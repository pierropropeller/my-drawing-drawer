import 'package:flutter/material.dart';

import '../common/sensitive_gate.dart';

import '../../l10n/l10n.dart';
import '../album/album_image.dart';
import 'ref_image.dart';
import 'ref_palette.dart';

/// 同冊圖片的縮圖列：<840 放底部橫排（縮圖 52），≥840 放左邊直排（縮圖 64～72）。
/// 選中的縮圖有 accent 外框、其餘 70% 透明；選中項目會自動捲進可視範圍。
class RefFilmstrip extends StatefulWidget {
  const RefFilmstrip({
    super.key,
    required this.images,
    required this.index,
    required this.onPick,
    required this.palette,
    required this.accent,
    this.vertical = false,
    this.thumb = 52,
  });

  final List<RefImage> images;
  final int index;
  final ValueChanged<int> onPick;
  final RefPalette palette;
  final Color accent;
  final bool vertical;
  final double thumb;

  @override
  State<RefFilmstrip> createState() => _RefFilmstripState();
}

class _RefFilmstripState extends State<RefFilmstrip> {
  final _scroll = ScrollController();

  double get _gap => widget.vertical ? 10 : 8;
  double get _extent => widget.thumb + _gap;

  @override
  void didUpdateWidget(RefFilmstrip old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final start = widget.index * _extent;
      final end = start + widget.thumb;
      final viewStart = pos.pixels;
      final viewEnd = viewStart + pos.viewportDimension;
      double? target;
      if (start < viewStart) {
        target = start - _gap;
      } else if (end > viewEnd) {
        target = end - pos.viewportDimension + _gap;
      }
      if (target != null) {
        _scroll.animateTo(
          target.clamp(0, pos.maxScrollExtent),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vertical = widget.vertical;
    return Semantics(
      label: l10n.refviewFilmstrip,
      container: true,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
        padding: vertical
            ? const EdgeInsets.symmetric(vertical: 8)
            : const EdgeInsets.fromLTRB(10, 12, 10, 4),
        itemCount: widget.images.length,
        separatorBuilder: (_, _) =>
            SizedBox(width: vertical ? 0 : _gap, height: vertical ? _gap : 0),
        itemBuilder: (context, i) {
          final selected = i == widget.index;
          final im = widget.images[i];
          final file = im.staticFile;
          final thumb = ClipRRect(
            borderRadius: BorderRadius.circular(vertical ? 12 : 10),
            child: file == null
                ? ColoredBox(color: widget.palette.chip)
                : SensitiveGate(
                    file: file,
                    circleSize: 24,
                    child: StoredImage(
                      file,
                      cacheWidth: (widget.thumb * 3).round(),
                      showDownloadBadge: false,
                      placeholderColor: widget.palette.chip,
                    ),
                  ),
          );
          return Center(
            child: Semantics(
              button: true,
              selected: selected,
              label: l10n.refviewImageN(i + 1),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onPick(i),
                child: Opacity(
                  opacity: selected ? 1 : (vertical ? .65 : .7),
                  child: SizedBox(
                    width: widget.thumb,
                    height: widget.thumb,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        thumb,
                        if (selected)
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  vertical ? 12 : 10,
                                ),
                                border: Border.all(
                                  color: widget.accent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
