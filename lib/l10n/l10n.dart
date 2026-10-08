import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// 介面文字：`context.l10n.xxx`。文字一律放 `lib/l10n/app_zh.arb`（內容是繁體中文；gen_l10n 要求有不帶文字系統碼的基底語言），不寫死在 widget 裡。
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// 沒有 BuildContext 的地方（controller、錯誤訊息）取字串用；語言固定是目前唯一的繁體中文。
AppLocalizations get l10nStatic => lookupAppLocalizations(const Locale('zh'));
