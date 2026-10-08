import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'search_icons.dart';
import 'tagged_list.dart';

/// 列表頂部的 tag 篩選列（FanArtFiltered）：搜尋 icon＋「#tag ×」pill＋右側張數。
/// 點整條開啟坑內搜尋；點「×」回到該格的完整列表（取代目前頁面）。
/// 腦洞／草稿／成圖列表沿用同一條，下面是各自原本的卡片。
class TagFilterBar extends ConsumerWidget {
  const TagFilterBar({
    super.key,
    required this.pitId,
    required this.kind,
    required this.tagId,
    required this.countText,
  });
  final String pitId;
  final TaggedKind kind;
  final String tagId;

  /// 右側小字，例如「38 張」。
  final String countText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tags = ref.watch(tagsProvider(pitId)).value ?? const [];
    final name = tags.where((e) => e.id == tagId).firstOrNull?.name ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openPitSearch(context, pitId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SvgIcon(SearchIcons.search, size: 18, color: t.text3),
              const SizedBox(width: 8),
              TagFilterPill(
                name: name,
                onClear: () =>
                    openTaggedList(context, pitId, kind, null, replace: true),
              ),
              const Spacer(),
              Text(countText, style: TextStyle(color: t.text3, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「#tag ×」pill：主色底白字 13/600，左 10 右 6 內距。
class TagFilterPill extends StatelessWidget {
  const TagFilterPill({super.key, required this.name, required this.onClear});
  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: Semantics(
              button: true,
              label: context.l10n.searchRemoveFilter,
              child: const SvgIcon(
                AppIcons.closeX,
                size: 14,
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
