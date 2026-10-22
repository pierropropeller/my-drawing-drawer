import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/svg_icon.dart';
import 'pit_form.dart';
import 'pits_icons.dart';

/// 淺坑／封存坑（D-088）的共用小元件：類型分段、格子開關清單、雜物開關、關閉格子的確認框。

/// 一個格子的顯示資料（名稱、icon、分類色）。
class PitSectionMeta {
  const PitSectionMeta(this.key, this.label, this.svg, this.color);
  final PitSectionKey key;
  final String label;
  final String svg;
  final CategoryColor color;
}

PitSectionMeta pitSectionMeta(BuildContext context, PitSectionKey key) {
  final t = context.tokens;
  final l = context.l10n;
  return switch (key) {
    PitSectionKey.official => PitSectionMeta(
      key,
      l.pitsOfficial,
      AppIcons.pitOfficial,
      t.official,
    ),
    PitSectionKey.fan => PitSectionMeta(
      key,
      l.pitsFanArt,
      AppIcons.pitFanArt,
      t.fanArt,
    ),
    PitSectionKey.idea => PitSectionMeta(
      key,
      l.pitsIdeas,
      AppIcons.pitIdea,
      t.idea,
    ),
    PitSectionKey.draft => PitSectionMeta(
      key,
      l.pitsDrafts,
      AppIcons.edit,
      t.draft,
    ),
    PitSectionKey.piece => PitSectionMeta(
      key,
      l.pitsPieces,
      AppIcons.pitPieceEmpty,
      t.piece,
    ),
    PitSectionKey.oshi => PitSectionMeta(
      key,
      l.pitsCellOshi,
      PitsIcons.oshi,
      t.oshi,
    ),
    PitSectionKey.junk => PitSectionMeta(
      key,
      l.junkTitle,
      PitsIcons.junk,
      CategoryColor(t.chipBg, t.text3),
    ),
  };
}

/// 類型分段（坑｜淺坑｜封存）。[allowArchive] 為 false 時只有前兩個（開新坑）。
class PitTypeSegment extends StatelessWidget {
  const PitTypeSegment({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowArchive = true,
  });
  final PitStatus value;
  final ValueChanged<PitStatus> onChanged;
  final bool allowArchive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final items = <(PitStatus, String)>[
      (PitStatus.active, l.shallowTypePit),
      (PitStatus.shallow, l.shallowName),
      if (allowArchive) (PitStatus.archived, l.shallowTypeArchive),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PitFieldLabel(l.shallowTypeLabel),
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: t.chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == items[i].$1,
                    label: items[i].$2,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(items[i].$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: value == items[i].$1
                              ? t.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: value == items[i].$1
                              ? const [
                                  BoxShadow(
                                    color: Color(0x1F2B2622),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          items[i].$2,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: value == items[i].$1 ? t.ink : t.text3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 一列：34px 圓角 10 的 icon 方塊＋名稱＋開關。
class PitSectionSwitchRow extends StatelessWidget {
  const PitSectionSwitchRow({
    super.key,
    required this.meta,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final PitSectionMeta meta;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: meta.color.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: SvgIcon(
            meta.svg,
            size: 18,
            strokeWidth: 1.7,
            color: meta.color.fg,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: t.text4),
                  ),
                ),
            ],
          ),
        ),
        AppSwitch(
          semanticLabel: meta.label,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 白底圓角卡（16）：淺坑的「開啟的格子」清單（七個格子，預設全關）。
class PitSectionSwitchList extends StatelessWidget {
  const PitSectionSwitchList({
    super.key,
    required this.enabled,
    required this.onChanged,
    this.sensitive,
    this.onSensitiveChanged,
  });
  final Set<PitSectionKey> enabled;

  /// 敏感內容開關（D-104）：null＝不顯示（總開關關著）；否則在同一張卡最後多一列。
  final bool? sensitive;
  final ValueChanged<bool>? onSensitiveChanged;

  /// 使用者撥動某個開關（`true`＝要開）。關掉有內容的格子的確認框由呼叫端處理。
  final void Function(PitSectionKey key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final keys = PitSectionKey.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PitFieldLabel(l.shallowFieldSections),
        Container(
          margin: const EdgeInsets.only(bottom: 22),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < keys.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: i == keys.length - 1
                      ? null
                      : BoxDecoration(
                          border: Border(bottom: BorderSide(color: t.border)),
                        ),
                  child: PitSectionSwitchRow(
                    meta: pitSectionMeta(context, keys[i]),
                    value: enabled.contains(keys[i]),
                    onChanged: (v) => onChanged(keys[i], v),
                  ),
                ),
              if (sensitive != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.border)),
                  ),
                  child: PitSensitiveSwitchRow(
                    value: sensitive!,
                    onChanged: onSensitiveChanged!,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 現坑的「雜物」開關：左邊補上雜物箱 icon（34px，`chipBg` 底），白底圓角卡（16）。
class PitJunkSwitchCard extends StatelessWidget {
  const PitJunkSwitchCard({
    super.key,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.sensitive,
    this.onSensitiveChanged,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  /// 敏感內容開關（D-104，`PitEditR18`）：null＝不顯示（總開關關著）；否則在同一張卡「雜物」下面多一列。
  final bool? sensitive;
  final ValueChanged<bool>? onSensitiveChanged;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        children: [
          Padding(
            padding: sensitive == null
                ? EdgeInsets.zero
                : const EdgeInsets.only(bottom: 10),
            child: PitSectionSwitchRow(
              meta: pitSectionMeta(context, PitSectionKey.junk),
              value: value,
              onChanged: onChanged,
              subtitle: subtitle,
            ),
          ),
          if (sensitive != null)
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.border)),
              ),
              child: PitSensitiveSwitchRow(
                value: sensitive!,
                onChanged: onSensitiveChanged!,
              ),
            ),
        ],
      ),
    );
  }
}

