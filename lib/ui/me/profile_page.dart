import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/user_avatar.dart';
import '../common/window_class.dart';
import '../material/material_icons.dart';
import '../material/material_library_page.dart';
import 'about_page.dart';
import 'backup_page.dart';
import 'me_widgets.dart';
import 'personalize_page.dart';
import 'profile_edit_page.dart';
import '../../l10n/l10n.dart';

/// iPad 版「我的」右側內容面板顯示哪一項（Profile 稿的設定列；D-106 起主題色、App 圖示、語言、敏感內容收進「個人化」）。
enum ProfileSection { library, personalize, backup, about }

/// 其他地方（例如同步進度 popover 的「同步設定」）要「我的」切到某一項時寫入；
/// ProfilePage 收到後切換並清掉。
class ProfileSectionRequest extends Notifier<ProfileSection?> {
  @override
  ProfileSection? build() => null;

  void request(ProfileSection s) => state = s;
  void clear() => state = null;
}

final profileSectionRequestProvider =
    NotifierProvider<ProfileSectionRequest, ProfileSection?>(
      ProfileSectionRequest.new,
    );

/// 我的：頭像、暱稱、編輯個人資料、主題色／備份與同步／關於 App 入口。
///
/// 手機（＜600，或內容區太窄）＝一欄列表，點列進子頁。
/// ≥600 且內容夠寬（iPad／平板）＝左設定列表（360）＋右內容面板（Profile 稿）：點列只切換右側內容，
/// 不 push 頁面；目前選的項目放在 State，拉窗（手機版 ↔ 並排）來回後仍保留。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  /// 內容區（扣掉側邊導覽）至少這麼寬才並排；再窄右側面板會小到沒法用。
  static const splitMinWidth = 500.0;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  /// 並排版右側目前顯示的項目（預設「個人化」）。
  ProfileSection _section = ProfileSection.personalize;

  void _takeRequest(ProfileSection? s) {
    if (s == null) return;
    ref.read(profileSectionRequestProvider.notifier).clear();
    if (mounted) setState(() => _section = s);
  }

  @override
  void initState() {
    super.initState();
    final pending = ref.read(profileSectionRequestProvider);
    if (pending != null) {
      _section = pending;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(profileSectionRequestProvider.notifier).clear(),
      );
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _editProfile() => _push(const ProfileEditPage());

  @override
  Widget build(BuildContext context) {
    ref.listen(profileSectionRequestProvider, (_, next) => _takeRequest(next));
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) =>
              WindowClass.of(context).hasSideNav &&
                  box.maxWidth >= ProfilePage.splitMinWidth
              ? _split(context, box.maxWidth)
              : _phone(context),
        ),
      ),
    );
  }

  // ---- 共用：各列的文字與圖示色 ----

  String _backupLabel(BuildContext context, AppSettings s, SyncState sync) =>
      s.accountEmail == null
      ? context.l10n.meBackupNotLinked
      : (sync.lastSyncAt == null
            ? context.l10n.meBackupLinked
            : meTimeLabel(sync.lastSyncAt));

  // ---- 手機：一欄列表（與原本完全相同） ----

  Widget _phone(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final backupLabel = _backupLabel(context, s, sync);
    final materialTotal = ref.watch(materialCountsProvider).value?.total ?? 0;

    Widget row({
      String? icon,
      Color? tileBg,
      Color? tileFg,
      required String title,
      String? value,
      required VoidCallback onTap,
      bool last = false,
    }) => MeListRow(
      icon: icon,
      tileBg: tileBg,
      tileFg: tileFg,
      title: title,
      value: value,
      onTap: onTap,
      last: last,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Text(
            context.l10n.meTitle,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 24),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 22),
                child: Column(
                  children: [
                    UserAvatar(
                      size: 84,
                      serif: true,
                      background: t.accentSoft,
                      foreground: t.accent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.nickname.isEmpty
                          ? context.l10n.meSetNickname
                          : s.nickname,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    _EditProfileChip(onTap: _editProfile),
                  ],
                ),
              ),
              // 素材庫（D-071）：獨立一張卡，右邊顯示總張數。
              MePanel(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  type: MaterialType.transparency,
                  child: row(
                    icon: MaterialLibIcons.library,
                    tileBg: t.accentSoft,
                    tileFg: t.piece.fg,
                    title: context.l10n.materialTitle,
                    value: context.l10n.commonCountImages(materialTotal),
                    last: true,
                    onTap: () => _push(const MaterialLibraryPage()),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              MePanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      // 個人化（D-106）：主題色、App 圖示、語言、敏感內容都在裡面。
                      row(
                        icon: AppIcons.personalize,
                        tileBg: t.piece.bg,
                        tileFg: t.piece.fg,
                        title: context.l10n.personalizeTitle,
                        onTap: () => _push(const PersonalizePage()),
                      ),
                      row(
                        icon: AppIcons.cloud,
                        tileBg: dark ? t.official.bg : const Color(0xFFEAF0F5),
                        tileFg: t.official.fg,
                        title: context.l10n.meBackupSync,
                        value: backupLabel,
                        onTap: () => _push(const BackupPage()),
                      ),
                      row(
                        icon: AppIcons.info,
                        tileBg: dark ? t.chipBg : const Color(0xFFEEEAE2),
                        tileFg: t.text3,
                        title: context.l10n.meAbout,
                        last: true,
                        onTap: () => _push(const AboutPage()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- iPad／平板：左設定列表＋右內容面板（Profile 稿） ----

  Widget _split(BuildContext context, double width) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final materialTotal = ref.watch(materialCountsProvider).value?.total ?? 0;
    // 稿：列表欄 360；內容區較窄時縮到 280。
    final listW = (width * 0.34).clamp(280.0, 360.0);

    Widget item({
      required ProfileSection section,
      String? icon,
      Widget? leading,
      Color? tileBg,
      Color? tileFg,
      required String title,
      String? value,
    }) => _SplitRow(
      selected: _section == section,
      icon: icon,
      leading: leading,
      tileBg: tileBg,
      tileFg: tileFg,
      title: title,
      value: value,
      onTap: () => setState(() => _section = section),
    );

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            context.l10n.meTitle,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 22),
          child: Row(
            spacing: 14,
            children: [
              UserAvatar(
                size: 68,
                serif: true,
                background: t.accentSoft,
                foreground: t.accent,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.nickname.isEmpty
                          ? context.l10n.meSetNickname
                          : s.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 6),
                    _EditProfileChip(onTap: _editProfile, height: 44),
                  ],
                ),
              ),
            ],
          ),
        ),
        Column(
          spacing: 4,
          children: [
            item(
              section: ProfileSection.library,
              icon: MaterialLibIcons.library,
              tileBg: t.accentSoft,
              tileFg: t.piece.fg,
              title: context.l10n.materialTitle,
              value: context.l10n.commonCountImages(materialTotal),
            ),
            item(
              section: ProfileSection.personalize,
              icon: AppIcons.personalize,
              tileBg: t.piece.bg,
              tileFg: t.piece.fg,
              title: context.l10n.personalizeTitle,
            ),
            item(
              section: ProfileSection.backup,
              icon: AppIcons.cloud,
              tileBg: dark ? t.official.bg : const Color(0xFFEAF0F5),
              tileFg: t.official.fg,
              title: context.l10n.meBackupSync,
              value: _backupLabel(context, s, sync),
            ),
            item(
              section: ProfileSection.about,
              icon: AppIcons.info,
              tileBg: dark ? t.chipBg : const Color(0xFFEEEAE2),
              tileFg: t.text3,
              title: context.l10n.meAbout,
            ),
          ],
        ),
      ],
    );

    final Widget panel = switch (_section) {
      ProfileSection.library => const MaterialLibraryPage(embedded: true),
      ProfileSection.personalize => const PersonalizePage(embedded: true),
      ProfileSection.backup => const BackupPage(embedded: true),
      ProfileSection.about => const AboutPage(embedded: true),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: listW,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: t.border)),
          ),
          child: Material(type: MaterialType.transparency, child: list),
        ),
        Expanded(
          // 換項目時重建面板（各面板自己的暫時狀態，例如素材庫的分類，不帶到別項）。
          child: KeyedSubtree(key: ValueKey(_section), child: panel),
        ),
      ],
    );
  }
}

