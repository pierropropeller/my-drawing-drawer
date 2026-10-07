import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/empty_state.dart';
import '../common/responsive.dart';
import '../common/user_avatar.dart';
import '../../state/settings.dart';
import 'pit_new_page.dart';
import 'pit_page.dart';

/// 主頁：現坑／封存坑、田字／瀑布切換、坑卡片、開新坑。
class PitsPage extends ConsumerStatefulWidget {
  const PitsPage({super.key});

  @override
  ConsumerState<PitsPage> createState() => _PitsPageState();
}

class _PitsPageState extends ConsumerState<PitsPage> {
  bool _archived = false;
  bool _grid = true; // true＝田字，false＝瀑布（單欄）

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pits = ref.watch(pitsProvider(_archived));
    return Scaffold(
      floatingActionButton: _archived
          ? null
          : FloatingActionButton.extended(
              backgroundColor: t.accent,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PitNewPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('開新坑'),
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  const UserAvatar(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ref
                              .watch(settingsProvider.select((s) => s.nickname))
                              .isEmpty
                          ? '我的坑'
                          : ref.watch(
                              settingsProvider.select((s) => s.nickname),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: _grid ? '切換為瀑布' : '切換為田字',
                    onPressed: () => setState(() => _grid = !_grid),
                    icon: Icon(
                      _grid ? Icons.view_agenda_outlined : Icons.grid_view,
                      color: t.text2,
                    ),
                  ),
                ],
              ),
            ),
            // 離線時顯示橫條，不用彈窗；沒有手動備份按鈕。
            if (ref.watch(onlineProvider).value == false)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: t.chipBg,
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 16, color: t.text2),
                    const SizedBox(width: 8),
                    Text(
                      '離線中・恢復網絡後將自動上傳',
                      style: TextStyle(color: t.text2, fontSize: 13),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: '現坑',
                    selected: !_archived,
                    onTap: () => setState(() => _archived = false),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '封存坑',
                    selected: _archived,
                    onTap: () => setState(() => _archived = true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: pits.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('載入失敗：$e')),
                data: (list) => list.isEmpty
                    ? _Empty(archived: _archived)
                    : _PitList(pits: list, grid: _grid),
              ),
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.chipBg,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : t.text2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.archived});
  final bool archived;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.collections_bookmark_outlined,
    text: archived ? '沒有封存的坑' : '還沒有坑',
    color: context.tokens.piece,
  );
}

class _PitList extends StatelessWidget {
  const _PitList({required this.pits, required this.grid});
  final List<Pit> pits;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(20, 8, 20, 96);
    if (grid) {
      return GridView.builder(
        padding: pad,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          // 手機 2 欄；平板（iPad）3～4 欄。
          crossAxisCount: columnsForWidth(MediaQuery.sizeOf(context).width),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: pits.length,
        itemBuilder: (_, i) => PitCard(pit: pits[i], wide: false),
      );
    }
    return ListView.separated(
      padding: pad,
      itemCount: pits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => PitCard(pit: pits[i], wide: true),
    );
  }
}

class PitCard extends ConsumerWidget {
  const PitCard({super.key, required this.pit, required this.wide});
  final Pit pit;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final stats = ref.watch(pitStatsProvider(pit.id)).value ?? PitStats.empty;
    final coverFile = ref.watch(coverFileProvider(pit.id)).value;
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(Radii.image),
      child: coverFile != null
          ? StoredImage(coverFile, cacheWidth: 400)
          : Container(
              color: t.piece.bg,
              child: Center(
                child: Icon(Icons.image_outlined, color: t.piece.fg, size: 32),
              ),
            ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pit.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          '${stats.pieces} 成圖 · ${stats.openIdeas} 腦洞未孵',
          style: TextStyle(color: t.text3, fontSize: 12),
        ),
      ],
    );
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => PitPage(pitId: pit.id))),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: t.borderCard),
          ),
          child: wide
              ? Row(
                  children: [
                    SizedBox(width: 72, height: 72, child: cover),
                    const SizedBox(width: 12),
                    Expanded(child: text),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SizedBox.expand(child: cover)),
                    const SizedBox(height: 10),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}
