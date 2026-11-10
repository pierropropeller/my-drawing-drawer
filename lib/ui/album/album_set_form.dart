import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/app_switch.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import 'album_icons.dart';

/// 表單裡多圖（D-136）的列：外框跟「全部標為敏感」那一列一樣（白底、圓角 14、細框）。
class _AlbumSetRow extends StatelessWidget {
  const _AlbumSetRow({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final row = Container(
      margin: EdgeInsets.only(top: WindowClass.of(context).isCompact ? 12 : 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.borderCard),
      ),
      child: child,
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

/// 新增頁「合成一組」開關（預設關）：開著存檔＝這幾張存成一筆多圖；關著＝照舊每張一筆。
class AlbumSetCombineRow extends StatelessWidget {
  const AlbumSetCombineRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _AlbumSetRow(
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.albumSetCombine,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
          ),
        ),
        AppSwitch(
          value: value,
          semanticLabel: context.l10n.albumSetCombine,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

/// 編輯頁「拆開」：這一組的每一張各自變成獨立一項（要確認）。
class AlbumSetSplitRow extends StatelessWidget {
  const AlbumSetSplitRow({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: context.l10n.albumSetSplit,
      excludeSemantics: true,
      child: _AlbumSetRow(
        onTap: onTap,
        child: Row(
          children: [
            SvgIcon(
              AlbumIcons.stack,
              size: 18,
              color: t.text2,
              strokeWidth: 1.7,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.albumSetSplit,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              context.l10n.albumSetCount(count),
              style: TextStyle(fontSize: 13, color: t.text3),
            ),
          ],
        ),
      ),
    );
  }
}

/// 拆開前的確認框：回傳 true＝拆開。
Future<bool> confirmAlbumSetSplit(BuildContext context, int count) async {
  final t = context.tokens;
  final l = context.l10n;
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
        l.albumSetSplitTitle,
        style: Theme.of(ctx).textTheme.titleLarge
            ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Text(
        l.albumSetSplitBody(count),
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
            l.albumSetSplit,
            style: TextStyle(
              color: t.accentStrong,
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
