// 影片參考檢視（RefVideo）：16:9 舞台、時間軸（約 14 格縮圖）＋播放頭、上一格／播放／下一格、
// 速度 0.25×／0.5×／1×／2×、循環、左右翻轉、靜音、「截取此格」。
//
// 逐格的做法與限制（給 Molly 知道）：
// - `video_player` 沒有「前進一格」的 API，所以上一格／下一格＝暫停後 `seekTo(目前 ± 1/fps)`。
//   這是近似：ExoPlayer／AVPlayer 的 seek 可能對到最近的關鍵格或整數毫秒，不保證剛好差一格。
//   我們自己記著目標位置（不讀播放器回報的位置），連按不會累積誤差。
// - fps 來自原生讀到的影片 metadata（`FrameExtractor`，Android 用 MediaMetadataRetriever 的
//   VIDEO_FRAME_COUNT ÷ 長度）；讀不到就用 30。「第 N 格」＝ round(位置秒數 × fps)。
// - 時間軸縮圖、「截取此格」的畫面也是原生抽的；沒有原生支援（測試、桌面）時縮圖退回 poster 色塊，
//   截取失敗會提示。
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart' show showSnack;
import '../album/album_image.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'ref_frames.dart';
import 'ref_icons.dart';
import '../common/dismissible_preview.dart';
import 'ref_image.dart';
import 'ref_palette.dart';
import 'ref_video_playback.dart';

/// 影片檢視器的頁面（沒有導覽列）。
class RefVideoViewerPage extends StatefulWidget {
  const RefVideoViewerPage({super.key, required this.image});
  final RefImage image;

  @override
  State<RefVideoViewerPage> createState() => _RefVideoViewerPageState();
}

class _RefVideoViewerPageState extends State<RefVideoViewerPage>
    with HidesNavBar<RefVideoViewerPage> {
  @override
  Widget build(BuildContext context) {
    // 共用預覽手勢（點一下舞台收起 UI、垂直拖曳退出），見 dismissible_preview.dart。
    return DismissiblePreview(
      background: RefPalette.dark.pane,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefVideoViewer(
            image: widget.image,
            onClose: () => Navigator.of(context).pop(<String>{}),
          ),
        ),
      ),
    );
  }
}

const _speeds = <double>[0.25, 0.5, 1, 2];
const stripCells = 14;

String refSpeedLabel(double s) =>
    s == s.roundToDouble() ? '${s.toInt()}×' : '$s×';

/// `m:ss.cc`（0:08.12）。
String refTimeLabel(Duration d) {
  final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final cs = (ms % 1000) ~/ 10;
  return '$m:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
}

class RefVideoViewer extends ConsumerStatefulWidget {
  const RefVideoViewer({super.key, required this.image, this.onClose});
  final RefImage image;
  final VoidCallback? onClose;

  @override
  ConsumerState<RefVideoViewer> createState() => _RefVideoViewerState();
}