/// 「敏感內容」開關列（D-104，`PitEditR18`）：34px 圓角 10 的 icon 方塊（同人圖色）＋名稱＋開關。
class PitSensitiveSwitchRow extends StatelessWidget {
  const PitSensitiveSwitchRow({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = context.l10n.sensitiveTitle;
    return Row(
      key: const ValueKey('pitSensitiveRow'),
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: t.fanArt.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: SvgIcon(
            AppIcons.eyeSlash,
            size: 18,
            strokeWidth: 1.9,
            color: t.fanArt.fg,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
        AppSwitch(
          key: const ValueKey('pitSensitiveSwitch'),
          semanticLabel: label,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 只有「敏感內容」一列的白底圓角卡（封存坑沒有雜物／格子開關，仍可開關敏感內容）。
class PitSensitiveCard extends StatelessWidget {
  const PitSensitiveCard({
    super.key,
    required this.value,
    required this.onChanged,
    this.radius = 16,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: PitSensitiveSwitchRow(value: value, onChanged: onChanged),
    );
  }
}

/// 某格子目前內容數量的說明：「3 張圖」「2 個腦洞」「5 份摸魚」「4 張成圖」「6 筆推活」。
String pitSectionCountText(BuildContext context, PitSectionKey key, int n) {
  final l = context.l10n;
  return switch (key) {
    PitSectionKey.official ||
    PitSectionKey.fan ||
    PitSectionKey.junk => l.shallowCountImages(n),
    PitSectionKey.idea => l.shallowCountIdeas(n),
    PitSectionKey.draft => l.shallowCountDrafts(n),
    PitSectionKey.piece => l.shallowCountPieces(n),
    PitSectionKey.oshi => l.shallowCountOshi(n),
  };
}

/// 關閉有內容的格子前的確認框（PitEditShallowOff）：回傳 true＝同意「關閉並刪除」。
Future<bool> confirmCloseSection(
  BuildContext context,
  PitSectionKey key,
  int count,
) async {
  final t = context.tokens;
  final l = context.l10n;
  final label = pitSectionMeta(context, key).label;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      title: Text(
        l.shallowCloseTitle(label),
        style: Theme.of(ctx).textTheme.titleLarge
            ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Text(
        l.shallowCloseBody(pitSectionCountText(ctx, key, count)),
        style: TextStyle(fontSize: 14, color: t.ink, height: 1.65),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            l.commonCancel,
            style: TextStyle(
              color: t.text2,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            l.shallowCloseConfirm,
            style: TextStyle(
              color: t.danger,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

/// 坑名旁邊的灰色小標「淺坑」。
class ShallowBadge extends StatelessWidget {
  const ShallowBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.shallowName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.text2,
        ),
      ),
    );
  }
}

/// 淺坑一個格子都沒開時的空白狀態（PitShallowEmpty）：四格 icon、說明、「開啟格子」（去編輯坑）。
class ShallowEmptyState extends StatelessWidget {
  const ShallowEmptyState({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: t.chipBg,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: SvgIcon(
                  PitsIcons.emptyCells,
                  size: 42,
                  strokeWidth: 1.5,
                  color: t.text3,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l.shallowEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onOpen,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SvgIcon(
                      AppIcons.plus,
                      size: 18,
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.shallowEmptyAction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
