import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../common/user_avatar.dart';
import '../pits/pit_form.dart';
import 'me_icons.dart';
import 'me_widgets.dart';
import '../../l10n/l10n.dart';

/// 編輯個人資料（ProfileEdit）：點頭像更換、暱稱、儲存。沒有導覽列。
/// 頭像和暱稱都在按「儲存」時才寫入設定。
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage>
    with HidesNavBar {
  late final TextEditingController _nick;

  /// 這次選好、尚未儲存的頭像檔名。
  String? _pendingAvatar;

  @override
  void initState() {
    super.initState();
    _nick = TextEditingController(text: ref.read(settingsProvider).nickname);
  }

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ref.read(imagePickerProvider)();
      if (picked.isEmpty) return;
      final store = await ref.read(imageStoreProvider.future);
      final im = await store.import(picked.first);
      if (mounted) setState(() => _pendingAvatar = im.file);
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    }
  }

  void _save() {
    final n = ref.read(settingsProvider.notifier);
    n.setNickname(_nick.text.trim());
    if (_pendingAvatar != null) n.setAvatar(_pendingAvatar);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final avatarBg = t.accentSoft;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            MeSubHeader(context.l10n.meEditProfile, bottom: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Semantics(
                        button: true,
                        label: context.l10n.meChangeAvatar,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 6),
                            child: SizedBox(
                              width: 104,
                              height: 104,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: _pendingAvatar != null
                                        ? ClipOval(
                                            child: StoredImage(
                                              _pendingAvatar!,
                                              cacheWidth: 312,
                                            ),
                                          )
                                        : UserAvatar(
                                            size: 104,
                                            serif: true,
                                            background: avatarBg,
                                            foreground: t.accent,
                                          ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 2,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: t.ink,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: t.ground,
                                          width: 3,
                                        ),
                                      ),
                                      child: Center(
                                        child: SvgIcon(
                                          MeIcons.camera,
                                          size: 16,
                                          strokeWidth: 2,
                                          color: dark ? t.ground : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      context.l10n.meTapAvatarToChange,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: t.text3),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: Text(
                        context.l10n.meNickname,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.text2,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _nick,
                      style: const TextStyle(fontSize: 15),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: pitInputDecoration(context),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(context.l10n.commonSave),
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
