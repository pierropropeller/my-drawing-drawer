import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_view.dart' show ChipRow;
import '../common/app_icons.dart';
import '../common/media_widgets.dart';
import '../common/svg_icon.dart';
import '../material/material_category.dart';

/// 「從素材庫選取」的選擇 sheet（MediaMenu 第三項，設計稿沒有畫這張 sheet）。
///
/// 分類 chips 篩選、點格子多選（按點選的次序給序號）、底部「加入 N 張」。
/// 回傳依點選次序排好的素材；關閉回傳 null。
Future<List<MaterialImage>?> showMaterialPickSheet(BuildContext context) {
  final t = context.tokens;
  return showModalBottomSheet<List<MaterialImage>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: t.ground,
    barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const MaterialPickSheet(),
  );
}

class MaterialPickSheet extends ConsumerStatefulWidget {
  const MaterialPickSheet({super.key});

  @override
  ConsumerState<MaterialPickSheet> createState() => _MaterialPickSheetState();
}

class _MaterialPickSheetState extends ConsumerState<MaterialPickSheet> {
  MaterialCategory? _category;

  /// 依點選次序的 id；換分類篩選時保留。
  final List<String> _order = [];
  final Map<String, MaterialImage> _byId = {};

  void _toggle(MaterialImage m) {
    setState(() {
      _byId[m.id] = m;
      if (!_order.remove(m.id)) _order.add(m.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final rows = ref.watch(materialsProvider(_category)).value ?? const [];
    final total = ref.watch(materialCountsProvider).value?.total ?? 0;
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: SizedBox(
        height: height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.ipadmediaMaterials,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: l.commonClose,
                    icon: SvgIcon(
                      AppIcons.closeX,
                      size: 22,
                      color: t.ink,
                      strokeWidth: 2,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            ChipRow(
              options: [
                for (final c in MaterialCategory.values) (c.name, c.label(l)),
              ],
              selected: _category?.name,
              onSelected: (v) => setState(
                () => _category = v == null
                    ? null
                    : MaterialCategory.values.firstWhere((c) => c.name == v),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        l.ipadmediaMaterialsEmpty,
                        key: const Key('material-pick-empty'),
                        style: TextStyle(color: t.text3, fontSize: 14),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 120,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final n = _order.indexOf(r.id);
                        return GestureDetector(
                          key: ValueKey('material-pick-${r.id}'),
                          onTap: () => _toggle(r),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  Radii.image,
                                ),
                                child: MediaThumb(
                                  MediaSource.row(
                                    file: r.imageFile,
                                    kind: r.kind,
                                    durationMs: r.durationMs,
                                    posterFile: r.posterFile,
                                    width: r.width,
                                    height: r.height,
                                  ),
                                  cacheWidth: 300,
                                  animate: false,
                                ),
                              ),
                              if (n >= 0) ...[
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      Radii.image,
                                    ),
                                    border: Border.all(
                                      color: t.accent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: t.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${n + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  key: const Key('material-pick-confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: t.accent.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _order.isEmpty || total == 0
                      ? null
                      : () =>
                            Navigator.of(context)
                                .pop([for (final id in _order) _byId[id]!]),
                  child: Text(
                    l.ipadmediaMaterialsAdd(_order.length),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
