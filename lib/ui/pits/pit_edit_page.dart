import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/cover_pick_page.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'pit_form.dart';
import '../common/app_switch.dart';

/// 編輯坑：封存、坑名、描述、刪除。坑內有圖才顯示「更換封面」。
class PitEditPage extends ConsumerStatefulWidget {
  const PitEditPage({super.key, required this.pit});
  final Pit pit;

  @override
  ConsumerState<PitEditPage> createState() => _PitEditPageState();
}

class _PitEditPageState extends ConsumerState<PitEditPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pit.name);
  late final _desc = TextEditingController(text: widget.pit.description ?? '');
  late bool _archived = widget.pit.archived;

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
                            // 坑內有圖才顯示封面預覽與「更換封面」。
                            if (hasImages) ...[
                              const PitFieldLabel('封面'),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 110,
                                      height: 110,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          Radii.card,
                                        ),
                                        child: coverFile != null
                                            ? StoredImage(
                                                coverFile,
                                                cacheWidth: 330,
                                              )
                                            : ColoredBox(
                                                color: t.official.bg,
                                                child: Center(
                                                  child: SvgIcon(
                                                    AppIcons.image,
                                                    size: 30,
                                                    strokeWidth: 1.5,
                                                    color: dark
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: .22,
                                                              )
                                                        : t.ink.withValues(
                                                            alpha: .24,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => CoverPickPage(
                                            pitId: widget.pit.id,
                                          ),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: t.surface,
                                          border: Border.all(color: t.border),
                                          borderRadius: BorderRadius.circular(
                                            Radii.chip,
                                          ),
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
                                ),
                              ),
                            ],
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
                            // 設計稿沒有封存欄位；封存功能保留，放在描述下方。
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '封存',
                                      style: TextStyle(
                                        color: t.text2,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  AppSwitch(
                                    semanticLabel: '封存',
                                    value: _archived,
                                    onChanged: (v) =>
                                        setState(() => _archived = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
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
