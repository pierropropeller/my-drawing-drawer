import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../me/me_icons.dart';
import '../pits/pit_form.dart';
import '../../l10n/l10n.dart';

/// 首次連結 Google 帳號後的同步中畫面（SyncFirst）：進度條＋「圖片 N / M」。
/// 按「先開始使用」離開，同步由 [SyncController] 在背景繼續；同步完成也會自動離開。
/// 沒有導覽列（設定／流程頁）。
class SyncFirstPage extends ConsumerStatefulWidget {
  const SyncFirstPage({super.key});

  /// 連結帳號後呼叫：開始首次同步（不等待），並以 [replace] 取代目前頁面進入 SyncFirst。
  static void open(
    BuildContext context,
    WidgetRef ref, {
    bool replace = false,
  }) {
    ref.read(syncControllerProvider.notifier).startFirstSyncInBackground();
    final route = MaterialPageRoute<void>(
      builder: (_) => const SyncFirstPage(),
    );
    final nav = Navigator.of(context);
    if (replace) {
      nav.pushReplacement(route);
    } else {
      nav.push(route);
    }
  }

  @override
  ConsumerState<SyncFirstPage> createState() => _SyncFirstPageState();
}

class _SyncFirstPageState extends ConsumerState<SyncFirstPage> {
  bool _left = false;

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).maybePop();
  }

  /// 首次同步已完成（或在進入前就完成）→ 自動離開。
  void _checkDone() {
    final sync = ref.read(syncControllerProvider);
    if (!sync.isSyncing &&
        sync.phase == SyncPhase.idle &&
        !ref.read(firstSyncPendingProvider) &&
        ref.read(settingsProvider).accountEmail != null) {
      _leave();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDone());
  }

  Widget _wide(
    BuildContext context, {
    required SyncState sync,
    required String subtitle,
    required double? fraction,
    required bool isError,
  }) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 300,
          child: _PopTiles(),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: dark ? t.official.bg : const Color(0xFFEAF0F5),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(
                        child: SvgIcon(
                          MeIcons.cloudDownload,
                          size: 54,
                          strokeWidth: 1.5,
                          color: t.official.fg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.loginSyncing,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isError ? t.danger : t.text2,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sync.isSyncing ? fraction : 0,
                      minHeight: 8,
                      backgroundColor: t.chipBg,
                      color: t.accent,
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 18,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sync.hasImageProgress
                              ? context.l10n.loginImagesProgress(
                                  sync.imagesDone,
                                  sync.imagesTotal,
                                )
                              : '',
                          style: TextStyle(fontSize: 13, color: t.text3),
                        ),
                        Text(
                          fraction == null
                              ? ''
                              : '${(fraction * 100).floor()}%',
                          style: TextStyle(fontSize: 13, color: t.text3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _leave,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border.all(
                          color: fieldBorderColor(context),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                      child: Text(
                        context.l10n.loginStartNow,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.loginSyncContinues,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: dark ? t.text4 : const Color(0xFFA49A8C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    ref.listen(syncControllerProvider, (prev, next) {
      if (prev?.isSyncing == true && !next.isSyncing) _checkDone();
    });
    final sync = ref.watch(syncControllerProvider);
    final fraction = sync.isSyncing ? sync.imageFraction : null;
    final String subtitle;
    if (sync.phase == SyncPhase.error && sync.message != null) {
      subtitle = sync.message!;
    } else if (!sync.isSyncing) {
      subtitle = context.l10n.syncOffline;
    } else {
      subtitle = context.l10n.loginDownloading;
    }
    final isError = sync.phase == SyncPhase.error;
    // ≥840（iPad，SyncFirst 稿）：內容 460 寬置中，底下一排裝飾色塊逐格浮現。
    if (WindowClass.of(context).isWide) {
      return HideNavBar(
        child: Scaffold(
          body: _wide(
            context,
            sync: sync,
            subtitle: subtitle,
            fraction: fraction,
            isError: isError,
          ),
        ),
      );
    }
    return HideNavBar(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: dark
                                ? t.official.bg
                                : const Color(0xFFEAF0F5),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Center(
                            child: SvgIcon(
                              MeIcons.cloudDownload,
                              size: 46,
                              strokeWidth: 1.5,
                              color: t.official.fg,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.loginSyncing,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontSize: 21),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isError ? t.danger : t.text2,
                          ),
                        ),
                        const SizedBox(height: 26),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            // 還不知道圖片數量時（拉取文件中）用不確定進度。
                            value: sync.isSyncing ? fraction : 0,
                            minHeight: 8,
                            backgroundColor: t.chipBg,
                            color: t.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 18,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                sync.hasImageProgress
                                    ? context.l10n.loginImagesProgress(
                                        sync.imagesDone,
                                        sync.imagesTotal,
                                      )
                                    : '',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: t.text3,
                                ),
                              ),
                              Text(
                                fraction == null
                                    ? ''
                                    : '${(fraction * 100).floor()}%',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: t.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _leave,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: fieldBorderColor(context),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(Radii.button),
                        ),
                        child: Text(
                          context.l10n.loginStartNow,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.loginSyncContinues,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? t.text4 : const Color(0xFFA49A8C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部的裝飾色塊（SyncFirst 稿）：12 欄 × 2 列共 24 塊，透明度 .55，由左到右逐塊浮現
/// （16 秒一輪，每塊晚 0.55 秒）。只作裝飾；系統要求減少動態效果時直接靜止顯示。
class _PopTiles extends StatefulWidget {
  const _PopTiles();

  @override
  State<_PopTiles> createState() => _PopTilesState();
}

class _PopTilesState extends State<_PopTiles>
    with SingleTickerProviderStateMixin {
  static const _colors = [
    Color(0xFFEAD9E0),
    Color(0xFFDCE6EC),
    Color(0xFFF2E2CE),
    Color(0xFFE0E8DD),
    Color(0xFFF5DED6),
    Color(0xFFE6E0EE),
    Color(0xFFE7ECF2),
    Color(0xFFF5EFCF),
    Color(0xFFF6E7EA),
    Color(0xFFECE6F3),
    Color(0xFFFBE7E0),
    Color(0xFFE7EFE4),
  ];
  static const _count = 24;
  static const _cycle = 16.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (!still && !_started) {
      _started = true;
      _c.repeat();
    } else if (still && _started) {
      _started = false;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 第 [i] 塊在這一輪的 0~1 相位對應的 (縮放, 不透明度)：
  /// 0%：縮 .6／透明 → 4%：滿 → 96%：仍滿 → 100%：透明。
  (double, double) _pop(double phase) {
    if (phase < 0.04) {
      final k = phase / 0.04;
      return (0.6 + 0.4 * k, k);
    }
    if (phase < 0.96) return (1, 1);
    return (1, 1 - (phase - 0.96) / 0.04);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final still = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.55,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: LayoutBuilder(
              builder: (context, c) {
                const cols = 12;
                const gap = 14.0;
                final side = (c.maxWidth - gap * (cols - 1)) / cols;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var i = 0; i < _count; i++)
                          Builder(
                            builder: (_) {
                              final base = _colors[(i * 5) % _colors.length];
                              final color = dark
                                  ? Color.alphaBlend(
                                      base.withValues(alpha: .16),
                                      t.surface,
                                    )
                                  : base;
                              // 負的 animation-delay：第 i 塊比第 0 塊晚 0.55 秒。
                              final (scale, opacity) = still
                                  ? (1.0, 1.0)
                                  : _pop(
                                      (((_c.value * _cycle) - 0.55 * i) %
                                              _cycle) /
                                          _cycle,
                                    );
                              return Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: side,
                                    height: side,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
