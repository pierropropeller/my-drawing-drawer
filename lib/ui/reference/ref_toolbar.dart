import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/ref_view_queries.dart';
import '../../l10n/l10n.dart';
import '../common/svg_icon.dart';
import 'ref_icons.dart';
import 'ref_palette.dart';

/// 目前縮放百分比（相對 fit；1.8 → 180）。
int refZoomPercent(Matrix4 m) => (m.getMaxScaleOnAxis() * 100).round();

/// 底部工具列（<840）：鎖定縮放／左右翻轉／灰階／背景／更多。
/// [showLabels] false（<600）只有 icon；true（600–839）icon＋文字（RefSplit）。
class RefBottomToolbar extends StatelessWidget {
  const RefBottomToolbar({
    super.key,
    required this.snapshot,
    required this.palette,
    required this.accent,
    required this.showLabels,
    required this.onLock,
    required this.onFlip,
    required this.onGray,
    required this.onBackground,
    required this.onMore,
  });

  final RefViewSnapshot snapshot;
  final RefPalette palette;
  final Color accent;
  final bool showLabels;
  final VoidCallback onLock;
  final VoidCallback onFlip;
  final VoidCallback onGray;
  final VoidCallback onBackground;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Color c(bool on) => on ? accent : palette.off;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        showLabels ? 6 : 8,
        6,
        showLabels ? 6 : 8,
        16,
      ),
      child: Row(
        children: [
          _Tool(
            icon: RefIcons.lock,
            label: l10n.refviewLock,
            color: c(snapshot.locked),
            showLabel: showLabels,
            onTap: onLock,
            selected: snapshot.locked,
          ),
          _Tool(
            icon: RefIcons.flip,
            label: l10n.refviewFlip,
            color: c(snapshot.flipped),
            showLabel: showLabels,
            onTap: onFlip,
            selected: snapshot.flipped,
          ),
          _Tool(
            icon: RefIcons.gray,
            label: l10n.refviewGray,
            color: c(snapshot.gray),
            showLabel: showLabels,
            onTap: onGray,
            selected: snapshot.gray,
          ),
          _Tool(
            icon: RefIcons.background,
            label: l10n.refviewBackground,
            color: palette.fg,
            showLabel: showLabels,
            onTap: onBackground,
            selected: snapshot.lightBg,
          ),
          _Tool(
            icon: RefIcons.more,
            label: l10n.refviewMore,
            color: palette.fg,
            showLabel: showLabels,
            onTap: onMore,
            strokeWidth: 0,
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.color,
    required this.showLabel,
    required this.onTap,
    this.selected,
    this.strokeWidth = 1.8,
  });

  final String icon;
  final String label;
  final Color color;
  final bool showLabel;
  final VoidCallback onTap;
  final bool? selected;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: selected,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: showLabel ? 56 : 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgIcon(icon, size: 22, color: color, strokeWidth: strokeWidth),
                if (showLabel) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 窄版舞台左下角的縮放 pill：「180% · 已鎖定」，點一下切換鎖定。
class RefZoomChip extends StatelessWidget {
  const RefZoomChip({
    super.key,
    required this.transform,
    required this.locked,
    required this.onToggleLock,
  });

  final ValueListenable<Matrix4> transform;
  final bool locked;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Positioned(
      left: 12,
      bottom: 12,
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggleLock,
          // 視覺高 36，點擊區補到 44。
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: RefPalette.floating,
                borderRadius: BorderRadius.circular(999),
              ),
              child: ValueListenableBuilder<Matrix4>(
                valueListenable: transform,
                builder: (context, m, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgIcon(
                      locked ? RefIcons.lock : RefIcons.unlock,
                      size: 15,
                      color: RefPalette.floatingFg,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.refviewZoomState(
                        refZoomPercent(m),
                        locked
                            ? l10n.refviewLockedShort
                            : l10n.refviewUnlockedShort,
                      ),
                      style: const TextStyle(
                        color: RefPalette.floatingFg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ≥840 的舞台下方浮動 pill：鎖定縮放｜100%｜左右翻轉 灰階 背景（RefFull）。
class RefFloatingBar extends StatelessWidget {
  const RefFloatingBar({
    super.key,
    required this.transform,
    required this.snapshot,
    required this.accent,
    required this.onLock,
    required this.onFlip,
    required this.onGray,
    required this.onBackground,
  });

  final ValueListenable<Matrix4> transform;
  final RefViewSnapshot snapshot;
  final Color accent;
  final VoidCallback onLock;
  final VoidCallback onFlip;
  final VoidCallback onGray;
  final VoidCallback onBackground;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Color c(bool on) => on ? accent : RefPalette.floatingOff;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: RefPalette.floating,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Pill(
                  icon: RefIcons.lock,
                  label: snapshot.locked
                      ? l10n.refviewLockedLong
                      : l10n.refviewLock,
                  color: c(snapshot.locked),
                  onTap: onLock,
                  selected: snapshot.locked,
                ),
                ValueListenableBuilder<Matrix4>(
                  valueListenable: transform,
                  builder: (context, m, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '${refZoomPercent(m)}%',
                      style: const TextStyle(
                        color: RefPalette.floatingFg,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 22, color: const Color(0x29FFFFFF)),
                _Pill(
                  icon: RefIcons.flip,
                  label: l10n.refviewFlip,
                  color: c(snapshot.flipped),
                  onTap: onFlip,
                  selected: snapshot.flipped,
                ),
                _Pill(
                  icon: RefIcons.gray,
                  label: l10n.refviewGray,
                  color: c(snapshot.gray),
                  onTap: onGray,
                  selected: snapshot.gray,
                ),
                _Pill(
                  icon: RefIcons.background,
                  label: l10n.refviewBackground,
                  color: RefPalette.floatingOff,
                  onTap: onBackground,
                  selected: snapshot.lightBg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.selected,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
