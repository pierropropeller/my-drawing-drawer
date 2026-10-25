import 'package:google_sign_in/google_sign_in.dart';

import 'remote.dart';
import 'sync_log.dart';
import '../l10n/l10n.dart';

/// Drive 的「App 專用資料夾」scope（使用者在 Drive 裡看不到這些檔案）。
const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

/// Web 類型的 OAuth Client ID，Android 用 Credential Manager 登入時需要。
/// 透過 `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` 帶入（CI 由 GitHub secret 提供）。
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 帳號服務介面：方便測試時替換。
abstract class AccountService {
  /// 開啟 Google 登入並授權 Drive 專用資料夾，回傳帳號 email。
  Future<String> signIn();

  /// 靜默還原先前登入的帳號；沒有則回傳 null。
  Future<String?> restore();
  Future<void> signOut();
  Future<Map<String, String>> headers();
}

class GoogleAccountService implements AccountService {
  /// 允許互動授權（會彈出 Google／系統畫面）。只有使用者主動觸發的同步（立即同步、首次連結、
  /// 更換帳號）才設成 true；自動同步一律 false，拿不到靜默授權就當作暫時失敗。
  bool allowInteractive = false;

  bool _initialized = false;
  GoogleSignInAccount? _account;

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId.isEmpty
          ? null
          : googleServerClientId,
    );
    _initialized = true;
  }

  @override
  Future<String> signIn() async {
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: [driveAppDataScope],
      );
      final authz = await account.authorizationClient.authorizeScopes([
        driveAppDataScope,
      ]);
      _cacheToken(authz.accessToken);
      _account = account;
      return account.email;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthFailure(l10nStatic.syncCancelled);
      }
      throw AuthFailure(
        l10nStatic.syncLinkFailed(e.description ?? e.code.name),
      );
    } catch (e) {
      throw AuthFailure(l10nStatic.syncLinkFailed('$e'));
    }
  }

  @override
  Future<String?> restore() async {
    try {
      await _init();
      final a = await GoogleSignIn.instance.attemptLightweightAuthentication();
      _account = a;
      return a?.email;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _account = null;
    invalidateToken();
  }

  // 記憶體裡的存取權杖（Google 的權杖約 1 小時有效，保守取 45 分鐘），同步時不用每次都問。
  String? _token;
  DateTime? _tokenUntil;

  bool get _tokenValid =>
      _token != null &&
      _tokenUntil != null &&
      DateTime.now().isBefore(_tokenUntil!);

  Map<String, String> _bearer(String token) => {
    'Authorization': 'Bearer $token',
    'X-Goog-AuthUser': '0',
  };

  void _cacheToken(String token) {
    _token = token;
    _tokenUntil = DateTime.now().add(const Duration(minutes: 45));
  }

  /// 丟掉快取的存取權杖（收到 401 時呼叫），下一次 [headers] 會重新授權。
  void invalidateToken() {
    _token = null;
    _tokenUntil = null;
  }

  // 同時多個請求一起要授權時只問一次（同步會並行下載）。
  Future<Map<String, String>>? _inflight;

  @override
  Future<Map<String, String>> headers() {
    if (_tokenValid) return Future.value(_bearer(_token!));
    return _inflight ??= _fetchHeaders().whenComplete(() => _inflight = null);
  }

  Future<Map<String, String>> _fetchHeaders() async {
    try {
      await _init();
      // 1) 先「靜默授權」：之前授權過 Drive 的話，不需要先登入、也不會彈出
      //    「Signing you in」的 Google 登入小視窗；取不到才往下走。
      var authz = await GoogleSignIn.instance.authorizationClient
          .authorizationForScopes([driveAppDataScope]);
      if (authz == null && !allowInteractive) {
        // 背景同步：不彈任何畫面。連不到 Google（例如中國大陸）或授權過期，都照離線處理。
        syncLog('auth: silent authorization unavailable (background), skip');
        throw SyncAuthUnavailableException(
          l10nStatic.syncAuthExpiredDetail('silent'),
        );
      }
      if (authz == null) {
        // 2) 要互動才能授權（第一次、或授權過期；iOS 上 authorizationForScopes 常回 null）：
        //    才去還原帳號，必要時顯示 Google 的畫面。拿不到就丟出授權失敗，絕不回空標頭。
        syncLog('auth: silent authorization unavailable, going interactive');
        _account ??= await GoogleSignIn.instance
            .attemptLightweightAuthentication();
        final client =
            _account?.authorizationClient ??
            GoogleSignIn.instance.authorizationClient;
        authz =
            await client.authorizationForScopes([driveAppDataScope]) ??
            await client.authorizeScopes([driveAppDataScope]);
      }
      if (authz.accessToken.isEmpty) {
        throw SyncAuthException(
          l10nStatic.syncAuthExpiredDetail('empty token'),
        );
      }
      _cacheToken(authz.accessToken);
      syncLog('auth: token acquired');
      return _bearer(authz.accessToken);
    } on SyncAuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      syncLog('auth: GoogleSignInException ${e.code.name}');
      // 背景：連不上 Google 之類的錯誤一律當暫時失敗（安靜、稍後重試）。
      if (!allowInteractive) {
        throw SyncAuthUnavailableException(
          l10nStatic.syncAuthExpiredDetail('${e.code.name}'),
        );
      }
      throw SyncAuthException(
        l10nStatic.syncAuthExpiredDetail(
          '${e.code.name}：${e.description ?? ''}',
        ),
      );
    } catch (e) {
      syncLog('auth: ${e.runtimeType}');
      if (!allowInteractive) {
        throw SyncAuthUnavailableException(
          l10nStatic.syncAuthExpiredDetail('$e'),
        );
      }
      throw SyncAuthException(l10nStatic.syncAuthExpiredDetail('$e'));
    }
  }
}
