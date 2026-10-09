import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../share/share_channel.dart';
import '../../share/share_inbox.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart';
import '../entity/draft_form_page.dart';
import '../entity/idea_form_page.dart';
import '../entity/piece_form_page.dart';
import '../pits/pit_new_page.dart';
import 'share_sheet.dart';

/// 儲存後、回到原本的 App 之前，讓「已加入」提示留在畫面上的時間。測試可設為 zero。
Duration shareBackDelay = const Duration(milliseconds: 900);

/// 常駐在主畫面上方，收到分享就顯示「加入到」sheet（D-053）。
///
/// 還在開頭畫面（未完成 onboarding）時這個 widget 不存在，分享的圖片會留在
/// [shareInboxProvider] 的佇列，進到主畫面後才逐批顯示。
class ShareHost extends ConsumerStatefulWidget {
  const ShareHost({
    super.key,
    required this.child,
    required this.pitsNavigator,
    required this.showPitsTab,
  });

  final Widget child;

  /// 「坑」分頁自己的 Navigator（新增表單與開新坑都開在這裡，導覽列規則才正確）。
  final GlobalKey<NavigatorState> pitsNavigator;

  /// 切到「坑」分頁。
  final VoidCallback showPitsTab;

  @override
  ConsumerState<ShareHost> createState() => _ShareHostState();
}

class _ShareHostState extends ConsumerState<ShareHost> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  Future<void> _pump() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      while (mounted) {
        final paths = ref.read(shareInboxProvider.notifier).take();
        if (paths == null) break;
        await _handle(paths);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _handle(List<String> paths) async {
    String? pitId;
    ShareSection? section;
    String? groupId;
    while (true) {
      if (!mounted) return;
      final choice = await showShareSheet(
        context,
        paths: paths,
        pitId: pitId,
        section: section,
        groupId: groupId,
      );
      if (!mounted) return;
      if (choice == null) {
        // 取消：複製進來的暫存檔不再需要。
        _deleteFiles(paths);
        return;
      }
      switch (choice.action) {
        case ShareAction.newPit:
          // 開新坑沿用既有的新增坑頁，回來後選中新坑，位置維持原樣。
          widget.showPitsTab();
          final nav = widget.pitsNavigator.currentState;
          final newId = await nav?.push<String>(
            MaterialPageRoute<String>(builder: (_) => const PitNewPage()),
          );
          pitId = newId ?? choice.pitId;
          section = choice.section;
          groupId = null;
        case ShareAction.add:
          await _save(choice, paths);
          return;
        case ShareAction.next:
          _openForm(choice, paths);
          return;
      }
    }
  }

  /// 「加入」：匯入 App 儲存空間、寫進資料庫、顯示「已加入」，再回到原本的 App。
  Future<void> _save(ShareChoice c, List<String> paths) async {
    final store = await ref.read(imageStoreProvider.future);
    final images = <NewImage>[];
    for (final path in paths) {
      try {
        images.add(await store.import(XFile(path)));
      } catch (_) {
        // 讀不到的檔案略過。
      }
    }
    _deleteFiles(paths);
    if (images.isEmpty) return;
    final db = ref.read(databaseProvider);
    final pitId = c.pitId!;
    switch (c.section!) {
      case ShareSection.official:
        await db.addOfficial(pitId, c.groupId!, images);
      case ShareSection.fan:
        // 作者留空，也沒有出處。
        await db.addFanArts(pitId, images, author: '');
      case ShareSection.junk:
        await db.addJunk(pitId, images);
      case ShareSection.draft || ShareSection.idea || ShareSection.piece:
        return;
    }
    if (!mounted) return;
    showSnack(context, context.l10n.shareAdded, success: true);
    await Future<void>.delayed(shareBackDelay);
    await ref.read(shareChannelProvider).moveTaskToBack();
  }

  /// 「下一步」：在「坑」分頁開該格的新增表單，圖片先放好。
  void _openForm(ShareChoice c, List<String> paths) {
    final pitId = c.pitId!;
    final files = [for (final p in paths) XFile(p)];
    widget.showPitsTab();
    final nav = widget.pitsNavigator.currentState;
    if (nav == null) return;
    // 表單關閉後回到坑列表，而不是使用者原本停留的深層頁面。
    nav.popUntil((r) => r.isFirst);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => switch (c.section!) {
          ShareSection.draft => DraftFormPage(
            pitId: pitId,
            initialImages: files,
          ),
          ShareSection.idea => IdeaFormPage(pitId: pitId, initialImages: files),
          _ => PieceFormPage(pitId: pitId, initialImages: files),
        },
      ),
    );
  }

  void _deleteFiles(List<String> paths) {
    for (final p in paths) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shareInboxProvider, (_, next) {
      if (next.isNotEmpty) unawaited(_pump());
    });
    return widget.child;
  }
}
