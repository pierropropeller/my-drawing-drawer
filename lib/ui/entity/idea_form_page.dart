import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/image_picker_field.dart';
import '../common/adaptive_modal.dart';
import '../common/modal_form_layout.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../tags/tag_picker.dart';
import 'piece_widgets.dart';
import 'connect_field.dart';
import 'entity_widgets.dart';
import '../common/reorder_tile.dart';

/// 新增／編輯腦洞的單一入口：視窗 ≥840 開置中 modal（NewIdea，900×700），較窄開整頁。
Future<void> openIdeaForm(
  BuildContext context, {
  required String pitId,
  String? ideaId,
  DateTime? initialTime,
  List<XFile> initialImages = const [],
}) => showAdaptiveModal<void>(
  context,
  width: 900,
  height: 700,
  builder: (_, asModal) => IdeaFormPage(
    pitId: pitId,
    ideaId: ideaId,
    initialTime: initialTime,
    initialImages: initialImages,
    asModal: asModal,
  ),
);

/// 新增腦洞（亦作編輯頁）：標題、內文、配圖、tag、關聯草稿、關聯成圖、日期。
/// 沒有導覽列。選擇草稿／成圖的面板只從這裡打開（D-037）。
class IdeaFormPage extends ConsumerStatefulWidget {
  const IdeaFormPage({
    super.key,
    required this.pitId,
    this.ideaId,
    this.initialTime,
    this.initialImages = const [],
    this.asModal = false,
  });
  final String pitId;
  final String? ideaId;

  /// 新增時的預設日期（目標日頁以「此時此刻」新增，帶時間）。
  final DateTime? initialTime;

  /// 預先放好的配圖（例如從其他 App 分享進來，D-053）。
  final List<XFile> initialImages;

  /// 畫成置中 modal 的內容（取消／標題／主動作 標題列，不藏導覽列）。
  final bool asModal;

  @override
  ConsumerState<IdeaFormPage> createState() => _IdeaFormPageState();
}

