import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart' show showSnack;
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/media_widgets.dart';
import '../common/svg_icon.dart';
import '../common/themed_sheet.dart';
import '../common/window_class.dart';
import 'pit_type_widgets.dart';
import 'pits_icons.dart';

/// 主頁編輯排序時點坑封面：更換封面 bottom sheet（D-132，MainSortCover）。
/// 點一張圖＝立即設為坑的封面；淺坑多「從相簿選擇」；有封面時最底是「移除封面」。
/// 動作生效後關掉 sheet、出提示條（人留在主頁）。
Future<void> showPitCoverSheet(BuildContext context, Pit pit) {
  final tablet = !WindowClass.of(context).isCompact;
  final h = MediaQuery.sizeOf(context).height;
  return showThemedSheet<void>(
    context: context,
    useRootNavigator: true,
    radius: 24,
    constraints: BoxConstraints(
      maxWidth: tablet ? 640 : double.infinity,
      maxHeight: (h * 0.76).clamp(320.0, 640.0),
    ),
    builder: (_) =>
        _PitCoverSheet(pitId: pit.id, tablet: tablet, host: context),
  );
}

class _PitCoverSheet extends ConsumerStatefulWidget {
  const _PitCoverSheet({
    required this.pitId,
    required this.tablet,
    required this.host,
  });
  final String pitId;
  final bool tablet;

  /// 主頁的 context：sheet 關掉後提示條出在主頁。
  final BuildContext host;

  @override
  ConsumerState<_PitCoverSheet> createState() => _PitCoverSheetState();
}

class _PitCoverSheetState extends ConsumerState<_PitCoverSheet> {
  String? _kind; // null＝全部；official／fan／piece

  Future<void> _done(Future<void> Function() write, String msg) async {
    final nav = Navigator.of(context);
    final host = widget.host;
    await write();
    if (!mounted) return;
    nav.pop();
    if (host.mounted) showSnack(host, msg, success: true);
  }

  Future<void> _pickGallery() async {
    final file = await pickShallowCoverFile(context, ref);
    if (file == null || !mounted) return;
    final db = ref.read(databaseProvider);
    await _done(
      () => db.setPitCoverFile(widget.pitId, file),
      context.l10n.albumCoverSet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final pit = ref.watch(pitProvider(widget.pitId)).value;
    final shown =
        ref.watch(coverCandidatesProvider((widget.pitId, _kind))).value ??
        const <CoverCandidate>[];
    final coverFile = ref.watch(coverFileProvider(widget.pitId)).value;
    final db = ref.read(databaseProvider);
    final hasCover = pit != null && pit.hasCoverRef;
    final currentId = (pit?.coverFile ?? '').isNotEmpty
        ? null
        : pit?.coverImageId;
    final padH = widget.tablet ? 28.0 : 20.0;
    final cols = widget.tablet ? 4 : 3;
    final gap = widget.tablet ? 10.0 : 8.0;
    final radius = widget.tablet ? 14.0 : 12.0;

    Widget chip(String label, String? kind) {
      final on = _kind == kind;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _kind = kind),
        child: Container(
          height: widget.tablet ? 36 : 32,
          padding: EdgeInsets.symmetric(horizontal: widget.tablet ? 15 : 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? t.ink : t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? t.surface : t.text2,
              fontSize: widget.tablet ? 13 : 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final actions = <Widget>[
      if (pit != null && pit.isShallow)
        _SheetButton(
          key: const ValueKey('pitCoverSheetAlbum'),
          icon: AppIcons.image,
          label: l.ipadpitPickFromAlbum,
          outlined: true,
          onTap: _pickGallery,
        ),
      if (hasCover)
        _SheetButton(
          key: const ValueKey('pitCoverSheetRemove'),
          icon: PitsIcons.trash,
          label: l.pitsortCoverRemove,
          color: t.accentStrong,
          onTap: () => _done(
            () => db.setCover(widget.pitId, null),
            l.pitsortCoverRemoved,
          ),
        ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padH, 10, padH, widget.tablet ? 28 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: widget.tablet ? 18 : 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(widget.tablet ? 12 : 10),
                  child: SizedBox.square(
                    dimension: widget.tablet ? 48 : 44,
                    child: PitCoverImage(
                      file: coverFile,
                      hasCoverRef: hasCover,
                      cacheWidth: 144,
                      placeholderColor: t.fanArt.bg,
                      fallback: ColoredBox(color: t.fanArt.bg),
                    ),
                  ),
                ),
                SizedBox(width: widget.tablet ? 14 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.pitsortCoverTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: widget.tablet ? 21 : 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        pit?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.tablet ? 13 : 12.5,
                          color: t.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.tablet ? 18 : 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  chip(l.commonAll, null),
                  chip(l.pitsOfficial, 'official'),
                  chip(l.pitsFanArt, 'fan'),
                  chip(l.searchCategoryPiece, 'piece'),
                ],
              ),
            ),
            SizedBox(height: widget.tablet ? 14 : 12),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        l.albumCoverNone,
                        style: TextStyle(color: t.text3, fontSize: 14),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(2),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final c = shown[i];
                        final on = c.id == currentId;
                        return Semantics(
                          button: true,
                          selected: on,
                          label: l.albumSetCover,
                          child: GestureDetector(
                            onTap: () => _done(
                              () => db.setCover(widget.pitId, c.id),
                              l.albumCoverSet,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(radius),
                                  child: StaticMediaImage(
                                    MediaSource(
                                      file: c.file,
                                      kind: c.kind,
                                      durationMs: c.durationMs,
                                      poster: c.poster,
                                    ),
                                    cacheWidth: 300,
                                  ),
                                ),
                                if (on) ...[
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        radius,
                                      ),
                                      border: Border.all(
                                        color: t.accent,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      width: widget.tablet ? 24 : 22,
                                      height: widget.tablet ? 24 : 22,
                                      decoration: BoxDecoration(
                                        color: t.accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: SvgIcon(
                                          PitsIcons.check,
                                          size: widget.tablet ? 14 : 13,
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: t.chipBg),
              SizedBox(height: widget.tablet ? 16 : 14),
              if (widget.tablet)
                Row(
                  spacing: 12,
                  children: [for (final a in actions) Expanded(child: a)],
                )
              else
                Column(spacing: 10, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.color,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = color ?? t.ink;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: outlined
              ? BoxDecoration(
                  color: t.surface,
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              SvgIcon(icon, size: 18, color: fg),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
