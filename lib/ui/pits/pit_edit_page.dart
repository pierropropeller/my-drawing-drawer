import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/cover_pick_page.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/app_switch.dart';
import '../common/dashed_box.dart';
import '../common/nav_bar_hidden.dart';
import 'pit_form.dart';

/// 編輯坑：封面、坑名、描述、雜物開關、封存、刪除。
/// 封面區三種狀態：坑內沒有圖＝不顯示（PitEdit-ntnf）；有圖沒封面＝虛線＋號（PitEditNoCover）；
/// 有封面＝縮圖＋「更換封面」（PitEdit）。
class PitEditPage extends ConsumerStatefulWidget {
  const PitEditPage({super.key, required this.pit});
  final Pit pit;

  @override
  ConsumerState<PitEditPage> createState() => _PitEditPageState();
}

class _PitEditPageState extends ConsumerState<PitEditPage>
    with HidesNavBar<PitEditPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pit.name);
  late final _desc = TextEditingController(text: widget.pit.description ?? '');
  late bool _archived = widget.pit.archived;
  late bool _junk = widget.pit.junkEnabled;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final desc = _desc.text.trim();
    await ref
        .read(databaseProvider)
        .updatePit(
          widget.pit.id,
          name: _name.text.trim(),
          description: desc.isEmpty ? null : desc,
          archived: _archived,
          junkEnabled: _junk,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除這個坑？'),
        content: const Text('坑內的內容也會一併刪除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('刪除', style: TextStyle(color: ctx.tokens.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(databaseProvider).deletePit(widget.pit.id);
    if (!mounted) return;
    // 回到主頁（越過坑內頁）。
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _pickCover() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CoverPickPage(pitId: widget.pit.id),
    ),
  );

  Widget _coverSection(String? coverFile) {
    final t = context.tokens;
    final Widget tile;
    if (coverFile == null) {
      // 有圖但還沒設封面：虛線正方框＋號，點了進選擇封面。
      tile = Semantics(
        button: true,
        label: '選擇封面',
        child: GestureDetector(
          onTap: _pickCover,
          child: SizedBox(
            width: 110,
            height: 110,
            child: DashedBox(
              color: t.dashed,
              radius: Radii.card,
              child: Center(
                child: SvgIcon(
                  AppIcons.plus,
                  size: 26,
                  strokeWidth: 2,
                  color: t.dashedText,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      tile = Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.card),
              child: StoredImage(coverFile, cacheWidth: 330),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text(
                '更換封面',
                style: TextStyle(
                  color: t.text2,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PitFieldLabel('封面'),
        Padding(padding: const EdgeInsets.only(bottom: 18), child: tile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasImages =
        (ref.watch(pitStatsProvider(widget.pit.id)).value?.imageCount ?? 0) > 0;
    final coverFile = ref.watch(coverFileProvider(widget.pit.id)).value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PitHeader(title: '編輯坑'),
            Expanded(
              child: Form(
                key: _form,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasImages) _coverSection(coverFile),
                            const PitFieldLabel('坑名'),
                            TextFormField(
                              controller: _name,
                              style: const TextStyle(fontSize: 15),
                              decoration: pitInputDecoration(context),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? '請輸入坑名'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            const PitFieldLabel('描述'),
                            TextFormField(
                              controller: _desc,
                              minLines: 3,
                              maxLines: 6,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.55,
                              ),
                              decoration: pitInputDecoration(context),
                            ),
                            const SizedBox(height: 16),
                            _SwitchCard(
                              label: '雜物',
                              value: _junk,
                              onChanged: (v) => setState(() => _junk = v),
                            ),
                            // 設計稿沒有封存欄位；封存功能保留，樣式比照雜物開關。
                            const SizedBox(height: 10),
                            _SwitchCard(
                              label: '封存',
                              value: _archived,
                              onChanged: (v) => setState(() => _archived = v),
                            ),
                            const SizedBox(height: 22),
                            PitPrimaryButton(label: '儲存', onPressed: _save),
                            const SizedBox(height: 28),
                            const Spacer(),
                            GestureDetector(
                              onTap: _delete,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: dark
                                        ? t.danger.withValues(alpha: .5)
                                        : const Color(0xFFE7B9AE),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    Radii.button,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgIcon(
                                      AppIcons.trash,
                                      size: 20,
                                      color: t.danger,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '刪除這個坑',
                                      style: TextStyle(
                                        color: t.danger,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '刪除後坑內所有圖片、腦洞、草稿及成圖將一併移除',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: t.text4),
                            ),
                          ],
                        ),
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

/// 白底圓角卡片＋右側開關（PitEdit 的「雜物」）。
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          AppSwitch(semanticLabel: label, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
