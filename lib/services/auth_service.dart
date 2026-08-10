import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1041465650841-h58q7rdv339ln2kbndl3du7emauj8lqi.apps.googleusercontent.com',
    scopes: ['email'],
  );

  User? _user;
  bool _isInitializing = true;
  String? _accessToken;
  String? _lastError;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isInitializing => _isInitializing;
  String? get accessToken => _accessToken;
  String? get lastError => _lastError;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Create an authenticated HTTP client using the stored access token.
  http.Client? get authenticatedClient {
    if (_accessToken == null) return null;
    return _AuthHttpClient(_accessToken!);
  }

  AuthService() {
    // google_sign_in 6.x doesn't need explicit initialization
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
    _lastError = null;
    try {
      if (kIsWeb) {
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(authProvider);
        _user = userCredential.user;
        notifyListeners();
        return _user;
      } else {
        final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
        if (gUser == null) {
          _lastError = 'Login dibatalkan oleh pengguna';
          notifyListeners();
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
        _lastError = null;
        notifyListeners();
        return _user;
      }
    } catch (e) {
      debugPrint('Auth: signIn failed: $e');
      _lastError = 'Login gagal: $e';
      notifyListeners();
      return null;
    }
  }

  /// Sign in with Email/Password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint('Auth: email signIn failed: $e');
      return null;
    }
  }

  /// Register with Email/Password
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint('Auth: email register failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
      _user = null;
      _accessToken = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Auth: signOut failed: $e');
    }
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
