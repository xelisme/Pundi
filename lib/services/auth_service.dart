import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  bool _isInitializing = true;
  String? _accessToken;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isInitializing => _isInitializing;
  String? get accessToken => _accessToken;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Create an authenticated HTTP client using the stored access token.
  /// Returns null if not signed in.
  http.Client? get authenticatedClient {
    if (_accessToken == null) return null;
    return _AuthHttpClient(_accessToken!);
  }

  Future<void> init() async {
    _isInitializing = true;
    notifyListeners();

    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });

    _user = _auth.currentUser;
    _isInitializing = false;
    notifyListeners();
  }

  Future<User?> signIn() async {
    try {
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
      if (gUser == null) {
        debugPrint('Auth: Google Sign-In cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // Store access token for Drive API
      _accessToken = gAuth.accessToken;

      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint('Auth: signIn failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _user = null;
    _accessToken = null;
    notifyListeners();
  }
}

/// Simple HTTP client that adds Authorization header to every request.
class _AuthHttpClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  _AuthHttpClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
}
