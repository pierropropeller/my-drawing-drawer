import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../entity/entity_widgets.dart' show DashedAddChip;
import '../entity/piece_platform.dart';
import 'album_actions.dart' show promptText;
import 'album_form.dart' show AlbumFieldLabel;

/// 同人圖的「原文連結」（D-158，TweetLinkEdit）：有連結＝鎖鏈方塊＋網址＋✕（同成圖的連結樣式）；
/// 沒有＝虛線「＋ 加原文連結」。
class SourceUrlField extends StatelessWidget {
  const SourceUrlField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  Future<void> _edit(BuildContext context) async {
    final l = context.l10n;
    final v = await promptText(
      context,
      title: l.tweetshareSourceUrl,
      initial: value ?? '',
    );
    if (v == null) return;
    final s = v.trim();
    onChanged(s.isEmpty ? null : s);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlbumFieldLabel(l.tweetshareSourceUrl),
        if (v == null || v.isEmpty)
          DashedAddChip(
            key: const ValueKey('sourceUrlAdd'),
            label: l.tweetshareAddSourceUrl,
            semanticLabel: l.tweetshareAddSourceUrl,
            onTap: () => _edit(context),
          )
        else
          GestureDetector(
            key: const ValueKey('sourceUrlRow'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _edit(context),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.field),
              ),
              child: Row(
                children: [
                  const SocialPlatformBadge(PieceSocialPlatform.other),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      v.replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: t.text2),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l.tweetshareRemoveSourceUrl,
                    child: GestureDetector(
                      key: const ValueKey('sourceUrlRemove'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(null),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: SvgIcon(
                          AppIcons.closeX,
                          size: 16,
                          strokeWidth: 2,
                          color: const Color(0xFFB7ADA0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
