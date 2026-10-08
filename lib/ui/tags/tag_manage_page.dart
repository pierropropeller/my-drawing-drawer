import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../entity/entity_widgets.dart';

/// 管理 tag（TagManage）：目前所在的坑、這個坑的 tag 清單（使用項數、改名、刪除）、新增。
/// 沒有導覽列。點「新增 tag」後，清單最底變成輸入框（固定 `#` 前綴）＋取消／新增（TagAdd，D-016）。
class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage>
    with HidesNavBar<TagManagePage> {
  final _name = TextEditingController();
  bool _adding = false;

  String get pitId => widget.pitId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 前面的 # 是固定前綴；使用者多打的 # 去掉。
    final name = _name.text.trim().replaceFirst(RegExp(r'^[#＃]+'), '').trim();
    if (name.isEmpty) return;
    await ref.read(databaseProvider).createTag(pitId, name);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _name.clear();
    });
  }

  void _cancel() => setState(() {
    _adding = false;
    _name.clear();
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final db = ref.watch(databaseProvider);
    final usage = ref.watch(tagUsageProvider(pitId)).value ?? const [];
    final pitName = ref.watch(pitProvider(pitId)).value?.name;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rowLine = dark ? t.border : const Color(0xFFF1EADF);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SubPageHeader(title: '管理 tag', titleSize: 20, gap: 6),
            Expanded(
              child: ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
                      child: Row(
                        children: [
                          if (pitName != null)
                            Container(
                              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                              decoration: BoxDecoration(
                                color: t.surface,
                                border: Border.all(
                                  color: dark
                                      ? t.border
                                      : const Color(0xFFE3D8C9),
                                ),
                                borderRadius: BorderRadius.circular(Radii.chip),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // D-004：坑的 pill 用導覽列同款資料夾 icon。
                                  SvgIcon(
                                    AppIcons.folder,
                                    size: 14,
                                    color: t.text2,
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 120,
                                    ),
                                    child: Text(
                                      pitName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: t.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (pitName != null) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'tag 按坑獨立，不同坑之間不共用',
                              style: TextStyle(color: t.text3, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 2, 10, 2),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(Radii.card),
                        border: Border.all(color: t.borderCard),
                      ),
                      child: Column(
                        children: [
                          for (final u in usage)
                            Container(
                              padding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: rowLine),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '#${u.tag.name}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Text(
                                      '${u.count} 項',
                                      style: TextStyle(
                                        color: t.text4,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _RowButton(
                                    icon: AppIcons.edit,
                                    label: '重新命名 #${u.tag.name}',
                                    color: t.text2,
                                    onTap: () async {
                                      final name = await promptText(
                                        context,
                                        title: 'Tag 名稱',
                                        initial: u.tag.name,
                                      );
                                      if (name != null) {
                                        await db.renameTag(u.tag.id, name);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _RowButton(
                                    icon: AppIcons.trash,
                                    label: '刪除 #${u.tag.name}',
                                    color: t.danger,
                                    onTap: () async {
                                      final ok = await confirmDelete(
                                        context,
                                        title: '刪除 tag「${u.tag.name}」？',
                                        message: u.count > 0
                                            ? '已使用的內容會一併移除這個 tag。'
                                            : null,
                                      );
                                      if (ok) await db.deleteTag(u.tag.id);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          if (_adding)
                            _AddRow(
                              controller: _name,
                              onCancel: _cancel,
                              onSubmit: _submit,
                            )
                          else
                            GestureDetector(
                              onTap: () => setState(() => _adding = true),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    SvgIcon(
                                      AppIcons.plus,
                                      size: 18,
                                      strokeWidth: 2,
                                      color: t.dashedText,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '新增 tag',
                                      style: TextStyle(
                                        color: t.dashedText,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 清單最底的新增列（TagAdd）：固定 `#` 前綴的輸入框＋取消／新增。
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.accent, width: 1.5),
              ),
              child: Row(
                children: [
                  Text('#', style: TextStyle(color: t.text4, fontSize: 15)),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onSubmit(),
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text('取消', style: TextStyle(color: t.text3, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSubmit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '新增',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      radius: 22,
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(child: SvgIcon(icon, size: 20, color: color)),
      ),
    ),
  );
}
