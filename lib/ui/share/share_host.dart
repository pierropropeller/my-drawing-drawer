import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../data/material_queries.dart';
import '../../l10n/l10n.dart';
import '../../media/media_import.dart';
import '../../share/share_inbox.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart';
import '../album/fan_art_list_page.dart';
import '../album/official_list_page.dart';
import '../entity/draft_list_page.dart';
import '../entity/finished_list_page.dart';
import '../entity/idea_list_page.dart';
import '../oshi/oshi_list_page.dart';
import '../entity/draft_form_page.dart';
import '../entity/idea_form_page.dart';
import '../entity/piece_form_page.dart';
import '../junk/junk_list_page.dart';
import '../material/material_library_page.dart';
import '../pits/pit_new_page.dart';
import '../pits/pit_page.dart';
import 'share_sheet.dart';
import 'share_targets.dart';

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
    required this.profileNavigator,
    required this.showProfileTab,
  });

  final Widget child;

  /// 「坑」分頁自己的 Navigator（新增表單與開新坑都開在這裡，導覽列規則才正確）。
  final GlobalKey<NavigatorState> pitsNavigator;

  /// 切到「坑」分頁。
  final VoidCallback showPitsTab;

  /// 「我的」分頁自己的 Navigator（素材庫頁開在這裡）。
  final GlobalKey<NavigatorState> profileNavigator;

  /// 切到「我的」分頁。
  final VoidCallback showProfileTab;

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
        case ShareAction.addMaterial:
          await _saveMaterial(choice, paths);
          return;
        case ShareAction.next:
          _openForm(choice, paths);
          return;
      }
    }
  }

  /// 「加入」：匯入 App 儲存空間、寫進資料庫、顯示「已加入」，並留在 App 裡，
  /// 停在剛加入的那個列表（坑 → 該格列表）。
  Future<void> _save(ShareChoice c, List<String> paths) async {
    final store = await ref.read(imageStoreProvider.future);
    final images = <NewImage>[];
    for (final path in paths) {
      try {
        images.add(await importPickedMedia(store, XFile(path)));
      } catch (_) {
        // 讀不到的檔案略過。
      }
    }
    _deleteFiles(paths);
    if (images.isEmpty) return;
    final db = ref.read(databaseProvider);
    final pitId = c.pitId!;
    final Widget list;
    switch (c.section!) {
      case ShareSection.official:
        await db.addOfficial(pitId, c.groupId!, images, tagIds: c.tagIds);
        list = OfficialListPage(pitId: pitId);
      case ShareSection.fan:
        await db.addFanArts(
          pitId,
          images,
          author: c.author,
          groupId: c.groupId,
          tagIds: c.tagIds,
        );
        list = FanArtListPage(pitId: pitId);
      case ShareSection.junk:
        await db.addJunk(pitId, images);
        list = JunkListPage(pitId: pitId);
      case ShareSection.draft ||
          ShareSection.idea ||
          ShareSection.piece ||
          ShareSection.oshi:
        return;
    }
    if (!mounted) return;
    _showDestination(pitId, list);
    showSnack(context, context.l10n.shareAdded, success: true);
  }

  /// 「素材庫」段的「加入」（D-071）：匯入、寫進素材庫，並留在 App 裡，
  /// 停在剛存的分類的素材庫頁（我的 → 素材庫）。
  Future<void> _saveMaterial(ShareChoice c, List<String> paths) async {
    final store = await ref.read(imageStoreProvider.future);
    final images = <NewImage>[];
    for (final path in paths) {
      try {
        images.add(await importPickedMedia(store, XFile(path)));
      } catch (_) {
        // 讀不到的檔案略過。
      }
    }
    _deleteFiles(paths);
    if (images.isEmpty) return;
    final category = c.material!;
    await ref.read(databaseProvider).addMaterials(category, images);
    if (!mounted) return;
    widget.showProfileTab();
    final nav = widget.profileNavigator.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => MaterialLibraryPage(initialCategory: category),
      ),
    );
    showSnack(context, context.l10n.shareAdded, success: true);
  }

  /// 切到「坑」分頁，回到最上層後依序打開該坑的頁面與目的地列表（返回時是坑內頁）。
  void _showDestination(String pitId, Widget list) {
    widget.showPitsTab();
    final nav = widget.pitsNavigator.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute<void>(builder: (_) => PitPage(pitId: pitId)));
    nav.push(MaterialPageRoute<void>(builder: (_) => list));
  }

  /// 「下一步」：在「坑」分頁開該格的新增表單，圖片先放好。
  ///
  /// 頁面堆疊是 坑內頁 → 該格列表 → 新增表單，所以存檔後（表單關閉）會停在
  /// 該格列表，看得到剛加入的內容，而不是掉回主頁。
  void _openForm(ShareChoice c, List<String> paths) {
    final pitId = c.pitId!;
    final files = [for (final p in paths) XFile(p)];
    widget.showPitsTab();
    final nav = widget.pitsNavigator.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute<void>(builder: (_) => PitPage(pitId: pitId)));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => switch (c.section!) {
          ShareSection.draft => DraftListPage(pitId: pitId),
          ShareSection.idea => IdeaListPage(pitId: pitId),
          ShareSection.piece => FinishedListPage(pitId: pitId),
          _ => OshiListPage(pitId: pitId),
        },
      ),
    );
    if (c.section == ShareSection.oshi) {
      final inner = nav.overlay?.context;
      if (inner != null) openOshiForm(inner, pitId, paths);
      return;
    }
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
