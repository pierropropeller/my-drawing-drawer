/// 參考圖檢視用到的 icon（路徑抄自 RefFull／RefSplit／RefVideo／Official artboard，24×24）。
abstract final class RefIcons {
  static const back = '<path d="M15 5l-7 7 7 7"/>';

  /// 鎖定縮放（上鎖）。
  static const lock =
      '<rect x="5" y="11" width="14" height="9" rx="2"/>'
      '<path d="M8 11V8a4 4 0 0 1 8 0v3"/>';

  /// 未鎖定（鎖頭打開，RefSplit 的 unlocked 狀態）。
  static const unlock =
      '<rect x="5" y="11" width="14" height="9" rx="2"/>'
      '<path d="M8 11V8a4 4 0 0 1 7.5-2"/>';

  static const flip =
      '<path d="M12 3v18" stroke-dasharray="2 2.5"/>'
      '<path d="M9 7L4 17h5z"/>'
      '<path d="M15 7l5 10h-5z"/>';

  /// 灰階：半實心圓（右半填色）。
  static const gray =
      '<circle cx="12" cy="12" r="8"/>'
      '<path d="M12 4a8 8 0 0 1 0 16z" fill="currentColor" stroke="none"/>';

  static const background =
      '<rect x="4" y="4" width="16" height="16" rx="3"/>'
      '<path d="M4 16L20 4"/>';

  /// 更多（三點，實心）。
  static const more =
      '<g fill="currentColor" stroke="none">'
      '<circle cx="6" cy="12" r="1.7"/>'
      '<circle cx="12" cy="12" r="1.7"/>'
      '<circle cx="18" cy="12" r="1.7"/></g>';

  /// 資料面板開關。
  static const panel =
      '<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/>'
      '<path d="M14.5 4.5v15"/>';

  /// 參考檢視入口（四角展開，Official／FanArt 預覽面板）。
  static const expand = '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>';

  // 資料面板的動作（RefFull）。
  static const setCover =
      '<rect x="4" y="4" width="16" height="16" rx="2.5"/>'
      '<path d="M4 15l4.5-4 4 3.5 3-2.5L20 15.5"/>';
  static const download =
      '<path d="M12 4v11M7.5 10.5L12 15l4.5-4.5"/><path d="M5 19h14"/>';
  static const share =
      '<circle cx="18" cy="5.5" r="2.5"/><circle cx="6" cy="12" r="2.5"/>'
      '<circle cx="18" cy="18.5" r="2.5"/><path d="M8.2 10.8l7.6-4M8.2 13.2l7.6 4"/>';
  static const edit = '<path d="M4 20l1-4L15.5 5.5a2.1 2.1 0 0 1 3 3L8 19z"/>';
  static const trash = '<path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/>';

  // 影片參考（RefVideo）。
  static const camera =
      '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>';
  static const prevFrame = '<path d="M7 5v14"/><path d="M18 6l-8 6 8 6z"/>';
  static const nextFrame = '<path d="M17 5v14"/><path d="M6 6l8 6-8 6z"/>';
  static const loop =
      '<path d="M17 2l3 3-3 3M3 11V9a4 4 0 0 1 4-4h13M7 22l-3-3 3-3M21 13v2a4 4 0 0 1-4 4H4"/>';
  // 播放／暫停是實心圖形（fill 要傳 currentColor）。
  static const play =
      '<path d="M4 2l16 10L4 22z" fill="currentColor" stroke="none"/>';
  static const pause =
      '<g fill="currentColor" stroke="none">'
      '<rect x="6" y="5" width="4" height="14" rx="1"/>'
      '<rect x="14" y="5" width="4" height="14" rx="1"/></g>';
}
