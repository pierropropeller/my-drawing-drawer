import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'entity_widgets.dart';

/// 可被連接的對象（腦洞、草稿或成圖）。
class ConnectOption {
  const ConnectOption({required this.id, required this.title, this.file});
  final String id;
  final String title;
  final String? file;
}

/// 開啟多選面板；取消回傳 null。詳情頁的「＋」也用這個。
Future<List<String>?> showConnectSheet(
  BuildContext context, {
  required String label,
  required List<ConnectOption> options,
  required List<String> selected,
}) => showModalBottomSheet<List<String>>(
  context: context,
  isScrollControlled: true,
  builder: (_) =>
      _ConnectSheet(label: label, options: options, initial: selected),
);

/// 「連接腦洞／草稿／成圖」欄（IdeaNew／DraftNew）：已連接的項目是彩色 chip（可移除），
/// 尾端虛線「＋ 新增」開啟多選面板。
/// 「連接」只用於腦洞、草稿、成圖之間（HANDOFF 用詞規則）；chip 的顏色與圖示由 [label] 判斷。
class ConnectField extends StatelessWidget {
  const ConnectField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<ConnectOption> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await showConnectSheet(
      context,
      label: label,
      options: options,
      selected: selected,
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (CategoryColor color, String icon) = label.contains('腦洞')
        ? (t.idea, AppIcons.bulb)
        : label.contains('草稿')
        ? (t.draft, AppIcons.edit)
        : (t.piece, AppIcons.image);
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
              Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
                decoration: BoxDecoration(
                  color: color.bg,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgIcon(icon, size: 14, color: color.fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        o.title.isEmpty ? '（無標題）' : o.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.fg,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Semantics(
                      button: true,
                      label: '移除',
                      child: GestureDetector(
                        onTap: () => onChanged(
                          selected.where((e) => e != o.id).toList(),
                        ),
                        child: SvgIcon(
                          AppIcons.closeX,
                          size: 13,
                          strokeWidth: 2,
                          color: color.fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            DashedAddChip(
              semanticLabel: '新增$label',
              onTap: () => _open(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectSheet extends StatefulWidget {
  const _ConnectSheet({
    required this.label,
    required this.options,
    required this.initial,
  });
  final String label;
  final List<ConnectOption> options;
  final List<String> initial;

  @override
  State<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<_ConnectSheet> {
  late final Set<String> _sel = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _sel.toList()),
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.options.isEmpty
                ? Center(
                    child: Text('沒有可連接的項目', style: TextStyle(color: t.text3)),
                  )
                : ListView.builder(
                    controller: controller,
                    itemCount: widget.options.length,
                    itemBuilder: (_, i) {
                      final o = widget.options[i];
                      return ListTile(
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.image),
                            child: o.file == null
                                ? ColoredBox(color: t.chipBg)
                                : StoredImage(o.file!, cacheWidth: 200),
                          ),
                        ),
                        title: Text(
                          o.title.isEmpty ? '（無標題）' : o.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: SelectDot(_sel.contains(o.id)),
                        onTap: () => setState(() {
                          if (!_sel.remove(o.id)) _sel.add(o.id);
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
