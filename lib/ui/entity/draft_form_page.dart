import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart';
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

/// 新增／編輯摸魚的單一入口：視窗 ≥840 開置中 modal（NewDraft，900×700），較窄開整頁。
Future<void> openDraftForm(
  BuildContext context, {
  required String pitId,
  String? draftId,
  DateTime? initialTime,
  List<XFile> initialImages = const [],
  List<String> initialIdeaIds = const [],
}) => showAdaptiveModal<void>(
  context,
  width: 900,
  height: 700,
  builder: (_, asModal) => DraftFormPage(
    pitId: pitId,
    draftId: draftId,
    initialTime: initialTime,
    initialImages: initialImages,
    initialIdeaIds: initialIdeaIds,
    asModal: asModal,
  ),
);

/// 新增草稿（亦作編輯頁）：圖片置頂（至少一張），標題、內文、tag 可空，可關聯多個腦洞。
/// 最底有「日期」欄（預設今天，可改，D-070）。沒有導覽列。
class DraftFormPage extends ConsumerStatefulWidget {
  const DraftFormPage({
    super.key,
    required this.pitId,
    this.draftId,
    this.initialTime,
    this.initialImages = const [],
    this.initialIdeaIds = const [],
    this.asModal = false,
  });
  final String pitId;
  final String? draftId;

  /// 新增時的預設日期（目標日頁以「此時此刻」新增，帶時間）。
  final DateTime? initialTime;

  /// 先從相簿選好的圖片（新增流程是先選圖、再進新增頁）。
  final List<XFile> initialImages;

  /// 新增時預先關聯的腦洞（平板腦洞詳情的「從這個腦洞開摸魚」）。
  final List<String> initialIdeaIds;

  /// 畫成置中 modal 的內容（取消／標題／主動作 標題列，不藏導覽列）。
  final bool asModal;

  @override
  ConsumerState<DraftFormPage> createState() => _DraftFormPageState();
}

class _DraftFormPageState extends ConsumerState<DraftFormPage>
    with HidesNavBar<DraftFormPage> {
  @override
  bool get hidesNavBarOnOpen => !widget.asModal;

  final _title = TextEditingController();
  final _body = TextEditingController();
  final List<ImageItem> _images = [];
  List<String> _tagIds = [];
  List<String> _ideaIds = [];
  List<String> _pieceIds = [];
  late DateTime _date = widget.initialTime ?? DateTime.now();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _images.addAll(widget.initialImages.map(ImageItem.picked));
    _load();
  }

  Future<void> _load() async {
    final id = widget.draftId;
    if (id != null) {
      final v = await ref.read(databaseProvider).watchDraftView(id).first;
      if (v != null) {
        _title.text = v.draft.title ?? '';
        _body.text = v.draft.body ?? '';
        _images.addAll(v.images.map((e) => ImageItem.stored(e.toNewImage())));
        _tagIds = v.tags.map((e) => e.id).toList();
        _ideaIds = v.ideaIds;
        _pieceIds = v.pieceIds;
        _date = v.draft.date;
      }
    } else {
      _ideaIds = [...widget.initialIdeaIds];
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
    if (_images.isEmpty) {
      showSnack(context, context.l10n.draftFormMissingImage);
      return;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final imgs = await resolveImages(store, _images);
    await ref
        .read(databaseProvider)
        .saveDraft(
          id: widget.draftId,
          pitId: widget.pitId,
          title: _title.text,
          body: _body.text,
          images: imgs,
          tagIds: _tagIds,
          ideaIds: _ideaIds,
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
    final ideas =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final pieces =
        ref.watch(pieceViewsProvider((widget.pitId, null))).value ?? const [];
    final isNew = widget.draftId == null;
    final title = isNew
        ? context.l10n.draftFormTitleNew
        : context.l10n.draftFormTitleEdit;
    final actionLabel = isNew
        ? context.l10n.draftFormCreate
        : context.l10n.commonSave;
    final imageField = [
      FormLabel(context.l10n.draftFormImages),
      FormImageGrid(
        items: _images,
        size: 84,
        onAdd: _addImages,
        onRemove: (i) => setState(() => _images.removeAt(i)),
        onReorder: (a, b) => setState(() => moveListItem(_images, a, b)),
      ),
    ];
    final textFields = [
      FormLabel(context.l10n.entityFieldTitle),
      TextField(
        controller: _title,
        style: const TextStyle(fontSize: 15),
        decoration: entityFieldDecoration(context, ''),
      ),
      const SizedBox(height: 16),
      FormLabel(context.l10n.entityFieldBody),
      TextField(
        controller: _body,
        minLines: 3,
        maxLines: 10,
        style: const TextStyle(fontSize: 15, height: 1.55),
        decoration: entityFieldDecoration(context, ''),
      ),
    ];
    final rest = [
      TagPicker(
        pitId: widget.pitId,
        selected: _tagIds,
        onChanged: (v) => setState(() => _tagIds = v),
      ),
      const SizedBox(height: 16),
      ConnectField(
        label: context.l10n.entityConnectIdea,
        kind: ConnectKind.idea,
        options: [
          for (final i in ideas)
            ConnectOption(
              id: i.idea.id,
              title: i.idea.title,
              file: i.images.isEmpty ? null : i.images.first.staticFile,
              imageCount: i.images.length,
              date: i.idea.date,
            ),
        ],
        selected: _ideaIds,
        onChanged: (v) => setState(() => _ideaIds = v),
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
      return ModalFormShell(
        title: title,
        actionLabel: actionLabel,
        loaded: _loaded,
        onAction: () {
          if (!_saving) _save();
        },
        panes: [
          ModalPane(
            width: 460,
            children: [
              ...imageField,
              const SizedBox(height: 20),
              ...textFields,
            ],
          ),
          ModalPane(children: rest),
        ],
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
                  : ContentWidth(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          ...imageField,
                          const SizedBox(height: 16),
                          ...textFields,
                          const SizedBox(height: 16),
                          ...rest,
                          const SizedBox(height: 24),
                          FormSubmitButton(
                            label: actionLabel,
                            onPressed: _saving ? null : _save,
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
