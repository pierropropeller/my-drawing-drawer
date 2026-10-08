import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';

/// 圖冊表單頁骨架（OfficialNew）：返回＋襯線標題 20px、可捲動內容（內距 20,8,20,24）。
/// 表單頁沒有底部導覽列，由各頁的 State 加 `HidesNavBar`。
class AlbumFormScaffold extends StatelessWidget {
  const AlbumFormScaffold({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 58,
        titleSpacing: 6,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: IconButton(
            tooltip: '返回',
            padding: EdgeInsets.zero,
            icon: SvgIcon(AppIcons.back, color: t.ink, strokeWidth: 1.9),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: children,
      ),
    );
  }
}

/// 欄位上方的小標題（13、粗體、text2）。
class AlbumFieldLabel extends StatelessWidget {
  const AlbumFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
    child: Text(
      text,
      style: TextStyle(
        color: context.tokens.text2,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// 表單底部的實心主色大按鈕（「加入官方圖冊」）；[onTap] 為 null＝停用，[busy]＝顯示進度。
class AlbumSubmitButton extends StatelessWidget {
  const AlbumSubmitButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (busy) return const Center(child: CircularProgressIndicator());
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: onTap == null ? t.accent.withValues(alpha: 0.4) : t.accent,
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