/// 「編輯個人資料」小膠囊。
class _EditProfileChip extends StatelessWidget {
  const _EditProfileChip({required this.onTap, this.height});
  final VoidCallback onTap;

  /// 並排版要有 44 的觸控範圍（視覺仍是小膠囊）。
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: dark ? t.border : const Color(0xFFE3D8C9)),
      ),
      child: Text(
        context.l10n.meEditProfile,
        style: TextStyle(fontSize: 12.5, color: t.text2),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: height == null
          ? chip
          : SizedBox(
              height: height,
              child: Align(alignment: Alignment.centerLeft, child: chip),
            ),
    );
  }
}

/// 並排版的設定列（Profile 稿）：60 高、圓角 14，選中＝白底＋粗體；右邊是目前值，沒有箭頭。
class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.selected,
    required this.title,
    required this.onTap,
    this.icon,
    this.leading,
    this.tileBg,
    this.tileFg,
    this.value,
  });
  final bool selected;
  final String title;
  final String? value;
  final String? icon;
  final Widget? leading;
  final Color? tileBg;
  final Color? tileFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                spacing: 12,
                children: [
                  leading ??
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tileBg,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: SvgIcon(
                            icon!,
                            size: 21,
                            color: tileFg,
                            strokeWidth: 1.7,
                          ),
                        ),
                      ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (value != null)
                    Flexible(
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: t.text3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
