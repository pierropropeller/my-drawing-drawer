import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trash_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart';
import '../album/preview_shell.dart';
import '../common/app_icons.dart';
import '../common/media_source.dart';
import '../common/nav_bar_hidden.dart';
import 'trash_page.dart';

/// 預覽頁「剩 N 天」的琥珀色（TrashPreview 稿 `#E2B65C`，深色底用）。
const _warnOnDark = Color(0xFFE2B65C);

/// 最近刪除的預覽（TrashPreview 稿）：深色全屏，標題＝位置（「坑A · 好看同人圖」），
/// 右上琥珀色「剩 N 天」，底部「YYYY / MM / DD 刪除」，動作只有 還原／永久刪除。
/// 多張圖的項目可以左右滑；沒有圖的腦洞中間顯示標題與內文。
class TrashPreviewPage extends ConsumerStatefulWidget {
  const TrashPreviewPage({super.key, required this.item});
  final TrashItem item;

  @override
  ConsumerState<TrashPreviewPage> createState() => _TrashPreviewPageState();
}

class _TrashPreviewPageState extends ConsumerState<TrashPreviewPage>
    with HidesNavBar<TrashPreviewPage> {
  final _controller = PageController();
  int _index = 0;

  TrashItem get _item => widget.item;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _location(BuildContext context) {
    final l = context.l10n;
    final cell = switch (_item.kind) {
      TrashKind.official => l.pitsOfficial,
      TrashKind.fan => l.pitsFanArt,
      TrashKind.junk => l.junkTitle,
      TrashKind.idea => l.pitsIdeas,
      TrashKind.draft => l.pitsDrafts,
      TrashKind.piece => l.pitsPieces,
      TrashKind.oshi => l.pitsCellOshi,
      TrashKind.material => l.materialTitle,
    };
    final pitId = _item.pitId;
    if (pitId == null) return cell;
    final pit = ref.watch(pitProvider(pitId)).value?.name;
    return pit == null ? cell : l.albumTitleWithPit(pit, cell);
  }

  Future<void> _restore() async {
    await TrashActions(ref).restore(items: [_item]);
    if (!mounted) return;
    showSnack(context, context.l10n.trashRestoredSnack, success: true);
    Navigator.of(context).maybePop();
  }

  Future<void> _purge() async {
    final l = context.l10n;
    final ok = await confirmPurge(
      context,
      title: l.trashPurgeTitle(1),
      body: l.trashPurgeBody,
    );
    if (!ok || !mounted) return;
    await TrashActions(ref).purge(items: [_item]);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = _item.deletedAt.toLocal();
    final days = trashDaysLeft(_item.deletedAt);
    final body = (_item.body ?? '').trim();
    return PreviewShell(
      title: _location(context),
      counter: l.trashDaysLeft(days),
      counterColor: days <= kTrashWarnDays ? _warnOnDark : PreviewPalette.muted,
      controller: _controller,
      media: [for (final r in _item.images) MediaSource.fromImageRef(r)],
      currentIndex: _index,
      onPageChanged: (i) => setState(() => _index = i),
      emptyMedia: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trashItemTitle(_item),
                style: const TextStyle(
                  color: PreviewPalette.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (body.isNotEmpty && body != trashItemTitle(_item)) ...[
                const SizedBox(height: 12),
                Text(
                  body,
                  style: const TextStyle(
                    color: PreviewPalette.action,
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      info: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
        child: Text(
          l.trashDeletedOn(
            d.year,
            d.month.toString().padLeft(2, '0'),
            d.day.toString().padLeft(2, '0'),
          ),
          style: const TextStyle(color: PreviewPalette.muted, fontSize: 11.5),
        ),
      ),
      actions: [
        PreviewAction(AppIcons.restore, l.trashRestore, _restore),
        PreviewAction(
          AppIcons.trash,
          l.trashPurge,
          _purge,
          color: PreviewPalette.danger,
        ),
      ],
    );
  }
}
