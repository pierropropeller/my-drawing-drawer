import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/fan_art_list_page.dart';
import '../album/official_list_page.dart';
import '../common/window_class.dart';
import '../entity/draft_list_page.dart';
import '../entity/finished_list_page.dart';
import '../entity/idea_list_page.dart';
import '../oshi/oshi_list_page.dart';

/// 坑內六個分區（頂部 tab 的順序即宣告順序，RespFan700／FanArt／Official 稿）。
enum PitSection {
  official,
  fanArt,
  ideas,
  drafts,
  pieces,
  oshi;

  String label(AppLocalizations l) => switch (this) {
    official => l.pitsOfficial,
    fanArt => l.pitsFanArt,
    ideas => l.pitsIdeas,
    drafts => l.pitsDrafts,
    pieces => l.pitsPieces,
    oshi => l.pitsCellOshi,
  };

  /// 對應的資料層格子（淺坑只顯示開啟的格子，D-088）。
  PitSectionKey get key => switch (this) {
    official => PitSectionKey.official,
    fanArt => PitSectionKey.fan,
    ideas => PitSectionKey.idea,
    drafts => PitSectionKey.draft,
    pieces => PitSectionKey.piece,
    oshi => PitSectionKey.oshi,
  };

  /// 這個分區的列表頁（與坑內頁的六格開啟同一批頁面）。
  Widget page(String pitId) => switch (this) {
    official => OfficialListPage(pitId: pitId),
    fanArt => FanArtListPage(pitId: pitId),
    ideas => IdeaListPage(pitId: pitId),
    drafts => DraftListPage(pitId: pitId),
    pieces => FinishedListPage(pitId: pitId),
    oshi => OshiListPage(pitId: pitId),
  };
}

/// 分區頁頂部的分區 tab bar（官方圖冊／好看同人圖／我的腦洞／我的摸魚／我的成圖／推活）。
///
/// 規格（IPAD_SPEC 2.1）：視窗闊度 ≥600 才出現，＜600 整個不畫（[SizedBox.shrink]），
/// 照手機版由坑內頁進入各分區。判斷用視窗闊度（[WindowClass.of]）。
///
/// ## 用法（給各分區頁的工程師）
/// 放在分區頁標題列的下方、篩選 chip 的上方，內容區左右邊界跟標題一致（[padding]）：
///
/// ```dart
/// Column(children: [
///   header,
///   PitSectionTabBar(pitId: pitId, selected: PitSection.fanArt),
///   chips,
///   Expanded(child: body),
/// ])
/// ```
///
/// - [selected]：目前頁面所屬分區（底線＋粗體）。點選中的 tab 不做事。
/// - [onSelect]：不給時的預設行為＝在「目前這個 Navigator」（坑分頁的 Navigator）上
///   **用無轉場的 `pushReplacement` 把目前分區頁換成目標分區頁**：返回堆疊維持
///   `[…, 坑內頁, 分區頁]`（不會越切越深），返回仍回到坑內頁，tab 切換沒有橫向滑入動畫。
///   要自己處理（例如保留選取）時傳 [onSelect]，收到的是被點的 [PitSection]。
/// - 想把靜態方法拿去別處用：`PitSectionTabBar.replaceWith(context, pitId, section)`。
///
/// ## 狀態不丟
/// 換頁是換掉整個 route，所以各分區頁**自己的**狀態（目前篩選 chip、搜尋、選中項目、捲動）
/// 必須放在 Riverpod provider（以 pitId 為 key）或上層持有，才能在來回切換、拉窗時保留；
/// widget State 裡的狀態切 tab 就會重設。tab 本身是無狀態的，選中項目只由 [selected] 決定，
/// 拉窗改變級別（medium⇄expanded⇄large）不影響。
///
/// 觸控目標：每個 tab 高 44、最小寬 44；tab 太多放不下時橫向捲動，並在建立時
/// 捲到選中的 tab。
class PitSectionTabBar extends ConsumerStatefulWidget {
  const PitSectionTabBar({
    super.key,
    required this.pitId,
    required this.selected,
    this.onSelect,
    this.padding = const EdgeInsets.fromLTRB(24, 6, 24, 0),
  });

  final String pitId;
  final PitSection selected;
  final ValueChanged<PitSection>? onSelect;

  /// tab 列左右的留白（要和頁面其他內容同邊界）；底線跨整個寬度。
  final EdgeInsetsGeometry padding;

  /// 預設換頁行為：以無轉場路由取代目前分區頁。
  static void replaceWith(
    BuildContext context,
    String pitId,
    PitSection section,
  ) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: 'pit-section-${section.name}'),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => section.page(pitId),
      ),
    );
  }

  @override
  ConsumerState<PitSectionTabBar> createState() => _PitSectionTabBarState();
}

class _PitSectionTabBarState extends ConsumerState<PitSectionTabBar> {
  final _scroll = ScrollController();
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 橫向捲動的 tab 列：建立後把選中的 tab 帶進可視範圍。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, alignment: .5);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _tap(PitSection s) {
    if (s == widget.selected) return;
    final cb = widget.onSelect;
    if (cb != null) {
      cb(s);
    } else {
      PitSectionTabBar.replaceWith(context, widget.pitId, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (WindowClass.of(context).isCompact) return const SizedBox.shrink();
    final t = context.tokens;
    final l = context.l10n;
    // 淺坑只列開啟的格子；目前所在的分區一定列出。
    final pit = ref.watch(pitProvider(widget.pitId)).value;
    final sections = [
      for (final s in PitSection.values)
        if (s == widget.selected || pit == null || pit.sectionOpen(s.key)) s,
    ];
    return Semantics(
      container: true,
      label: l.ipadpitSectionsLabel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: Row(
            children: [
              for (final s in sections) ...[
                if (s != sections.first) const SizedBox(width: 18),
                _Tab(
                  key: s == widget.selected ? _selectedKey : null,
                  label: s.label(l),
                  selected: s == widget.selected,
                  onTap: () => _tap(s),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: selected ? t.accent : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              color: selected ? t.ink : t.text2,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
