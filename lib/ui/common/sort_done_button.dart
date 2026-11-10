import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';

/// 編輯排序右上的「完成」膠囊鈕（MainSortEdit／AlbumSortEdit）。[big]＝平板（高 44）。
class SortDoneButton extends StatelessWidget {
  const SortDoneButton({super.key, required this.onTap, this.big = false});
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: big ? 44 : 38,
          padding: EdgeInsets.symmetric(horizontal: big ? 22 : 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.accent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            context.l10n.commonDone,
            style: TextStyle(
              color: Colors.white,
              fontSize: big ? 15 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
