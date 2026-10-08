import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/payment.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/image_picker_field.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/svg_icon.dart';
import 'entity_widgets.dart';
import 'piece_icons.dart';

String pieceHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// 表單輸入框的邊線色（淺色 #E3D8C9，深色用 border）。
Color pieceFieldLine(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.tokens.border
    : const Color(0xFFE3D8C9);

// ---- 幣種 -------------------------------------------------------------

const pieceCurrencies = ['CNY', 'HKD', 'TWD', 'USD', 'JPY', 'EUR'];

String pieceCurrencySymbol(String code) => switch (code) {
  'CNY' => '¥',
  'HKD' => 'HK\$',
  'TWD' => 'NT\$',
  'USD' => 'US\$',
  'JPY' => 'JP¥',
  'EUR' => '€',
  _ => code,
};

/// 數字轉成輸入框文字：整數不帶小數點。
String pieceNumberText(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// 「¥ 1,200」。
String formatPieceMoney(String currency, double v) {
  final text = pieceNumberText(v);
  final parts = text.split('.');
  final intPart = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final num = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return '${pieceCurrencySymbol(currency)} $num';
}

/// 選擇幣種的 bottom sheet；取消回傳 null。
Future<String?> showCurrencySheet(BuildContext context, String current) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final c in pieceCurrencies)
              ListTile(
                title: Text('${pieceCurrencySymbol(c)} $c'),
                trailing: SelectDot(c == current),
                onTap: () => Navigator.pop(ctx, c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

// ---- 表單元件 -----------------------------------------------------------

/// 開關卡片（PieceNew）：白底、1px 邊、圓角 16；標題列 15/600＋開關，
/// 開啟時下方以細線分隔展開 [child]。
class PieceSwitchCard extends StatelessWidget {
  const PieceSwitchCard({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.child,
    this.bottomGap = 12,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final divider = Theme.of(context).brightness == Brightness.dark
        ? t.border
        : const Color(0xFFF1EADF);
    return Container(
      margin: EdgeInsets.only(bottom: bottomGap),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderCard),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppSwitch(
                  value: value,
                  onChanged: onChanged,
                  semanticLabel: title,
                ),
              ],
            ),
          ),
          if (value)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: divider)),
              ),
              padding: const EdgeInsets.only(top: 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// 日期欄：日期文字＋日曆 icon，點了開日期選擇。
class PieceDateField extends StatelessWidget {
  const PieceDateField({
    super.key,
    required this.date,
    required this.onChanged,
    this.emptyText,
    this.semanticLabel,
  });
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;

  /// 沒選日期時的文字；沒傳時用「選擇日期」。
  final String? emptyText;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: date ?? now,
            firstDate: DateTime(2000),
            lastDate: now.add(const Duration(days: 365 * 3)),
          );
          if (d != null) onChanged(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: pieceFieldLine(context)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  date == null
                      ? (emptyText ?? context.l10n.pieceDateEmpty)
                      : fmtSlash(date!),
                  style: TextStyle(
                    fontSize: 15,
                    color: date == null ? t.text4 : t.ink,
                  ),
                ),
              ),
              SvgIcon(
                PieceIcons.calendar,
                size: 19,
                strokeWidth: 1.7,
                color: t.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 輸入框的無框樣式（包在自己畫外框的容器裡）。
const pieceBareInput = InputDecoration(
  isDense: true,
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  contentPadding: EdgeInsets.symmetric(vertical: 12),
);

/// 外框容器：白底、邊線、圓角 12、左右內距 14。
class PieceBoxField extends StatelessWidget {
  const PieceBoxField({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: context.tokens.surface,
      border: Border.all(color: pieceFieldLine(context)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

/// 互動量欄：愛心＋數字輸入＋右側「紅心」。
class PieceHeartField extends StatelessWidget {
  const PieceHeartField({
    super.key,
    required this.controller,
    required this.semanticLabel,
    this.fieldKey,
  });
  final TextEditingController controller;
  final Key? fieldKey;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: PieceBoxField(
            child: Row(
              children: [
                SvgIcon(
                  AppIcons.heart,
                  size: 18,
                  strokeWidth: 0,
                  color: t.accent,
                  fill: pieceHex(t.accent),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Semantics(
                    label: semanticLabel,
                    child: TextField(
                      key: fieldKey,
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 15),
                      decoration: pieceBareInput,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          context.l10n.pieceHeartUnit,
          style: TextStyle(fontSize: 13, color: t.text3),
        ),
      ],
    );
  }
}

/// 表單圖片區（PieceNew）：84px 縮圖圓角 12，右上角 22px 墨色圓鈕「×」（D-018）
/// 外凸 6px、2px 底色邊框；尾端虛線「＋」。
class PieceImageGrid extends StatelessWidget {
  const PieceImageGrid({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });
  final List<ImageItem> items;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  static const double size = 84;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++)
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.image),
                  child: items[i].picked != null
                      ? Image.file(
                          File(items[i].picked!.path),
                          cacheWidth: 300,
                          fit: BoxFit.cover,
                        )
                      : StoredImage(items[i].stored!.file, cacheWidth: 300),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Semantics(
                    button: true,
                    label: context.l10n.entityRemoveImage,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: t.ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.ground, width: 2),
                        ),
                        child: Center(
                          child: SvgIcon(
                            AppIcons.closeX,
                            size: 11,
                            strokeWidth: 3,
                            color: t.ground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        DashedAddTile(
          size: size,
          onTap: onAdd,
          semanticLabel: context.l10n.pieceAddImage,
          iconSize: 26,
        ),
      ],
    );
  }
}

// ---- 收款狀態 -----------------------------------------------------------

/// 收款狀態小膠囊（IncomeYear 的說法）：未收／已收 ¥ 300／已收齊。
class PaymentChip extends StatelessWidget {
  const PaymentChip({super.key, required this.state, required this.currency});
  final PaymentState state;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (Color bg, Color fg, String text) = switch (state.status) {
      PaymentStatus.unpaid => (
        dark ? const Color(0xFF4A2A26) : const Color(0xFFF9E1DC),
        dark ? const Color(0xFFF08A76) : const Color(0xFFC0392B),
        context.l10n.piecePaymentUnpaid,
      ),
      PaymentStatus.partial => (
        dark ? const Color(0xFF383126) : const Color(0xFFF1EAD9),
        dark ? const Color(0xFFD6B267) : const Color(0xFFA9812F),
        context.l10n.piecePaymentPartial(
          formatPieceMoney(currency, state.received),
        ),
      ),
      PaymentStatus.paid => (
        dark ? const Color(0xFF2D3324) : const Color(0xFFE6EBDC),
        dark ? const Color(0xFFADBD8C) : const Color(0xFF5C7A44),
        context.l10n.piecePaymentPaid,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// 設計稿 `.chip`／`.chip.on`：外框 1px、13/500；選中＝主色底白字。
class PieceChipButton extends StatelessWidget {
  const PieceChipButton({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.radius = 12,
    this.horizontal = 16,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;
  final double radius;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? t.accent : t.surface,
            border: Border.all(color: on ? t.accent : t.border),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: on ? Colors.white : t.text2,
            ),
          ),
        ),
      ),
    );
  }
}
