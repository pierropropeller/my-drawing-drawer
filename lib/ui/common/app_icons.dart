/// 設計稿用到的 icon 圖形（24×24，搭配 `SvgIcon`）。
/// 新增 icon 時照設計稿原樣貼上 `<path>` 等圖形，並註明出處畫面。
abstract final class AppIcons {
  /// 返回箭頭（所有子頁面左上；設計稿線寬 1.9）。
  static const back = '<path d="M15 5l-7 7 7 7"/>';

  /// 加號（新增）。
  static const plus = '<path d="M12 5v14M5 12h14"/>';

  /// 編輯（鉛筆；坑內頁右上、草稿格）。
  static const edit =
      '<path d="M4 20l1-4L15.5 5.5a2.1 2.1 0 0 1 3 3L8 19z"/><path d="M13.5 7.5l3 3"/>';

  /// 圖片佔位（相框＋圓＋山）。
  static const image =
      '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="8.5" cy="9.5" r="1.8"/><path d="M3.5 16.5l4.5-4 4 3 3-2.5 5.5 4.5"/>';

  /// 向右箭頭（列表列尾端）。
  static const chevronRight = '<path d="M9 5l7 7-7 7"/>';

  /// 勾。
  static const check = '<path d="M5 12.5l4 4 10-10"/>';

  /// 雲（備份與同步）。
  static const cloud =
      '<path d="M7 18h11a3 3 0 0 0 .3-6 5 5 0 0 0-9.6-1.6A3.6 3.6 0 0 0 7 18z"/>';

  /// 雲＋斜線（離線）。
  static const cloudOff =
      '<path d="M7 18h9a3 3 0 0 0 .5-6 5 5 0 0 0-8-3"/><path d="M3 3l18 18"/>';

  /// 田字（2×2 方格檢視）。
  static const gridView =
      '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>';

  /// 瀑布檢視（一高一矮兩欄）。
  static const waterfallView =
      '<rect x="4" y="4" width="7" height="16" rx="1.5"/><rect x="13" y="4" width="7" height="10" rx="1.5"/>';

  /// 資料夾（主頁「坑」、主頁空白狀態）。Main／MainEmpty
  static const folder =
      '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>';

  /// 垃圾桶（刪除這個坑）。PitEdit
  static const trash = '<path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/>';

  /// 鉛筆＋圓點（開頭畫面 logo）。Welcome
  static const pencilDot =
      '<path d="M4 20l1-4L15.5 5.5a2.1 2.1 0 0 1 3 3L8 19z"/><path d="M13.5 7.5l3 3"/><circle cx="6" cy="18" r="1.1" fill="currentColor" stroke="none"/>';

  /// 手機／螢幕（連結帳號插圖左）。Connect
  static const deviceSmall =
      '<rect x="4" y="5" width="16" height="12" rx="1.6"/><path d="M9 20h6"/>';

  /// 桌機螢幕（連結帳號插圖右）。Connect
  static const deviceLarge =
      '<rect x="3" y="4" width="18" height="14" rx="1.8"/><path d="M8 21h8"/>';

  /// 雲（連結帳號插圖中）。Connect
  static const cloudSync =
      '<path d="M7 18h10a3 3 0 0 0 .4-6 5 5 0 0 0-9.7-1.5A3.6 3.6 0 0 0 7 18z"/>';

  /// 左右箭括（連結帳號插圖同步符號）。Connect
  static const codeArrows = '<path d="M8 7l-4 5 4 5M16 7l4 5-4 5"/>';

  /// 官方圖冊（雙頁書；坑內頁、OfficialEmpty）。
  static const pitOfficial =
      '<path d="M4 5.5A1.5 1.5 0 0 1 5.5 4H11v16H5.5A1.5 1.5 0 0 1 4 18.5z"/><path d="M20 5.5A1.5 1.5 0 0 0 18.5 4H13v16h5.5A1.5 1.5 0 0 0 20 18.5z"/>';

  /// 好看同人圖（相框＋實心愛心；坑內頁）。
  static const pitFanArt =
      '<rect x="3" y="4" width="18" height="16" rx="2.5"/><path d="M12 16.5c-2-1.4-3.4-2.7-3.4-4.2A1.6 1.6 0 0 1 12 11a1.6 1.6 0 0 1 3.4 1.3c0 1.5-1.4 2.8-3.4 4.2z" fill="currentColor" stroke="none"/>';

  /// 我的腦洞（燈泡；坑內頁）。
  static const pitIdea =
      '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 1 4 10.5c-.7.7-1 1.2-1 2H9c0-.8-.3-1.3-1-2A6 6 0 0 1 12 3z"/>';

