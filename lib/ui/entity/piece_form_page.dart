import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/entity_queries.dart';
import '../../data/payment.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/image_picker_field.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../tags/tag_picker.dart';
import 'connect_field.dart';
import 'entity_widgets.dart';
import 'piece_platform.dart';
import 'piece_widgets.dart';

/// 新增成圖（亦作編輯頁 PieceEdit）：圖片置頂（只限圖片）、標題、內文、tag、
/// 兩個獨立開關「已公開發佈」「商稿」（D-046）、完成時間、關聯腦洞與草稿。
class PieceFormPage extends ConsumerStatefulWidget {
  const PieceFormPage({
    super.key,
    required this.pitId,
    this.pieceId,
    this.initialTime,
    this.initialImages = const [],
  });
  final String pitId;
  final String? pieceId;

  /// 新增時預設的完成時間。
  final DateTime? initialTime;

  /// 先從相簿選好的圖片（新增流程是先選圖、再進新增頁）。
  final List<XFile> initialImages;

  @override
  ConsumerState<PieceFormPage> createState() => _PieceFormPageState();
}

/// 一條社交連結的輸入列。平台由網址自動判斷（D-035）；
/// 判斷不出來時，網址沒改過就沿用原本儲存的平台，否則是鎖鏈。
class _LinkRow {
  _LinkRow(String url, [String? storedPlatform])
    : url = TextEditingController(text: url),
      initialUrl = url,
      initialPlatform = storedPlatform == null
          ? null
          : PieceSocialPlatform.fromLabel(storedPlatform);
  final TextEditingController url;
  final String initialUrl;
  final PieceSocialPlatform? initialPlatform;

  PieceSocialPlatform get platform {
    final d = detectSocialPlatform(url.text);
    if (d != PieceSocialPlatform.other) return d;
    if (initialPlatform != null && url.text.trim() == initialUrl.trim()) {
      return initialPlatform!;
    }
    return PieceSocialPlatform.other;
  }
}

