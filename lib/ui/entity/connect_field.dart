import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'entity_icons.dart';
import 'entity_widgets.dart';

/// 可被關聯的對象種類（腦洞、草稿、成圖）。
enum ConnectKind {
  idea,
  draft,
  piece;

  /// 「關聯草稿」欄位標籤。
  String relateLabel(AppLocalizations l) => switch (this) {
    ConnectKind.idea => l.entityConnectIdea,
    ConnectKind.draft => l.entityConnectDraft,
    ConnectKind.piece => l.entityConnectPiece,
  };

  /// 「選擇草稿」面板標題與按鈕語意。
  String selectLabel(AppLocalizations l) => switch (this) {
    ConnectKind.idea => l.entityConnectSelectIdea,
    ConnectKind.draft => l.entityConnectSelectDraft,
    ConnectKind.piece => l.entityConnectSelectPiece,
  };

  /// 「已選 2 份」。
  String selectedLabel(AppLocalizations l, int n) => switch (this) {
    ConnectKind.idea => l.entityConnectSelectedIdea(n),
    ConnectKind.draft => l.entityConnectSelectedDraft(n),
    ConnectKind.piece => l.entityConnectSelectedPiece(n),
  };

  /// 由欄位／面板標籤判斷種類（標籤含「腦洞」「草稿」，其餘視為成圖）。
  static ConnectKind of(String label) => label.contains('腦洞')
      ? ConnectKind.idea
      : label.contains('草稿')
      ? ConnectKind.draft
      : ConnectKind.piece;

  CategoryColor color(AppTokens t) => switch (this) {
    ConnectKind.idea => t.idea,
    ConnectKind.draft => t.draft,
    ConnectKind.piece => t.piece,
  };

  String get icon => switch (this) {
    ConnectKind.idea => AppIcons.bulb,
    ConnectKind.draft => EntityIcons.draftChip,
    ConnectKind.piece => AppIcons.image,
  };
}

/// 可被關聯的對象（腦洞、草稿或成圖）。
class ConnectOption {
  const ConnectOption({
    required this.id,
    required this.title,
    this.file,
    this.imageCount = 1,
    this.date,
  });
  final String id;
  final String title;
  final String? file;

  /// 圖片張數；大於 1 時縮圖右下角顯示張數。
  final int imageCount;

  /// 建立日期（選擇面板列尾的短日期）。
  final DateTime? date;
}

/// 開啟「選擇腦洞／草稿／成圖」面板（DraftPick）：列出項目、多選、底部「完成」。
/// 取消回傳 null。[label] 決定種類（含「腦洞」「草稿」，其餘為成圖）。
/// 只從新增／編輯表單打開；詳情頁不能新增關聯（D-037）。
Future<List<String>?> showConnectSheet(
  BuildContext context, {
  required String label,
  ConnectKind? kind,
  required List<ConnectOption> options,
  required List<String> selected,
}) => showModalBottomSheet<List<String>>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.tokens.ground,
  barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * 0.85,
  ),
  builder: (_) => ConnectSheet(
    kind: kind ?? ConnectKind.of(label),
    options: options,
    initial: selected,
  ),
);

/// 已關聯項目的彩色 chip（腦洞黃、草稿褐、成圖紅）。
/// 表單裡傳 [onRemove] 顯示 ×；詳情頁傳 [onTap] 點了開啟該項目。
class RelationChip extends StatelessWidget {
  const RelationChip({
    super.key,
    required this.kind,
    required this.title,
    this.onRemove,
    this.onTap,
  });
  final ConnectKind kind;
  final String title;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = kind.color(t);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 7, onRemove == null ? 12 : 10, 7),
        decoration: BoxDecoration(
          color: color.bg,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(kind.icon, size: 14, color: color.fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title.isEmpty ? context.l10n.commonNoTitle : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color.fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: context.l10n.entityRemove,
                child: GestureDetector(
                  onTap: onRemove,
                  child: SvgIcon(
                    AppIcons.closeX,
                    size: 13,
                    strokeWidth: 2,
                    color: color.fg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「關聯腦洞／草稿／成圖」欄（IdeaNew／DraftNew／PieceNew）：已關聯的項目是彩色 chip（可移除），
/// 尾端虛線「＋ 選擇」開啟選擇面板。
/// 「關聯」只用於腦洞、草稿、成圖之間（HANDOFF 用詞規則）；chip 的顏色與圖示由 [label] 判斷。
class ConnectField extends StatelessWidget {
  const ConnectField({
    super.key,
    required this.label,
    this.kind,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;

  /// 種類；沒傳時由 [label] 判斷（舊用法）。
  final ConnectKind? kind;
  final List<ConnectOption> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await showConnectSheet(
      context,
      label: label,
      kind: kind,
      options: options,
      selected: selected,
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final kind = this.kind ?? ConnectKind.of(label);
    final chosen = options.where((o) => selected.contains(o.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormLabel(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in chosen)
              RelationChip(
                kind: kind,
                title: o.title,
                onRemove: () =>
                    onChanged(selected.where((e) => e != o.id).toList()),
              ),
            DashedAddChip(
              label: context.l10n.commonSelect,
              semanticLabel: kind.selectLabel(context.l10n),
              onTap: () => _open(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// 選擇面板本體：同一個樣式用於選擇腦洞、選擇草稿、選擇成圖。
class ConnectSheet extends StatefulWidget {
  const ConnectSheet({
    super.key,
    required this.kind,
    required this.options,
    required this.initial,
  });
  final ConnectKind kind;
  final List<ConnectOption> options;
  final List<String> initial;

  @override
  State<ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<ConnectSheet> {
  late final Set<String> _sel = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kind = widget.kind;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    kind.selectLabel(context.l10n),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    kind.selectedLabel(context.l10n, _sel.length),
                    style: TextStyle(color: t.text3, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Flexible(
              child: widget.options.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          context.l10n.entityConnectEmpty,
                          style: TextStyle(color: t.text3),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.options.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final o = widget.options[i];
                        final on = _sel.contains(o.id);
                        return _PickRow(
                          option: o,
                          selected: on,
                          onTap: () => setState(() {
                            if (!_sel.remove(o.id)) _sel.add(o.id);
                          }),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            FormSubmitButton(
              label: context.l10n.commonDone,
              onPressed: () => Navigator.pop(context, _sel.toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final ConnectOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final o = option;
    final untitled = o.title.isEmpty;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? t.accent : t.borderCard,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: o.file == null
                          ? const ImagePlaceholder(iconSize: 18)
                          : StoredImage(o.file!, cacheWidth: 200),
                    ),
                    if (o.imageCount > 1)
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: CountBadge(o.imageCount),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      untitled ? context.l10n.commonNoTitle : o.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: untitled
                          ? TextStyle(color: t.text4, fontSize: 14)
                          : TextStyle(
                              color: t.ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                    if (o.date != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          fmtMd(o.date!),
                          style: TextStyle(color: t.text4, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SelectDot(selected),
            ],
          ),
        ),
      ),
    );
  }
}