  /// 我的成圖（坑內頁尚無成圖的卡片）。
  static const pitPieceEmpty =
      '<rect x="3" y="5" width="18" height="14" rx="2.5"/><circle cx="8.5" cy="10" r="1.6"/><path d="M3.5 17l4.5-4 3.5 2.8"/>';

  /// 關閉 X（多選取消）。
  static const closeX = '<path d="M6 6l12 12M18 6L6 18"/>';

  /// 分組管理（兩條滑桿；OfficialList 篩選列最右）。
  static const sliders =
      '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>';

  /// 分享（ImagePreview）。
  static const share =
      '<circle cx="18" cy="5.5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="18.5" r="2.5"/><path d="M8.2 10.8l7.6-4M8.2 13.2l7.6 4"/>';

  /// 下載（ImagePreview、OfficialSelect）。
  static const download =
      '<path d="M12 4v11M7.5 10.5L12 15l4.5-4.5"/><path d="M5 19h14"/>';

  /// 設為封面（ImagePreview）。
  static const setCover =
      '<rect x="4" y="4" width="16" height="16" rx="2.5"/><path d="M4 15l4.5-4 4 3.5 3-2.5L20 15.5"/>';

  /// 拖曳把手（六點；GroupManage，實心）。
  static const dragDots =
      '<circle cx="9" cy="7" r="1.4"/><circle cx="15" cy="7" r="1.4"/><circle cx="9" cy="12" r="1.4"/><circle cx="15" cy="12" r="1.4"/><circle cx="9" cy="17" r="1.4"/><circle cx="15" cy="17" r="1.4"/>';

  /// 腦洞（燈泡；IdeaEmpty、DraftList 連接 chip、DraftNew）。
  static const bulb =
      '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 1 4 10.5c-.7.7-1 1.2-1 2H9c0-.8-.3-1.3-1-2A6 6 0 0 1 12 3z"/>';

  /// 列表檢視（兩條橫列；DraftList 切換）。
  static const listRows =
      '<rect x="4" y="4" width="16" height="7" rx="1.5"/><rect x="4" y="13" width="16" height="7" rx="1.5"/>';

  /// 九宮格檢視（DraftList／DraftGrid 切換）。
  static const grid3x3 =
      '<rect x="3.5" y="3.5" width="5" height="5" rx="1"/><rect x="9.5" y="3.5" width="5" height="5" rx="1"/><rect x="15.5" y="3.5" width="5" height="5" rx="1"/><rect x="3.5" y="9.5" width="5" height="5" rx="1"/><rect x="9.5" y="9.5" width="5" height="5" rx="1"/><rect x="15.5" y="9.5" width="5" height="5" rx="1"/><rect x="3.5" y="15.5" width="5" height="5" rx="1"/><rect x="9.5" y="15.5" width="5" height="5" rx="1"/><rect x="15.5" y="15.5" width="5" height="5" rx="1"/>';

  /// 調色盤（我的：主題色列）。Profile
  static const palette =
      '<path d="M12 3a9 9 0 1 0 1 17.9c.9-.1 1.2-1 .8-1.7-.5-.9.1-2 1.2-2H17a4 4 0 0 0 4-4c0-4.4-4-7.2-9-7.2z"/><circle cx="8" cy="11" r="1" fill="currentColor" stroke="none"/><circle cx="12" cy="8" r="1" fill="currentColor" stroke="none"/><circle cx="16" cy="10" r="1" fill="currentColor" stroke="none"/>';

  /// 地球（我的：語言列）。
  static const globe =
      '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.6 3.7 5.6 3.7 9s-1.2 6.4-3.7 9c-2.5-2.6-3.7-5.6-3.7-9S9.5 5.6 12 3z"/>';

  /// 資訊（我的：關於 App 列）。Profile
  static const info =
      '<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><circle cx="12" cy="7.8" r="1" fill="currentColor" stroke="none"/>';

  /// 左右換向箭頭（更換同步的 Google 帳號）。Backup
  static const swap = '<path d="M4 8h13l-3-3M20 16H7l3 3"/>';

  /// 向下箭頭（刷新間隔下拉選單）。Backup（對應原生 select 的箭頭）
  static const chevronDown = '<path d="M6 9l6 6 6-6"/>';

  /// 愛心（成圖互動量；實心用 fill、空心用線條）。Finished／PieceDetail／Day。
  static const heart =
      '<path d="M12 20c-5-3.3-8-6.4-8-10a4 4 0 0 1 8-1.4A4 4 0 0 1 20 10c0 3.6-3 6.7-8 10z"/>';

  /// 外開連結（PieceDetail 社交媒體連結列尾）。
  static const externalLink =
      '<path d="M14 5h5v5M19 5l-8 8M11 5H7a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4"/>';
}
