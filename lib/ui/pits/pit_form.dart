import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';

/// 設計稿輸入框外框色 #E3D8C9（深色沿用 border token）。
Color fieldBorderColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.tokens.border
    : const Color(0xFFE3D8C9);

/// 設計稿 `.fld`：白底、1px 邊、圓角 12、內距 12×14、字 15。
InputDecoration pitInputDecoration(BuildContext context, {String? label}) {
  final t = context.tokens;
  OutlineInputBorder b(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    labelText: label,
    // 多行輸入框的標籤靠左上（預設是左中）。
    alignLabelWithHint: true,
    filled: true,
    fillColor: t.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: b(fieldBorderColor(context)),
    focusedBorder: b(t.accent),
    errorBorder: b(t.danger),
    focusedErrorBorder: b(t.danger),
  );
}

/// 其他表單沿用的帶標籤輸入框樣式。
InputDecoration pitFieldDecoration(BuildContext context, String label) =>
    pitInputDecoration(context, label: label);

/// 輸入框上方的小標題（13、粗體、text2）。
class PitFieldLabel extends StatelessWidget {
  const PitFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.tokens.text2,
      ),
    ),
  );
}

/// 子頁面標題列：返回箭頭＋襯線標題（開新坑／編輯坑）。
class PitHeader extends StatelessWidget {
  const PitHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: context.l10n.commonBack,
            child: InkResponse(
              onTap: () => Navigator.of(context).maybePop(),
              radius: 24,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgIcon(
                    AppIcons.back,
                    strokeWidth: 1.9,
                    color: context.tokens.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 滿版主色按鈕（建立／儲存）。
class PitPrimaryButton extends StatelessWidget {
  const PitPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
