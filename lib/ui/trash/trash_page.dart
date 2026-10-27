import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart' show GoalKind;
import '../../data/trash_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/media_widgets.dart';
import '../common/nav_bar_hidden.dart';
import '../common/sensitive_gate.dart';
import '../common/svg_icon.dart';
import '../common/top_toast.dart';
import '../entity/entity_name.dart';
import '../entity/entity_widgets.dart';
import 'trash_preview_page.dart';

/// 剩幾天以下用琥珀色（分段標題、坑卡、預覽頁）。
const kTrashWarnDays = 3;
const kTrashWarn = Color(0xFFC58A1E);

/// 選中框與勾的顏色（TrashSelect 稿 `#D9634E`）。
const _selectColor = Color(0xFFD9634E);

/// 最近刪除（D-120／P-044；Trash、TrashSelect、TrashClearConfirm、TrashPitRestore 稿）。
///
/// 上面一排已刪除的坑卡，下面按剩餘天數分段的格子（手機一排 3 格、間距 2；iPad 右欄 6 格、間距 3）。
/// 點「選擇」或長按進入多選；點坑卡彈還原對話框；點格子進 [TrashPreviewPage]。
/// [embedded]＝iPad「我的」右欄（標題「最近刪除 11 項」、外框按鈕、置中動作列）。
class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage>
    with HidesNavBar<TrashPage> {
  @override
  bool get hidesNavBarOnOpen => !widget.embedded;

  bool _selecting = false;
  final _selected = <String>{};

  void _toggle(String key) => setState(() {
    if (!_selected.remove(key)) _selected.add(key);
  });

  void _startSelect([String? key]) => setState(() {
    _selecting = true;
    _selected.clear();
    if (key != null) _selected.add(key);
  });

  void _endSelect() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  TrashActions get _db => TrashActions(ref);

  Future<void> _restore(TrashContents c, {required bool all}) async {
    final pits = [
      for (final p in c.pits)
        if (all || _selected.contains(p.key)) p.id,
    ];
    final items = [
      for (final i in c.items)
        if (all || _selected.contains(i.key)) i,
    ];
    await _db.restore(pitIds: pits, items: items);
    if (!mounted) return;
    _endSelect();
    showSnack(context, context.l10n.trashRestoredSnack, success: true);
  }

  Future<void> _purge(TrashContents c, {required bool all}) async {
    final l = context.l10n;
    final pits = [
      for (final p in c.pits)
        if (all || _selected.contains(p.key)) p.id,
    ];
    final items = [
      for (final i in c.items)
        if (all || _selected.contains(i.key)) i,
    ];
    final ok = await confirmPurge(
      context,
      title: all
          ? l.trashClearTitle
          : l.trashPurgeTitle(pits.length + items.length),
      body: all
          ? (pits.isEmpty
                ? l.trashClearBodyItems(items.length)
                : l.trashClearBodyPits(pits.length, items.length))
          : l.trashPurgeBody,
    );
    if (!ok || !mounted) return;
    await _db.purge(pitIds: pits, items: items);
    if (mounted) _endSelect();
  }

  Future<void> _openPit(TrashPit p) async {
    final l = context.l10n;
    final t = context.tokens;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.trashPitRestoreTitle(p.name)),
        content: Text(l.trashPitRestoreBody(p.itemCount)),
        // 稿：永久刪除靠左，取消、還原靠右。
        actions: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'purge'),
                child: Text(l.trashPurge, style: TextStyle(color: t.danger)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonCancel, style: TextStyle(color: t.text2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'restore'),
                child: Text(
                  l.trashRestore,
                  style: TextStyle(
                    color: t.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'restore') {
      await _db.restore(pitIds: [p.id]);
      if (mounted) {
        showSnack(context, context.l10n.trashRestoredSnack, success: true);
      }
    } else if (action == 'purge') {
      final ok = await confirmPurge(
        context,
        title: l.trashPurgePitTitle(p.name),
        body: l.trashPurgeBody,
      );
      if (ok) await _db.purge(pitIds: [p.id]);
    }
  }

  void _openItem(TrashItem it) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => TrashPreviewPage(item: it)));

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(trashProvider).value ?? TrashContents.empty;
    // 全部還原／清空後最近刪除空了：手機版退回「我的」（入口那一行也會消失）。
    ref.listen(trashProvider, (prev, next) {
      final was = prev?.value;
      if (!widget.embedded &&
          was != null &&
          !was.isEmpty &&
          (next.value?.isEmpty ?? false)) {
        Navigator.of(context).maybePop();
      }
    });
    // 多選時被選的項目已經不在（例如另一台裝置還原了）：拿掉。
    _selected.retainWhere(
      (k) => c.pits.any((p) => p.key == k) || c.items.any((i) => i.key == k),
    );
    final wide = widget.embedded;
    final body = _content(context, c, wide);
    final bar = _selecting ? _bottomBar(context, c, wide) : null;
    if (wide) {
      return Column(
        children: [
          Expanded(child: body),
          ?bar,
        ],
      );
    }
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endSelect();
      },
      child: Scaffold(
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: bar == null ? null : BottomInsetAnchor(child: bar),
      ),
    );
  }

  Widget _header(BuildContext context, TrashContents c, bool wide) {
    final l = context.l10n;
    final t = context.tokens;
    final allKeys = [
      for (final p in c.pits) p.key,
      for (final i in c.items) i.key,
    ];
    final action = _selecting
        ? (l.commonSelectAll, () => setState(() => _selected.addAll(allKeys)))
        : (l.trashSelect, c.isEmpty ? null : () => _startSelect());
    final title = _selecting
        ? (_selected.isEmpty
              ? l.trashSelectTitle
              : l.trashSelectedCount(_selected.length))
        : l.trashTitle;
    if (!wide) {
      return SubPageHeader(
        title: title,
        titleSize: _selecting ? 19 : 20,
        gap: 6,
        leadingIcon: _selecting ? AppIcons.closeX : AppIcons.back,
        leadingSize: _selecting ? 22 : 24,
        leadingStroke: _selecting ? 2 : 1.9,
        onBack: _selecting ? _endSelect : null,
        trailing: [
          TextButton(
            onPressed: action.$2,
            style: TextButton.styleFrom(
              foregroundColor: t.piece.fg,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action.$1,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    final serif = Theme.of(context).textTheme.headlineSmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (_selecting) ...[
            Transform.translate(
              offset: const Offset(-8, 0),
              child: InkResponse(
                radius: 22,
                onTap: _endSelect,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SvgIcon(
                      AppIcons.closeX,
                      size: 22,
                      strokeWidth: 2,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                text: title,
                children: [
                  if (!_selecting)
                    TextSpan(
                      text: ' ${l.trashItemCount(c.count)}',
                      style: TextStyle(
                        fontFamily: DefaultTextStyle.of(context)
                            .style
                            .fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: t.text3,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: serif?.copyWith(
                fontSize: _selecting ? 22 : 24,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: action.$2,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: t.surface,
              foregroundColor: t.accentStrong,
              side: BorderSide(color: t.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              action.$1,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, TrashContents c, bool wide) {
    final t = context.tokens;
    final hpad = wide ? 40.0 : 20.0;
    final now = DateTime.now();

    Widget section(String text, {bool warn = false, bool first = false}) =>
        Padding(
          padding: wide
              ? EdgeInsets.fromLTRB(hpad, 18, hpad, 10)
              : EdgeInsets.fromLTRB(20, first ? 18 : 14, 20, 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: wide ? 13.5 : 13,
              fontWeight: FontWeight.w600,
              color: warn ? kTrashWarn : t.text2,
            ),
          ),
        );

    // 依剩餘天數分段（剩最多的在上）。
    final groups = <int, List<TrashItem>>{};
    for (final it in c.items) {
      groups
          .putIfAbsent(trashDaysLeft(it.deletedAt, now: now), () => [])
          .add(it);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final gap = wide ? 3.0 : 2.0;
    return LayoutBuilder(
      builder: (context, box) => _scroll(
        context,
        c,
        wide,
        box.maxWidth,
        gap,
        groups,
        days,
        now,
        section,
      ),
    );
  }

  Widget _scroll(
    BuildContext context,
    TrashContents c,
    bool wide,
    double width,
    double gap,
    Map<int, List<TrashItem>> groups,
    List<int> days,
    DateTime now,
    Widget Function(String text, {bool warn, bool first}) section,
  ) {
    final l = context.l10n;
    final hpad = wide ? 40.0 : 20.0;
    // iPad 稿：右欄一排 6 格（每格約 110）；右欄較窄時減少，最少 3 格。
    final cols = wide
        ? ((width - 2 * hpad + gap) / (108 + gap)).floor().clamp(3, 6)
        : 3;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: wide
              ? Padding(
                  padding: EdgeInsets.fromLTRB(hpad, 30, hpad, 0),
                  child: _header(context, c, wide),
                )
              : _header(context, c, wide),
        ),
        if (c.pits.isNotEmpty) ...[
          SliverToBoxAdapter(child: section(l.trashSectionPits)),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(hpad, 0, hpad, wide ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: wide ? 14 : 12,
                children: [
                  for (final p in c.pits)
                    _PitCard(
                      pit: p,
                      wide: wide,
                      now: now,
                      selecting: _selecting,
                      selected: _selected.contains(p.key),
                      onTap: () => _selecting ? _toggle(p.key) : _openPit(p),
                      onLongPress: _selecting
                          ? null
                          : () => _startSelect(p.key),
                    ),
                ],
              ),
            ),
          ),
        ],
        for (final (i, d) in days.indexed) ...[
          SliverToBoxAdapter(
            child: section(
              l.trashDaysLeft(d),
              warn: d <= kTrashWarnDays,
              first: i == 0 && c.pits.isNotEmpty,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: wide ? hpad : 0),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
              ),
              itemCount: groups[d]!.length,
              itemBuilder: (context, j) {
                final it = groups[d]![j];
                return _ItemTile(
                  item: it,
                  wide: wide,
                  selecting: _selecting,
                  selected: _selected.contains(it.key),
                  onTap: () => _selecting ? _toggle(it.key) : _openItem(it),
                  onLongPress: _selecting ? null : () => _startSelect(it.key),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, TrashContents c, bool wide) {
    final l = context.l10n;
    final t = context.tokens;
    final none = _selected.isEmpty;
    final restore = (
      none ? l.trashRestoreAll : l.trashRestore,
      () => _restore(c, all: none),
    );
    final purge = (
      none ? l.trashClearAll : l.trashPurge,
      () => _purge(c, all: none),
    );
    if (wide) {
      Widget pill(String label, String svg, Color color, VoidCallback onTap) =>
          OutlinedButton.icon(
            onPressed: onTap,
            icon: SvgIcon(svg, size: 21, strokeWidth: 1.7, color: color),
            label: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              foregroundColor: color,
              backgroundColor: t.surface,
              side: BorderSide(color: t.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
      return Container(
        padding: const EdgeInsets.fromLTRB(40, 12, 40, 16),
        decoration: BoxDecoration(
          color: t.nav,
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            pill(restore.$1, AppIcons.restore, t.ink, restore.$2),
            pill(purge.$1, AppIcons.trash, t.danger, purge.$2),
          ],
        ),
      );
    }
    Widget act(String label, String svg, Color color, VoidCallback onTap) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgIcon(svg, size: 22, strokeWidth: 1.7, color: color),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(color: color, fontSize: 11.5)),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            act(restore.$1, AppIcons.restore, t.ink, restore.$2),
            act(purge.$1, AppIcons.trash, t.danger, purge.$2),
          ],
        ),
      ),
    );
  }
}

/// 永久刪除的確認（系統對話框）：取消／永久刪除（紅字）。
Future<bool> confirmPurge(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            ctx.l10n.commonCancel,
            style: TextStyle(color: ctx.tokens.text2),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            ctx.l10n.trashPurge,
            style: TextStyle(
              color: ctx.tokens.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

/// 還原、永久刪除（資料層在 `trash_queries.dart`）。
class TrashActions {
  TrashActions(this.ref);
  final WidgetRef ref;

  Future<void> restore({
    Iterable<String> pitIds = const [],
    Iterable<TrashItem> items = const [],
  }) async {
    final db = ref.read(databaseProvider);
    for (final id in pitIds) {
      await db.restorePit(id);
    }
    if (items.isNotEmpty) await db.restoreItems(items);
  }

  Future<void> purge({
    Iterable<String> pitIds = const [],
    Iterable<TrashItem> items = const [],
  }) => ref.read(databaseProvider).purgeTrash(items: items, pitIds: pitIds);
}

/// 「剩 N 天」：剩 3 天或以下琥珀色。
class TrashDaysText extends StatelessWidget {
  const TrashDaysText(this.deletedAt, {super.key, this.style});
  final DateTime deletedAt;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final d = trashDaysLeft(deletedAt);
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      context.l10n.trashDaysLeft(d),
      style: d <= kTrashWarnDays ? base.copyWith(color: kTrashWarn) : base,
    );
  }
}

/// 多選的勾（右上角 22／iPad 24）：選中＝主色圓＋白勾；未選＝白框半透明圓。
class _SelectMark extends StatelessWidget {
  const _SelectMark(this.selected, {required this.size});
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected
          ? _selectColor
          : const Color(0xFF2B2622).withValues(alpha: 0.18),
      border: selected ? null : Border.all(color: Colors.white, width: 2),
    ),
    child: selected
        ? const Center(
            child: SvgIcon(
              AppIcons.check,
              size: 13,
              strokeWidth: 3,
              color: Colors.white,
            ),
          )
        : null,
  );
}

/// 選中時的內框（2px；iPad 2.5px）。
class _SelectRing extends StatelessWidget {
  const _SelectRing({required this.width, this.radius = 0});
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _selectColor, width: width),
      ),
    ),
  );
}

class _PitCard extends StatelessWidget {
  const _PitCard({
    required this.pit,
    required this.wide,
    required this.now,
    required this.selecting,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });
  final TrashPit pit;
  final bool wide;
  final DateTime now;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final cover = pit.coverFile;
    final markInset = wide ? 7.0 : 6.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: wide ? 170 : 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: wide ? 124 : 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: cover == null
                        ? ImagePlaceholder(color: t.fanArt.bg)
                        : SensitiveGate(
                            file: cover,
                            child: StoredImage(cover, cacheWidth: 400),
                          ),
                  ),
                  if (selected) _SelectRing(width: wide ? 2.5 : 2, radius: 14),
                  if (selecting)
                    Positioned(
                      right: markInset,
                      top: markInset,
                      child: _SelectMark(selected, size: wide ? 24 : 22),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: wide ? 14.5 : 14,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                text: '${l.trashItemCount(pit.itemCount)}・',
                children: [
                  TextSpan(
                    text: l.trashDaysLeft(
                      trashDaysLeft(pit.deletedAt, now: now),
                    ),
                    style:
                        trashDaysLeft(pit.deletedAt, now: now) <= kTrashWarnDays
                        ? const TextStyle(color: kTrashWarn)
                        : null,
                  ),
                ],
              ),
              style: TextStyle(fontSize: wide ? 12.5 : 12, color: t.text4),
            ),
          ],
        ),
      ),
    );
  }
}

