import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'album_image.dart';

/// 預覽頁固定深色（ImagePreview／FanArtPreview 設計稿），不隨主題變化。
abstract final class PreviewPalette {
  static const bg = Color(0xFF1E1B18);
  static const text = Color(0xFFF5F0E8);
  static const muted = Color(0xFFA49A8C);
  static const action = Color(0xFFE9E2D8);
  static const danger = Color(0xFFF08A76);

  /// 官方分組小標底色。
  static const pill = Color(0xFFC9D6E3);

  /// 同人圖出處小標底色。
  static const pillFan = Color(0xFFE8C6CF);

  /// 同人圖 tag 底色（白 12%）。
  static const tagBg = Color(0x1FFFFFFF);
  static const tagText = Color(0xFFF2ECE4);
}

/// 「2026 / 09 / 21 加入」。
String previewDate(DateTime d, [AppLocalizations? l10n]) =>
    (l10n ?? l10nStatic).albumPreviewDateAdded(
      d.year,
      d.month.toString().padLeft(2, '0'),
      d.day.toString().padLeft(2, '0'),
    );

class PreviewAction {
  const PreviewAction(this.svg, this.label, this.onTap, {this.color});
  final String svg;
  final String label;
  final VoidCallback onTap;
  final Color? color;
}

/// 預覽頁骨架：返回＋標題＋頁碼、可左右滑動的圖、資訊區、底部動作列。
class PreviewShell extends StatelessWidget {
  const PreviewShell({
    super.key,
    required this.title,
    required this.counter,
    required this.controller,
    required this.files,
    required this.onPageChanged,
    required this.info,
    required this.actions,
  });

  final String title;
  final String counter;
  final PageController controller;
  final List<String> files;
  final ValueChanged<int> onPageChanged;
  final Widget info;
  final List<PreviewAction> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PreviewPalette.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.commonBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const SvgIcon(
                      AppIcons.back,
                      color: PreviewPalette.text,
                      strokeWidth: 1.9,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PreviewPalette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      counter,
                      style: const TextStyle(
                        color: PreviewPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: PageView.builder(
                  controller: controller,
                  itemCount: files.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (_, i) => InteractiveViewer(
                    maxScale: 5,
                    child: SizedBox.expand(
                      child: StoredImage(files[i], fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
            info,
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
              ),
              child: Row(children: [for (final a in actions) _ActionButton(a)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.action);
  final PreviewAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.color ?? PreviewPalette.action;
    return Expanded(
      child: InkWell(
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(action.svg, size: 22, color: color, strokeWidth: 1.7),
              const SizedBox(height: 5),
              Text(action.label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
