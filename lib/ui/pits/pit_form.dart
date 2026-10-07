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
    filled: true,
    fillColor: t.surface,
    enabledBorder: b(t.border),
    focusedBorder: b(t.accent),
    errorBorder: b(t.danger),
    focusedErrorBorder: b(t.danger),
  );
}
