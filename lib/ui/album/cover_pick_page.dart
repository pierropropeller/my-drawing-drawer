import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'album_actions.dart';
import 'album_image.dart';

/// 選擇坑的封面（主頁坑卡片上的圖）：長按坑內頁的某一格進入，只列出該格內的圖，
/// 點一下即設為封面，沒有選中狀態。
class CoverPickPage extends ConsumerStatefulWidget {
  const CoverPickPage({super.key, required this.pitId, this.kind});
  final String pitId;

  /// `official`／`fan`／`draft`／`idea`／`piece`；null＝整個坑的圖都列出（編輯坑的「更換封面」）。
  final String? kind;

  @override
  ConsumerState<CoverPickPage> createState() => _CoverPickPageState();
}

class _CoverPickPageState extends ConsumerState<CoverPickPage>
    with HidesNavBar<CoverPickPage> {
  String? _group; // null＝全部

  static String? _kindLabel(AppLocalizations l, String? kind) => switch (kind) {
    'official' => l.pitsOfficial,
    'fan' => l.pitsFanArt,
    'draft' => l.pitsDrafts,
    'idea' => l.pitsIdeas,
    'piece' => l.pitsPieces,
    _ => null,
  };

  Future<void> _pick(CoverCandidate c) async {
    await ref.read(databaseProvider).setCover(widget.pitId, c.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showSnack(context, context.l10n.albumCoverSet, success: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kind = widget.kind;
    final all =
        ref.watch(coverCandidatesProvider((widget.pitId, kind))).value ??
        const <CoverCandidate>[];
    final hasGroups = kind == 'official' || kind == 'fan';
    final groups = hasGroups
        ? (ref.watch(groupsProvider((widget.pitId, kind!))).value ?? const [])
        : const [];
    final shown = _group == null
        ? all
        : [
            for (final c in all)
              if (c.groupId == _group) c,
          ];
    final label = _kindLabel(context.l10n, kind);
    return Scaffold(
      backgroundColor: const Color(0xFF2B2622),
      body: Column(
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, top: 4),
                    child: IconButton(
                      tooltip: context.l10n.commonBack,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: SvgIcon(
                        AppIcons.back,
                        strokeWidth: 1.9,
                        color: Colors.white.withValues(alpha: .7),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    label == null
                        ? context.l10n.albumCoverPickTitle
                        : context.l10n.albumCoverHolding(label),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: .5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              decoration: BoxDecoration(
                color: t.ground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.albumCoverPickHeading,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  if (groups.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip(
                              label: context.l10n.commonAll,
                              selected: _group == null,
                              onTap: () => setState(() => _group = null),
                            ),
                            for (final g in groups)
                              _FilterChip(
                                label: g.name,
                                selected: _group == g.id,
                                onTap: () => setState(() => _group = g.id),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: shown.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 40),
                              child: Text(
                                context.l10n.albumCoverNone,
                                style: TextStyle(color: t.text3, fontSize: 15),
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(2, 2, 2, 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            itemCount: shown.length,
                            itemBuilder: (_, i) => Semantics(
                              button: true,
                              label: context.l10n.albumSetCover,
                              child: GestureDetector(
                                onTap: () => _pick(shown[i]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    Radii.image,
                                  ),
                                  child: StoredImage(
                                    shown[i].file,
                                    cacheWidth: 300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? t.ink : t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? t.surface : t.text2,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
