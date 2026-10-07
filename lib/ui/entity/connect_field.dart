import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../album/album_image.dart';
import 'entity_widgets.dart';

/// 可被連接的對象（腦洞、草稿或成圖）。
class ConnectOption {
  const ConnectOption({required this.id, required this.title, this.file});
  final String id;
  final String title;
  final String? file;
}

/// 「連接腦洞／草稿／成圖」欄：顯示已連接項目，點「選擇」開啟多選面板。
/// 「連接」只用於腦洞、草稿、成圖之間（HANDOFF 用詞規則）。
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
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ConnectSheet(label: label, options: options, initial: selected),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chosen = options.where((o) => selected.contains(o.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => _open(context),
              child: const Text('選擇'),
            ),
          ],
        ),
        if (chosen.isEmpty)
          Text('尚未連接', style: TextStyle(color: t.text3))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in chosen)
                InputChip(
                  label: Text(o.title.isEmpty ? '（無標題）' : o.title),
                  onDeleted: () =>
                      onChanged(selected.where((e) => e != o.id).toList()),
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