class _PieceFormPageState extends ConsumerState<PieceFormPage>
    with HidesNavBar<PieceFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _target = TextEditingController();
  final _actual = TextEditingController();
  final _client = TextEditingController();
  final _amount = TextEditingController();
  final _received = TextEditingController();
  final List<ImageItem> _images = [];
  final List<_LinkRow> _links = [];
  List<String> _tagIds = [];
  List<String> _ideaIds = [];
  List<String> _draftIds = [];
  DateTime _finishedAt = DateTime.now();
  bool _published = false;
  DateTime? _publishedAt;
  bool _commission = false;
  DateTime? _dueAt;
  late String _currency = ref.read(settingsProvider).defaultCurrency;
  bool _loaded = false;
  bool _saving = false;

  bool get _isEdit => widget.pieceId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialTime != null) _finishedAt = widget.initialTime!;
    _images.addAll(widget.initialImages.map(ImageItem.picked));
    _load();
  }

  Future<void> _load() async {
    final id = widget.pieceId;
    if (id != null) {
      final v = await ref.read(databaseProvider).watchPieceView(id).first;
      if (v != null) {
        final p = v.piece;
        _title.text = p.title;
        _body.text = p.body;
        _target.text = p.targetLikes > 0 ? '${p.targetLikes}' : '';
        _actual.text = p.actualLikes > 0 ? '${p.actualLikes}' : '';
        _finishedAt = p.finishedAt;
        _published = p.isPublished;
        _publishedAt = p.publishedAt;
        _commission = p.isCommission;
        _client.text = p.client;
        _amount.text = p.amount == null ? '' : pieceNumberText(p.amount!);
        _received.text = p.receivedAmount > 0
            ? pieceNumberText(p.receivedAmount)
            : '';
        _currency = p.currency.isEmpty ? _currency : p.currency;
        _dueAt = p.dueAt;
        _images.addAll(
          v.images.map(
            (e) => ImageItem.stored(
              NewImage(file: e.file, width: e.width, height: e.height),
            ),
          ),
        );
        _links.addAll(v.links.map((l) => _LinkRow(l.url, l.platform)));
        _tagIds = v.tags.map((e) => e.id).toList();
        _ideaIds = v.ideaIds;
        _draftIds = v.draftIds;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _target, _actual, _client, _amount]) {
      c.dispose();
    }
    _received.dispose();
    for (final l in _links) {
      l.url.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim());

  /// 「已收齊」按鈕的實色狀態跟著數字走（D-050）。
  bool get _fullyReceived =>
      isFullyReceived(amount: _num(_amount), received: _num(_received) ?? 0);

  void _toggleReceivedAll() {
    final amount = _num(_amount);
    setState(() {
      if (_fullyReceived) {
        _received.text = '0';
      } else if (amount != null && amount > 0) {
        _received.text = pieceNumberText(amount);
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_images.isEmpty) {
      showSnack(context, '請至少選擇一張圖片');
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final store = await ref.read(imageStoreProvider.future);
    final imgs = await resolveImages(store, _images);
    // 兩組欄位各自整組傳（DATA_API §3）；開關關閉時資料保留。
    final id = await db.savePiece(
      id: widget.pieceId,
      pitId: widget.pitId,
      title: _title.text.trim(),
      body: _body.text.trim(),
      images: imgs,
      tagIds: _tagIds,
      links: [
        for (final l in _links)
          if (l.url.text.trim().isNotEmpty)
            SocialLink(l.platform.label, l.url.text.trim()),
      ],
      targetLikes: int.tryParse(_target.text.trim()) ?? 0,
      finishedAt: _finishedAt,
      ideaIds: _ideaIds,
      draftIds: _draftIds,
      isPublished: _published,
      publishedAt: _publishedAt ?? _finishedAt,
      isCommission: _commission,
      client: _client.text.trim(),
      amount: _num(_amount),
      currency: _currency,
      receivedAmount: _num(_received) ?? 0,
      dueAt: _dueAt,
    );
    if (_isEdit) {
      await db.setActualLikes(id, int.tryParse(_actual.text.trim()) ?? 0);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _linkRow(BuildContext context, int i) {
    final t = context.tokens;
    final row = _links[i];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: pieceFieldLine(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SocialPlatformBadge(row.platform),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: Key('piece-link-$i'),
              controller: row.url,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '貼上連結網址',
                hintStyle: TextStyle(color: t.text4, fontSize: 13),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '移除',
            child: InkResponse(
              radius: 18,
              onTap: () => setState(() => _links.removeAt(i).url.dispose()),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: SvgIcon(
                  AppIcons.closeX,
                  size: 16,
                  strokeWidth: 2,
                  color: t.text4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _publishFields(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const FormLabel('發佈日期'),
      PieceDateField(
        date: _publishedAt ?? _finishedAt,
        semanticLabel: '發佈日期',
        onChanged: (d) => setState(() => _publishedAt = d),
      ),
      const SizedBox(height: 14),
      const FormLabel('社交媒體連結'),
      for (var i = 0; i < _links.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _linkRow(context, i),
        ),
      const SizedBox(height: 2),
      Align(
        alignment: Alignment.centerLeft,
        child: DashedAddChip(
          label: '加社交連結',
          semanticLabel: '加社交連結',
          onTap: () => setState(() => _links.add(_LinkRow(''))),
        ),
      ),
      const SizedBox(height: 16),
      const FormLabel('目標互動量'),
      PieceHeartField(
        fieldKey: const Key('piece-target'),
        controller: _target,
        semanticLabel: '目標互動量',
      ),
      const SizedBox(height: 14),
      if (_isEdit) ...[
        const FormLabel('實際互動量'),
        PieceHeartField(
          fieldKey: const Key('piece-actual'),
          controller: _actual,
          semanticLabel: '實際互動量',
        ),
        const SizedBox(height: 14),
      ],
    ],
  );

  Widget _commissionFields(BuildContext context) {
    final t = context.tokens;
    final sym = pieceCurrencySymbol(_currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormLabel('委託人'),
        TextField(
          key: const Key('piece-client'),
          controller: _client,
          style: const TextStyle(fontSize: 15),
          decoration: entityFieldDecoration(context, ''),
        ),
        const SizedBox(height: 14),
        const FormLabel('金額'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label: '幣種',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final c = await showCurrencySheet(context, _currency);
                    if (c != null) setState(() => _currency = c);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: pieceFieldLine(context)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$sym $_currency',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        SvgIcon(
                          AppIcons.chevronDown,
                          size: 14,
                          strokeWidth: 2,
                          color: t.text3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: '金額',
                  child: TextField(
                    key: const Key('piece-amount'),
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 15),
                    decoration: entityFieldDecoration(context, ''),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const FormLabel('已收金額'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PieceBoxField(
                  child: Row(
                    children: [
                      Text(sym, style: TextStyle(fontSize: 15, color: t.text3)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          label: '已收金額',
                          child: TextField(
                            key: const Key('piece-received'),
                            controller: _received,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 15),
                            decoration: pieceBareInput,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PieceChipButton(
                label: '已收齊',
                on: _fullyReceived,
                onTap: _toggleReceivedAll,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const FormLabel('交稿日期'),
        PieceDateField(
          date: _dueAt,
          semanticLabel: '交稿日期',
          onChanged: (d) => setState(() => _dueAt = d),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ideas =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final drafts =
        ref.watch(draftViewsProvider(widget.pitId)).value ?? const [];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(title: _isEdit ? '編輯成圖' : '新增成圖', titleSize: 20),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          const FormLabel('成品圖'),
                          PieceImageGrid(
                            items: _images,
                            onAdd: () async {
                              final picked = await ref.read(
                                imagePickerProvider,
                              )();
                              if (picked.isNotEmpty) {
                                setState(
                                  () => _images.addAll(
                                    picked.map(ImageItem.picked),
                                  ),
                                );
                              }
                            },
                            onRemove: (i) =>
                                setState(() => _images.removeAt(i)),
                          ),
                          const SizedBox(height: 16),
                          const FormLabel('標題'),
                          TextFormField(
                            key: const Key('piece-title'),
                            controller: _title,
                            style: const TextStyle(fontSize: 15),
                            decoration: entityFieldDecoration(
                              context,
                              '為這張成圖命名',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? '請輸入標題'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const FormLabel('內文'),
                          TextFormField(
                            controller: _body,
                            minLines: 3,
                            maxLines: 8,
                            style: const TextStyle(fontSize: 15, height: 1.55),
                            decoration: entityFieldDecoration(
                              context,
                              '想說的話、創作筆記…',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TagPicker(
                            pitId: widget.pitId,
                            selected: _tagIds,
                            onChanged: (v) => setState(() => _tagIds = v),
                          ),
                          const SizedBox(height: 16),
                          PieceSwitchCard(
                            title: '已公開發佈',
                            value: _published,
                            onChanged: (v) => setState(() => _published = v),
                            child: _publishFields(context),
                          ),
                          PieceSwitchCard(
                            title: '商稿',
                            value: _commission,
                            bottomGap: 18,
                            onChanged: (v) => setState(() => _commission = v),
                            child: _commissionFields(context),
                          ),
                          const FormLabel('完成時間'),
                          PieceDateField(
                            date: _finishedAt,
                            semanticLabel: '完成時間',
                            onChanged: (d) => setState(() => _finishedAt = d),
                          ),
                          const SizedBox(height: 16),
                          ConnectField(
                            label: '關聯腦洞',
                            options: [
                              for (final i in ideas)
                                ConnectOption(
                                  id: i.idea.id,
                                  title: i.idea.title,
                                  file: i.images.isEmpty
                                      ? null
                                      : i.images.first.file,
                                ),
                            ],
                            selected: _ideaIds,
                            onChanged: (v) => setState(() => _ideaIds = v),
                          ),
                          const SizedBox(height: 16),
                          ConnectField(
                            label: '關聯草稿',
                            options: [
                              for (final d in drafts)
                                ConnectOption(
                                  id: d.draft.id,
                                  title: d.draft.title ?? '',
                                  file: d.images.isEmpty
                                      ? null
                                      : d.images.first.file,
                                ),
                            ],
                            selected: _draftIds,
                            onChanged: (v) => setState(() => _draftIds = v),
                          ),
                          const SizedBox(height: 22),
                          FormSubmitButton(
                            label: _isEdit ? '儲存' : '建立成圖',
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