/// 下方格子：有圖＝第一張（多張右下角張數）；沒有圖＝白底文字格（腦洞＝燈泡＋標題）。
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.wide,
    required this.selecting,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });
  final TrashItem item;
  final bool wide;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final markInset = wide ? 7.0 : 6.0;
    final Widget content;
    if (item.images.isEmpty) {
      content = Container(
        color: t.surface,
        padding: wide
            ? const EdgeInsets.fromLTRB(12, 14, 12, 14)
            : const EdgeInsets.fromLTRB(10, 12, 10, 12),
        // 格子很小時（窄的分割畫面）字直接截掉，不溢出。
        child: ClipRect(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: wide ? 8 : 6,
              children: [
                if (item.kind == TrashKind.idea)
                  SvgIcon(
                    AppIcons.bulb,
                    size: 16,
                    strokeWidth: 1.7,
                    color: t.idea.fg,
                  ),
                Text(
                  trashItemTitle(item),
                  style: TextStyle(
                    fontSize: wide ? 13.5 : 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      content = MediaThumb(
        MediaSource.fromImageRef(item.images.first),
        cacheWidth: 400,
        count: item.images.length,
        badgeInset: wide ? 6 : 5,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (selected) _SelectRing(width: wide ? 2.5 : 2),
          if (selecting)
            Positioned(
              right: markInset,
              top: markInset,
              child: _SelectMark(selected, size: wide ? 24 : 22),
            ),
        ],
      ),
    );
  }
}

/// 文字格／預覽用的標題：標題 → 內文前 12 字 → 日期＋類型（同 D-129，`entityDisplayName`）。
/// 沒有圖的文字項目都至少有其中一樣；沒有日期（推活）就用空字串。
String trashItemTitle(TrashItem it) {
  final kind = switch (it.kind) {
    TrashKind.idea => GoalKind.idea,
    TrashKind.draft => GoalKind.draft,
    TrashKind.piece => GoalKind.piece,
    _ => null,
  };
  final date = it.date;
  if (kind != null && date != null) {
    return entityDisplayName(
      l10nStatic,
      title: it.title,
      body: it.body,
      date: date,
      kind: kind,
    );
  }
  final title = it.title?.trim() ?? '';
  if (title.isNotEmpty) return title;
  final body = (it.body ?? '').trim().replaceAll('\n', ' ');
  return body.length <= 12 ? body : body.substring(0, 12);
}
