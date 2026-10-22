import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/media.dart';
import '../../l10n/l10n.dart';
import '../../media/video_probe.dart';
import '../common/app_icons.dart';
import '../common/dismissible_preview.dart';
import '../common/media_widgets.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'image_picker_field.dart';
import 'preview_shell.dart';
import 'sensitive_form.dart';

/// 表單裡點小縮圖開的全螢幕預覽（D-102，`FormImagePreview`）。
///
/// 黑底、左上 ×、右上「1 / N」、左右滑換圖；**沒有底部動作列**（分享、下載都不放）。
/// 手勢沿用共用的 [DismissiblePreview]（垂直拖曳／邊緣水平拖曳退出、點一下收起 UI）。
/// 圖片可以是還沒匯入的本機檔（[ImageItem.picked]）或已在 App 內的（[ImageItem.stored]）。
class FormImagePreviewPage extends ConsumerStatefulWidget {
  const FormImagePreviewPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.canMark = false,
  });

  final List<ImageItem> items;
  final int initialIndex;

  /// 右上角出現逐張「標為敏感」切換鈕（D-104，總開關＋該坑的敏感內容都開了才傳 true）。
  final bool canMark;

  /// 從表單開預覽。
  static Future<void> open(
    BuildContext context,
    List<ImageItem> items,
    int index, {
    bool canMark = false,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FormImagePreviewPage(
        items: items,
        initialIndex: index,
        canMark: canMark,
      ),
    ),
  );

  @override
  ConsumerState<FormImagePreviewPage> createState() =>
      _FormImagePreviewPageState();
}

class _FormImagePreviewPageState extends ConsumerState<FormImagePreviewPage>
    with HidesNavBar<FormImagePreviewPage> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return DismissiblePreview(
      background: PreviewPalette.bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              PreviewChrome(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  child: Row(
                    children: [
                      InkResponse(
                        radius: 24,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Semantics(
                          button: true,
                          label: context.l10n.commonClose,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: SvgIcon(
                                AppIcons.closeX,
                                size: 22,
                                strokeWidth: 2,
                                color: PreviewPalette.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '${_index + 1} / ${items.length}',
                          style: const TextStyle(
                            color: PreviewPalette.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (widget.canMark && items.isNotEmpty)
                        ListenableBuilder(
                          listenable: items[_index],
                          builder: (context, _) => SensitivePreviewToggle(
                            marked: items[_index].sensitive,
                            onTap: () => items[_index].sensitive =
                                !items[_index].sensitive,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PreviewMediaArea(
                  pageController: _controller,
                  child: PreviewPageView(
                    controller: _controller,
                    itemCount: items.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) =>
                        _FormPreviewPage(items[i], active: i == _index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormPreviewPage extends ConsumerWidget {
  const _FormPreviewPage(this.item, {required this.active});
  final ImageItem item;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = item.stored;
    if (stored != null) {
      return MediaViewer(
        MediaSource.fromNewImage(stored),
        active: active,
        zoomable: true,
      );
    }
    final path = item.picked!.path;
    switch (mediaKindFromExtension(path)) {
      case MediaKind.video:
        return _PickedVideoPoster(path, probe: ref.watch(videoProbeProvider));
      case MediaKind.gif:
        return _PickedZoomable(
          active
              ? Image.file(File(path), fit: BoxFit.contain)
              : FirstFrameImage(provider: FileImage(File(path))),
        );
      case MediaKind.image:
        return _PickedZoomable(Image.file(File(path), fit: BoxFit.contain));
    }
  }
}

/// 還沒匯入的本機圖：可雙指縮放，並回報縮放狀態給預覽手勢（放大時不觸發拖曳退出）。
class _PickedZoomable extends StatefulWidget {
  const _PickedZoomable(this.child);
  final Widget child;

  @override
  State<_PickedZoomable> createState() => _PickedZoomableState();
}

class _PickedZoomableState extends State<_PickedZoomable> {
  final _tc = TransformationController();
  PreviewController? _preview;

  @override
  void initState() {
    super.initState();
    _tc.addListener(() {
      _preview?.setZoomed(this, _tc.value.getMaxScaleOnAxis() > 1.02);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preview = PreviewScope.maybeOf(context);
  }

  @override
  void dispose() {
    _preview?.setZoomed(this, false);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    transformationController: _tc,
    maxScale: 5,
    child: SizedBox.expand(child: widget.child),
  );
}

/// 還沒匯入的影片：設計稿沒畫影片控制列，只顯示第一格截圖＋長度小標（不能播放）。
class _PickedVideoPoster extends StatelessWidget {
  const _PickedVideoPoster(this.path, {required this.probe});
  final String path;
  final VideoProbe probe;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VideoMeta?>(
      future: probe.probe(path, maxPosterSide: 1600),
      builder: (context, snap) {
        final meta = snap.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (meta != null && meta.hasPoster)
              Image.memory(meta.poster!, fit: BoxFit.contain),
            Positioned(
              left: 12,
              bottom: 12,
              child: MediaBadgeVideo(durationMs: meta?.durationMs),
            ),
          ],
        );
      },
    );
  }
}
