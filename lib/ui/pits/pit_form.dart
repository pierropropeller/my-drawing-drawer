import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

InputDecoration pitFieldDecoration(BuildContext context, String label) {
  final t = context.tokens;
  OutlineInputBorder b(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.button),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    labelText: label,
    // 多行輸入框的標籤靠左上（預設是左中）。
    alignLabelWithHint: true,
    filled: true,
    fillColor: t.surface,
    enabledBorder: b(t.border),
    focusedBorder: b(t.accent),
    errorBorder: b(t.danger),
    focusedErrorBorder: b(t.danger),
  );
}
