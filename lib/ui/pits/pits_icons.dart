/// 坑／主頁用到、共用 AppIcons 沒有的 icon（SVG 圖形取自設計稿）。
class PitsIcons {
  const PitsIcons._();

  /// 同步橫條的雲＋向下箭頭（MainSyncing）。
  static const syncCloud =
      '<path d="M7 18h10a3 3 0 0 0 .4-6 5 5 0 0 0-9.7-1.5A3.6 3.6 0 0 0 7 18z"/>'
      '<path d="M12 10v5M10 13l2 2 2-2"/>';

  /// 尚未下載的封面上的下載 icon（MainSyncing）。
  static const download = '<path d="M12 5v10M8 11l4 4 4-4M6 19h12"/>';

  /// 坑內頁最底的「雜物」入口 icon（PitJunk）。
  static const junk =
      '<rect x="3.5" y="9" width="17" height="11" rx="2"/>'
      '<path d="M6 9V6.5A1.5 1.5 0 0 1 7.5 5h9A1.5 1.5 0 0 1 18 6.5V9M10 13.5h4"/>';
}
