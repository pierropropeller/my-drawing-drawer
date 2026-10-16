import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/oshi_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/group_manage_page.dart';
import '../album/image_picker_field.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../entity/entity_widgets.dart';
import '../tags/tag_picker.dart';
import 'oshi_date_guess.dart';
import 'oshi_icons.dart';
import '../common/reorder_tile.dart';

/// 新增推活紀錄（OshiNew），編輯用同一頁（[recordId]，按鈕改「儲存」）。沒有導覽列。
/// 欄位順序：圖片 → 標題 → 描述 → 分組 → tag → 日期（最後）。
/// [initialImages] 是已複製進 App 儲存空間（或暫存）的圖片檔案路徑（分享進來、列表先選圖）。
class OshiFormPage extends ConsumerStatefulWidget {
  const OshiFormPage({
    super.key,
    required this.pitId,
    this.recordId,
    this.initialImages = const [],
    this.initialGroupId,
  });
  final String pitId;
  final String? recordId;
  final List<String> initialImages;

  /// 新增時預選的分組（從分組篩選下新增時帶入）；可省略。
  final String? initialGroupId;

  @override
  ConsumerState<OshiFormPage> createState() => _OshiFormPageState();
}

class _OshiFormPageState extends ConsumerState<OshiFormPage>
    with HidesNavBar<OshiFormPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final List<ImageItem> _images = [];
  List<String> _tagIds = [];
  String? _groupId;
  DateTime _date = oshiDateOnly(DateTime.now());

  /// 使用者自己選過日期（或編輯既有紀錄）後，不再依第一張圖自動猜。
  late bool _dateLocked = widget.recordId != null;
  String? _guessedFor;
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.recordId == null;

  @override
  void initState() {
    super.initState();
    _groupId = widget.initialGroupId;
    _images.addAll(widget.initialImages.map((p) => ImageItem.picked(XFile(p))));
    _syncDate();
    _load();
  }

  Future<void> _load() async {
    final id = widget.recordId;
    if (id != null) {
      final v = await ref.read(databaseProvider).getOshiRecord(id);
      if (v != null) {
        _title.text = v.record.title ?? '';
        _desc.text = v.record.description ?? '';
        _images.addAll(v.images.map((e) => ImageItem.stored(e.toNewImage())));
        _tagIds = v.tags.map((e) => e.id).toList();
        _groupId = v.record.groupId;
        _date = oshiDateOnly(v.record.date);
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  /// 預設日期：第一張圖的 EXIF 拍攝時間 → 檔案修改時間 → 今天；可手動改。
  void _syncDate() {
    if (_dateLocked) return;
    final first = _images.isEmpty ? null : _images.first.picked?.path;
    if (first == _guessedFor) return;
    _guessedFor = first;
    if (first == null) return;
    guessOshiDate(first).then((d) {
      if (mounted && !_dateLocked && _guessedFor == first) {
        setState(() => _date = d);
      }
    });
  }

  Future<void> _addImages() async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isEmpty || !mounted) return;
    setState(() => _images.addAll(picked.map(ImageItem.picked)));
    _syncDate();
  }

  void _removeImage(int i) {
    setState(() => _images.removeAt(i));
    _syncDate();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _date = oshiDateOnly(d);
      _dateLocked = true;
    });
  }

  Future<void> _addGroup() async {
    final name = await promptText(context, title: context.l10n.albumGroupAdd);
    if (name == null || !mounted) return;
    final db = ref.read(databaseProvider);
    await db.addGroup(widget.pitId, name, kind: 'oshi');
    final groups = await db.watchGroups(widget.pitId, kind: 'oshi').first;
    if (mounted && groups.isNotEmpty) {
      setState(() => _groupId = groups.last.id);
    }
  }

  Future<void> _save(List<String> validGroupIds) async {
    if (_images.isEmpty) {
      showSnack(context, context.l10n.albumPickImageFirst);
      return;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final imgs = await resolveImages(store, _images);
    await ref
        .read(databaseProvider)
        .saveOshiRecord(
          id: widget.recordId,
          pitId: widget.pitId,
          date: _date,
          groupId: validGroupIds.contains(_groupId) ? _groupId : null,
          title: _title.text,
          description: _desc.text,
          images: imgs,
          tagIds: _tagIds,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'oshi'))).value ?? const [];
    final validIds = [for (final g in groups) g.id];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: _isNew
                  ? context.l10n.oshiFormTitleNew
                  : context.l10n.oshiFormTitleEdit,
              titleSize: 19,
            ),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ContentWidth(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          FormLabel(context.l10n.oshiFieldImages),
                          ImagePickerField(
                            items: _images,
                            onAdd: _addImages,
                            onRemove: _removeImage,
                            onReorder: (a, b) =>
                                setState(() => moveListItem(_images, a, b)),
                          ),
                          const SizedBox(height: 16),
                          FormLabel(context.l10n.entityFieldTitle),
                          TextField(
                            controller: _title,
                            style: const TextStyle(fontSize: 15),
                            decoration: entityFieldDecoration(context, ''),
                          ),
                          const SizedBox(height: 16),
                          FormLabel(context.l10n.oshiFieldDescription),
                          TextField(
                            controller: _desc,
                            minLines: 3,
                            maxLines: 8,
                            style: const TextStyle(fontSize: 15, height: 1.55),
                            decoration: entityFieldDecoration(context, ''),
                          ),
                          const SizedBox(height: 16),
                          // 「分組」標題右邊的「管理」（D-076，同 tag 欄）。
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Text(
                                    context.l10n.albumGroupLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: context.tokens.text2,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => GroupManagePage(
                                        pitId: widget.pitId,
                                        kind: 'oshi',
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    context.l10n.commonManage,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.tokens.piece.fg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final g in groups)
                                _GroupPill(
                                  label: g.name,
                                  on: _groupId == g.id,
                                  // 分組是選填的：再點一次已選的分組即取消。
                                  onTap: () => setState(
                                    () => _groupId = _groupId == g.id
                                        ? null
                                        : g.id,
                                  ),
                                ),
                              DashedAddChip(
                                semanticLabel: context.l10n.albumGroupAdd,
                                onTap: _addGroup,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TagPicker(
                            pitId: widget.pitId,
                            selected: _tagIds,
                            onChanged: (v) => setState(() => _tagIds = v),
                          ),
                          const SizedBox(height: 16),
                          FormLabel(context.l10n.oshiFieldDate),
                          _DateField(date: _date, onTap: _pickDate),
                          const SizedBox(height: 24),
                          FormSubmitButton(
                            label: _isNew
                                ? context.l10n.oshiFormCreate
                                : context.l10n.commonSave,
                            onPressed: _saving ? null : () => _save(validIds),
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

/// 分組單選 pill（表單用：選中＝主色底白字）。
class _GroupPill extends StatelessWidget {
  const _GroupPill({
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? t.accent : t.surface,
          border: Border.all(color: on ? t.accent : t.border),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : t.text2,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 日期欄（OshiNew）：白底框＋右側日曆 icon，點了開日期選擇器。
class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? t.border : const Color(0xFFE3D8C9)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(fmtSlash(date), style: const TextStyle(fontSize: 15)),
            ),
            SvgIcon(
              OshiIcons.calendar,
              size: 19,
              strokeWidth: 1.7,
              color: t.text3,
            ),
          ],
        ),
      ),
    );
  }
}
