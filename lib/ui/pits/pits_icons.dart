/// 坑／主頁用到、共用 AppIcons 沒有的 icon（SVG 圖形取自設計稿）。
class PitsIcons {
  const PitsIcons._();

  /// 坑內頁最底的「雜物」入口 icon（PitJunk）。
  static const junk =
      '<rect x="3.5" y="9" width="17" height="11" rx="2"/>'
      '<path d="M6 9V6.5A1.5 1.5 0 0 1 7.5 5h9A1.5 1.5 0 0 1 18 6.5V9M10 13.5h4"/>';

  /// 推活（星星；坑內頁第六格，Pit）。
  static const oshi =
      '<path d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>';

  /// 四格（淺坑還沒開啟任何格子的空白狀態，PitShallowEmpty）。
  static const emptyCells =
      '<rect x="4" y="4" width="7" height="7" rx="1.8"/>'
      '<rect x="13" y="4" width="7" height="7" rx="1.8"/>'
      '<rect x="4" y="13" width="7" height="7" rx="1.8"/>'
      '<rect x="13" y="13" width="7" height="7" rx="1.8"/>';

  /// 拖動把手（兩條橫線；主頁淺坑／封存坑列表的編輯排序，MainShallowSortEdit）。
  static const dragHandle =
      '<path d="M5 9h14M5 15h14" stroke-linecap="round"/>';

  /// 向下／向上箭頭（底部排序列：新→舊／舊→新，MainSortEdit）。
  static const arrowDown =
      '<path d="M12 5v14M6.5 13.5L12 19l5.5-5.5" stroke-linecap="round" stroke-linejoin="round"/>';
  static const arrowUp =
      '<path d="M12 19V5M6.5 10.5L12 5l5.5 5.5" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 垃圾桶（更換封面 sheet 的「移除封面」，MainSortCover）。
  static const trash =
      '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4h6v3" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 勾（目前的封面，MainSortCover）。
  static const check =
      '<path d="M5 12.5l4.5 4.5L19 7.5" stroke-linecap="round" stroke-linejoin="round"/>';
}