class _IdeaFormPageState extends ConsumerState<IdeaFormPage>
    with HidesNavBar<IdeaFormPage> {
  @override
  bool get hidesNavBarOnOpen => !widget.asModal;

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final List<ImageItem> _images = [];
  List<String> _tagIds = [];
  List<String> _draftIds = [];
  List<String> _pieceIds = [];
  late DateTime _date = widget.initialTime ?? DateTime.now();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _images.addAll(widget.initialImages.map(ImageItem.picked));
    _title.addListener(_onRequiredChanged);
    _load();
  }

  void _onRequiredChanged() {
    if (mounted) setState(() {});
  }

  /// 標題填了才能儲存；沒填「儲存」變灰，不另加提示（D-121 ①）。
  bool get _canSave => _title.text.trim().isNotEmpty;

  Future<void> _load() async {
    final id = widget.ideaId;
    if (id != null) {
      final v = await ref.read(databaseProvider).watchIdeaView(id).first;
      if (v != null) {
        _title.text = v.idea.title;
        _body.text = v.idea.body;
        _images.addAll(v.images.map((e) => ImageItem.stored(e.toNewImage())));
        _tagIds = v.tags.map((e) => e.id).toList();
        _draftIds = v.draftIds;
        _pieceIds = v.pieceIds;
        _date = v.idea.date;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || !_canSave) return;
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final imgs = await resolveImages(store, _images);
    await ref
        .read(databaseProvider)
        .saveIdea(
          id: widget.ideaId,
          pitId: widget.pitId,
          title: _title.text.trim(),
          body: _body.text.trim(),
          images: imgs,
          tagIds: _tagIds,
          draftIds: _draftIds,
          pieceIds: _pieceIds,
          date: _date,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addImages() async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isNotEmpty) {
      setState(() => _images.addAll(picked.map(ImageItem.picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts =
        ref.watch(draftViewsProvider(widget.pitId)).value ?? const [];
    final pieces =
        ref.watch(pieceViewsProvider((widget.pitId, null))).value ?? const [];
    final isNew = widget.ideaId == null;
    final title = isNew
        ? context.l10n.ideaFormTitleNew
        : context.l10n.ideaFormTitleEdit;
    final actionLabel = isNew
        ? context.l10n.ideaFormCreate
        : context.l10n.commonSave;
    final titleField = [
      FormLabel(context.l10n.entityFieldTitle),
      TextFormField(
        controller: _title,
        style: const TextStyle(fontSize: 15),
        decoration: entityFieldDecoration(context, ''),
      ),
    ];
    Widget bodyField(int minLines, int maxLines) => TextFormField(
      controller: _body,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, height: 1.55),
      decoration: entityFieldDecoration(context, ''),
    );
    final rest = [
      FormLabel(context.l10n.ideaFormImages),
      FormImageGrid(
        pitId: widget.pitId,
        items: _images,
        size: 72,
        // NewIdea：72×72 固定大小、間距 10（其他表單是 3 欄方形）。
        dialogColumns: null,
        dialogSpacing: 10,
        onAdd: _addImages,
        onRemove: (i) => setState(() => _images.removeAt(i)),
        onReorder: (a, b) => setState(() => moveListItem(_images, a, b)),
      ),
      const SizedBox(height: 16),
      TagPicker(
        pitId: widget.pitId,
        selected: _tagIds,
        onChanged: (v) => setState(() => _tagIds = v),
      ),
      const SizedBox(height: 16),
      ConnectField(
        label: context.l10n.entityConnectDraft,
        kind: ConnectKind.draft,
        options: [
          for (final d in drafts)
            ConnectOption(
              id: d.draft.id,
              title: d.draft.title ?? '',
              file: d.images.isEmpty ? null : d.images.first.staticFile,
              imageCount: d.images.length,
              date: d.draft.date,
            ),
        ],
        selected: _draftIds,
        onChanged: (v) => setState(() => _draftIds = v),
      ),
      const SizedBox(height: 16),
      ConnectField(
        label: context.l10n.entityConnectPiece,
        kind: ConnectKind.piece,
        options: [
          for (final p in pieces)
            ConnectOption(
              id: p.piece.id,
              title: p.piece.title,
              file: p.images.isEmpty ? null : p.images.first.staticFile,
              imageCount: p.images.length,
              date: p.piece.finishedAt,
            ),
        ],
        selected: _pieceIds,
        onChanged: (v) => setState(() => _pieceIds = v),
      ),
      const SizedBox(height: 16),
      FormLabel(context.l10n.entityFieldDate),
      PieceDateField(
        date: _date,
        semanticLabel: context.l10n.entityFieldDate,
        onChanged: (d) => setState(() => _date = d),
      ),
    ];
    if (widget.asModal) {
      return Form(
        key: _form,
        child: ModalFormShell(
          title: title,
          actionLabel: actionLabel,
          compactActionLabel: isNew ? context.l10n.pitsCreate : null,
          loaded: _loaded,
          onAction: _canSave
              ? () {
                  if (!_saving) _save();
                }
              : null,
          panes: [
            ModalPane(
              width: 460,
              children: [
                ...titleField,
                const SizedBox(height: 18),
                FormLabel(context.l10n.entityFieldBody),
                bodyField(10, 18),
              ],
            ),
            ModalPane(children: rest),
          ],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(title: title, titleSize: 20, gap: 6),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _form,
                      child: ContentWidth(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          children: [
                            ...titleField,
                            const SizedBox(height: 16),
                            FormLabel(context.l10n.entityFieldBody),
                            bodyField(4, 12),
                            const SizedBox(height: 16),
                            ...rest,
                            const SizedBox(height: 24),
                            FormSubmitButton(
                              label: actionLabel,
                              onPressed: _saving || !_canSave ? null : _save,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
