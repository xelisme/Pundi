import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';

class AuthService extends ChangeNotifier {
  static const _clientId = '29195344058-liil7hlifg6pb6fd5i0uog40d0jgv98i.apps.googleusercontent.com';
  static const _clientSecret = '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';
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];

  late final GoogleSignIn _googleSignIn;

  GoogleSignInCredentials? _credentials;
  bool _isInitializing = true;

  GoogleSignInCredentials? get credentials => _credentials;
  bool get isSignedIn => _credentials != null;
  bool get isInitializing => _isInitializing;
  String? get accessToken => _credentials?.accessToken;

  /// Google Sign-In only works on Android, iOS, and Web.
  /// Linux, macOS, and Windows desktop are not supported by this library.
  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      kIsWeb;

  Stream<GoogleSignInCredentials?> get authenticationState =>
      _googleSignIn.authenticationState;

  AuthService() {
    _googleSignIn = GoogleSignIn(
      params: GoogleSignInParams(
        clientId: _clientId,
        clientSecret: _clientSecret,
        scopes: _scopes,
      ),
    );
  }

  Future<void> init() async {
    _isInitializing = true;
    notifyListeners();

    if (!_isSupportedPlatform) {
      _credentials = null;
    } else {
      try {
        _credentials = await _googleSignIn.silentSignIn();
      } catch (e) {
        debugPrint('Auth: silent sign-in failed: $e');
        _credentials = null;
      }
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<GoogleSignInCredentials?> signIn() async {
    if (!_isSupportedPlatform) {
      debugPrint('Auth: signIn not supported on this platform');
      return null;
    }
    try {
      _credentials = await _googleSignIn.signIn();
      notifyListeners();
      return _credentials;
    } catch (e) {
      debugPrint('Auth: signIn failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (!_isSupportedPlatform) return;
    await _googleSignIn.signOut();
    _credentials = null;
    notifyListeners();
  }

  Future<http.Client?> get authenticatedClient async {
    return await _googleSignIn.authenticatedClient;
  }

  Widget? signInButton({VoidCallback? onTap}) {
    try {
      return _googleSignIn.signInButton();
    } catch (e) {
      return null;
    }
  }
}
