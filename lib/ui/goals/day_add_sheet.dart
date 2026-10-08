import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'goals_icons.dart';

/// 時間軸 ＋ 的選擇結果：要新增的類型與所屬的坑。建立時間一律是「現在」，不能改（D-038）。
class DayAddChoice {
  const DayAddChoice(this.kind, this.pitId);
  final GoalKind kind;
  final String pitId;
}

/// DayAddSheet：標題「新增」＋ 腦洞／草稿／成圖三列。
/// 表單一定要有所屬的坑：只有一個坑時直接用；有多個坑時，選完類型後在同一張面板換成「選擇坑」。
Future<DayAddChoice?> showDayAddSheet(
  BuildContext context, {
  required List<Pit> pits,
}) {
  return showModalBottomSheet<DayAddChoice>(
    context: context,
    useRootNavigator: true, // 面板要蓋住底部導覽列
    isScrollControlled: true,
    backgroundColor: context.tokens.ground,
    barrierColor: const Color(0x6B1E1A17), // rgba(30,26,23,.42)
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _DayAddSheet(pits: pits),
  );
}

class _DayAddSheet extends StatefulWidget {
  const _DayAddSheet({required this.pits});
  final List<Pit> pits;

  @override
  State<_DayAddSheet> createState() => _DayAddSheetState();
}

class _DayAddSheetState extends State<_DayAddSheet> {
  GoalKind? _kind; // 有多個坑時，已選的類型

  void _pickKind(GoalKind k) {
    if (widget.pits.length == 1) {
      Navigator.pop(context, DayAddChoice(k, widget.pits.first.id));
    } else {
      setState(() => _kind = k);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final choosingPit = _kind != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                choosingPit ? '選擇坑' : '新增',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (!choosingPit) ...[
              _OptionRow(
                label: '腦洞',
                icon: GoalsIcons.sheetIdea,
                color: t.idea,
                onTap: () => _pickKind(GoalKind.idea),
              ),
              const SizedBox(height: 8),
              _OptionRow(
                label: '草稿',
                icon: GoalsIcons.sheetDraft,
                color: t.draft,
                onTap: () => _pickKind(GoalKind.draft),
              ),
              const SizedBox(height: 8),
              _OptionRow(
                label: '成圖',
                icon: GoalsIcons.sheetPiece,
                color: t.piece,
                onTap: () => _pickKind(GoalKind.piece),
              ),
            ] else
              for (final p in widget.pits) ...[
                _OptionRow(
                  label: p.name,
                  icon: AppIcons.folder,
                  color: t.official,
                  onTap: () =>
                      Navigator.pop(context, DayAddChoice(_kind!, p.id)),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

/// 一列選項：42 的分類色圖示底、15.5/600 文字、右側箭頭。
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String icon;
  final CategoryColor color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.borderCard),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            spacing: 14,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgIcon(
                    icon,
                    size: 22,
                    strokeWidth: 1.7,
                    color: color.fg,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SvgIcon(
                AppIcons.chevronRight,
                size: 18,
                strokeWidth: 2,
                color: t.text4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
