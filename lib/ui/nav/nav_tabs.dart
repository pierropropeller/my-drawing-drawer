import '../../l10n/l10n.dart';

/// 導覽的三個分頁：坑／時間軸／我的。底部列、icon rail、sidebar 共用同一份 icon。
///
/// icon 直接取自設計稿（GoalYear／Main／Profile 的 nav）：資料夾、時間軸（直線＋兩點＋橫線）、人像；
/// 未選中線寬 1.8，選中線寬 2。
class NavTab {
  const NavTab(this.id, this._shapes);
  final int id;

  /// SVG（24×24）內的圖形。
  final String _shapes;

  String label(AppLocalizations l) => switch (id) {
    0 => l.shellTabPits,
    1 => l.shellTabGoals,
    _ => l.shellTabMe,
  };

  String svg(double strokeWidth) =>
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
      'fill="none" stroke="currentColor" stroke-width="$strokeWidth" '
      'stroke-linecap="round" stroke-linejoin="round">$_shapes</svg>';
}

const navTabs = [
  NavTab(
    0,
    '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  ),
  NavTab(
    1,
    '<path d="M6 4v16"/>'
    '<circle cx="6" cy="7" r="1.9" fill="currentColor" stroke="none"/>'
    '<circle cx="6" cy="17" r="1.9" fill="currentColor" stroke="none"/>'
    '<path d="M10.5 7h8M10.5 12h6M10.5 17h8"/>',
  ),
  NavTab(
    2,
    '<circle cx="12" cy="8" r="4"/><path d="M4.5 20c0-4.2 3.8-6 7.5-6s7.5 1.8 7.5 6"/>',
  ),
];