class _RefVideoViewerState extends ConsumerState<RefVideoViewer>
    with WidgetsBindingObserver {
  RefVideoPlayback? _pb;
  bool _ready = false;
  bool _error = false;

  double _fps = 30;
  Duration _target = Duration.zero;
  double _speed = 1;
  bool _loop = true;
  bool _flipped = false;
  bool _muted = false;
  bool _capturing = false;

  List<Uint8List?> _strip = const [];

  bool _seekBusy = false;
  Duration? _pendingSeek;

  Duration get _duration => _pb?.duration ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final store = await ref.read(imageStoreProvider.future);
      final file = store.fileOf(widget.image.file);
      final pb = ref.read(refPlaybackFactoryProvider)(file);
      _pb = pb;
      await pb.initialize();
      if (!mounted) {
        pb.dispose();
        _pb = null;
        return;
      }
      await pb.setLooping(_loop);
      await pb.setPlaybackSpeed(_speed);
      pb.addListener(_onTick);
      setState(() => _ready = true);
      unawaited(_loadStrip(file.path));
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _loadStrip(String path) async {
    final durMs = _duration.inMilliseconds;
    if (durMs <= 0) return;
    final positions = [
      for (var i = 0; i < stripCells; i++)
        ((i + 0.5) / stripCells * durMs).round(),
    ];
    final r = await ref.read(frameExtractorProvider).extract(path, positions);
    if (!mounted || r == null) return;
    setState(() {
      _strip = r.frames;
      if (r.fps != null && r.fps! > 1) _fps = r.fps!;
    });
  }

  void _onTick() {
    final pb = _pb;
    if (pb == null || !mounted) return;
    // 播放中讓目標位置跟著播放器走；暫停時以我們記的為準（見檔頭）。
    if (pb.isPlaying) _target = pb.position;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_pb?.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pb?.removeListener(_onTick);
    _pb?.dispose();
    super.dispose();
  }

  Duration get _step => Duration(microseconds: (1e6 / _fps).round());

  Duration _clamp(Duration d) {
    if (d < Duration.zero) return Duration.zero;
    if (d > _duration) return _duration;
    return d;
  }

  /// 跳到指定位置；連續請求只保留最新的一個，免得 seek 排隊。
  Future<void> _seek(Duration d) async {
    _target = _clamp(d);
    if (_seekBusy) {
      _pendingSeek = _target;
      return;
    }
    _seekBusy = true;
    try {
      var next = _target;
      while (true) {
        await _pb?.seekTo(next);
        final p = _pendingSeek;
        if (p == null) break;
        _pendingSeek = null;
        next = p;
      }
    } finally {
      _seekBusy = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    final pb = _pb;
    if (pb == null) return;
    if (pb.isPlaying) {
      await pb.pause();
      _target = pb.position;
    } else {
      if (_duration > Duration.zero && _target >= _duration) {
        await _seek(Duration.zero);
      }
      await pb.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _stepFrame(int dir) async {
    final pb = _pb;
    if (pb == null) return;
    if (pb.isPlaying) {
      await pb.pause();
      _target = pb.position;
    }
    await _seek(_target + _step * dir);
  }

  Future<void> _setSpeed(double s) async {
    setState(() => _speed = s);
    await _pb?.setPlaybackSpeed(s);
  }

  Future<void> _toggleLoop() async {
    setState(() => _loop = !_loop);
    await _pb?.setLooping(_loop);
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _pb?.setVolume(_muted ? 0 : 1);
  }

  /// 把時間軸上的橫向位置換成影片位置。
  void _scrub(double dx, double width) {
    if (width <= 0) return;
    final f = (dx / width).clamp(0.0, 1.0);
    final d = Duration(microseconds: (f * _duration.inMicroseconds).round());
    final pb = _pb;
    if (pb != null && pb.isPlaying) unawaited(pb.pause());
    unawaited(_seek(d));
  }

  /// 「截取此格」：把目前這一格存成一張新圖，放進和來源影片同一個坑／分區。
  /// （稿沒有說存到哪，這是暫定做法，見最終回報。）
  Future<void> _capture() async {
    final a = widget.image.album;
    final pitId = widget.image.pitId;
    final l10n = context.l10n;
    if (_capturing) return;
    if (a == null ||
        pitId == null ||
        (a.kind == AlbumKind.official && a.groupId == null)) {
      showSnack(context, l10n.refviewCaptureNoTarget);
      return;
    }
    setState(() => _capturing = true);
    try {
      final store = await ref.read(imageStoreProvider.future);
      final path = store.fileOf(widget.image.file).path;
      final r = await ref
          .read(frameExtractorProvider)
          .extract(
            path,
            [_target.inMilliseconds],
            maxSide: 4096,
            quality: 95,
            exact: true,
          );
      final bytes = (r == null || r.frames.isEmpty) ? null : r.frames.first;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) showSnack(context, l10n.refviewCaptureFailed);
        return;
      }
      final name = await store.savePoster(bytes);
      var w = widget.image.width;
      var h = widget.image.height;
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        w = frame.image.width;
        h = frame.image.height;
        frame.image.dispose();
        codec.dispose();
      } catch (_) {
        // 解碼不出尺寸就沿用影片的寬高。
      }
      final img = NewImage(file: name, width: w, height: h);
      final db = ref.read(databaseProvider);
      switch (a.kind) {
        case AlbumKind.official:
          await db.addOfficial(pitId, a.groupId!, [img]);
        case AlbumKind.fanArt:
          await db.addFanArts(
            pitId,
            [img],
            author: a.author ?? '',
            groupId: a.groupId,
          );
        case AlbumKind.junk:
          await db.addJunk(pitId, [img]);
      }
      if (mounted) showSnack(context, l10n.refviewCaptured, success: true);
    } catch (_) {
      if (mounted) showSnack(context, l10n.refviewCaptureFailed);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const p = RefPalette.dark;
    final l10n = context.l10n;
    final accent = context.tokens.accent;
    // 在預覽頁裡（有 PreviewScope）底色由 DismissiblePreview 畫，這裡透明。
    final inPreview = PreviewScope.maybeOf(context) != null;
    return ColoredBox(
      color: inPreview ? Colors.transparent : p.pane,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: p.fg),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 720;
            final side = c.maxWidth >= 600 ? 20.0 : 12.0;
            final pos = _target;
            final frame = (pos.inMicroseconds / 1e6 * _fps).round();
            return Column(
              children: [
                PreviewChrome(child: _header(p, accent, side, l10n)),
                Expanded(
                  child: PreviewMediaArea(
                    allowHorizontalDismiss: false,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: side),
                      decoration: BoxDecoration(
                        color: p.stage,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _stage(p, l10n, frame),
                    ),
                  ),
                ),
                PreviewChrome(
                  child: _timeline(p, side + (wide ? 8 : 4), pos, l10n),
                ),
                PreviewChrome(child: _controls(p, accent, side, wide, l10n)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(
    RefPalette p,
    Color accent,
    double side,
    AppLocalizations l10n,
  ) {
    final title = l10n.refviewVideoTitle(widget.image.title ?? '');
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 6, side, 10),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.commonBack,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SvgIcon(
                    RefIcons.back,
                    size: 24,
                    color: p.fg,
                    strokeWidth: 1.9,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: l10n.refviewCapture,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _ready ? _capture : null,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SvgIcon(
                      RefIcons.camera,
                      size: 18,
                      color: Colors.white,
                      strokeWidth: 1.9,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.refviewCapture,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage(RefPalette p, AppLocalizations l10n, int frame) {
    if (_error) {
      return Center(
        child: Text(
          l10n.mediaVideoError,
          style: TextStyle(color: p.sub, fontSize: 13),
        ),
      );
    }
    final pb = _pb;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_ready && pb != null)
          LayoutBuilder(
            builder: (context, b) {
              final ar = pb.aspectRatio;
              var w = b.maxWidth * 0.86;
              var h = w / ar;
              if (h > b.maxHeight) {
                h = b.maxHeight;
                w = h * ar;
              }
              Widget view = pb.buildView(context);
              if (_flipped) {
                view = Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(-1, 1, 1),
                  child: view,
                );
              }
              return Center(
                child: SizedBox(width: w, height: h, child: view),
              );
            },
          ),
        Positioned(
          left: 14,
          top: 14,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xCC1E1B18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.refviewFrameLabel(refSpeedLabel(_speed), frame),
              style: const TextStyle(
                color: RefPalette.floatingFg,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeline(
    RefPalette p,
    double side,
    Duration pos,
    AppLocalizations l10n,
  ) {
    final dur = _duration;
    final frac = dur.inMicroseconds <= 0
        ? 0.0
        : (pos.inMicroseconds / dur.inMicroseconds).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 14, side, 8),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, b) {
              final w = b.maxWidth;
              return Semantics(
                label: l10n.refviewTimeline,
                slider: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _scrub(d.localPosition.dx, w),
                  onHorizontalDragStart: (d) => _scrub(d.localPosition.dx, w),
                  onHorizontalDragUpdate: (d) => _scrub(d.localPosition.dx, w),
                  child: SizedBox(
                    height: 52,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Row(
                              children: [
                                for (var i = 0; i < stripCells; i++) ...[
                                  if (i > 0) const SizedBox(width: 2),
                                  Expanded(child: _cell(p, i)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: frac * w - 2,
                          top: -2,
                          bottom: -2,
                          width: 4,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x59000000),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                refTimeLabel(pos),
                style: TextStyle(color: p.sub, fontSize: 12),
              ),
              Text(
                refTimeLabel(dur),
                style: TextStyle(color: p.sub, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(RefPalette p, int i) {
    final bytes = i < _strip.length ? _strip[i] : null;
    return Opacity(
      opacity: .8,
      child: bytes == null
          ? ColoredBox(color: p.chip)
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => ColoredBox(color: p.chip),
            ),
    );
  }

  Widget _controls(
    RefPalette p,
    Color accent,
    double side,
    bool wide,
    AppLocalizations l10n,
  ) {
    final playing = _pb?.isPlaying ?? false;
    Widget iconBtn(String icon, String label, VoidCallback? onTap) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: SvgIcon(icon, size: 22, color: p.fg, strokeWidth: 1.9),
          ),
        ),
      ),
    );
    final transport = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBtn(
          RefIcons.prevFrame,
          l10n.refviewPrevFrame,
          _ready ? () => _stepFrame(-1) : null,
        ),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          label: playing ? l10n.mediaPause : l10n.mediaPlay,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _ready ? _togglePlay : null,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1FFFFFFF),
              ),
              child: Center(
                child: SvgIcon(
                  playing ? RefIcons.pause : RefIcons.play,
                  size: 22,
                  color: p.fg,
                  strokeWidth: 0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        iconBtn(
          RefIcons.nextFrame,
          l10n.refviewNextFrame,
          _ready ? () => _stepFrame(1) : null,
        ),
      ],
    );
    final speeds = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in _speeds) ...[
          if (s != _speeds.first) const SizedBox(width: 6),
          _chip(
            p,
            label: refSpeedLabel(s),
            on: _speed == s,
            onTap: () => _setSpeed(s),
          ),
        ],
      ],
    );
    final toggles = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(
          p,
          label: l10n.refviewLoop,
          on: _loop,
          icon: RefIcons.loop,
          onTap: _toggleLoop,
        ),
        const SizedBox(width: 6),
        _chip(
          p,
          label: l10n.refviewFlip,
          on: _flipped,
          onTap: () => setState(() => _flipped = !_flipped),
        ),
        const SizedBox(width: 6),
        _chip(p, label: l10n.mediaMute, on: _muted, onTap: _toggleMute),
      ],
    );
    final divider = Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0x24FFFFFF),
    );
    if (wide) {
      return Padding(
        padding: EdgeInsets.fromLTRB(side, 4, side, 20),
        child: Row(
          children: [
            transport,
            divider,
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: speeds,
              ),
            ),
            const Spacer(),
            toggles,
          ],
        ),
      );
    }
    // 窄版：播放控制一排、速度與開關各一排（<720 放不下）。
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 0, side, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          transport,
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: speeds),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: toggles),
        ],
      ),
    );
  }

  Widget _chip(
    RefPalette p, {
    required String label,
    required bool on,
    required VoidCallback onTap,
    String? icon,
  }) {
    final fg = on ? const Color(0xFF1E1B18) : p.off;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 視覺高 36，垂直補到 44 的點擊區。
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFF5F0E8) : const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  SvgIcon(icon, size: 16, color: fg, strokeWidth: 1.9),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
