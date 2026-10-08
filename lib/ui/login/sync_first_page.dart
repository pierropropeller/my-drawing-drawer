import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../me/me_icons.dart';
import '../pits/pit_form.dart';

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
      subtitle = '目前離線，恢復網絡後將自動同步';
    } else {
      subtitle = '正在下載你在 Google Drive 的資料';
    }
    final isError = sync.phase == SyncPhase.error;
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
                          '正在同步',
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
                                    ? '圖片 ${sync.imagesDone} / ${sync.imagesTotal}'
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
                        child: const Text(
                          '先開始使用',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '同步會在背景繼續',
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
