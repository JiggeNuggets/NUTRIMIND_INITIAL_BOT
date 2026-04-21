import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Lazily initialized because `google_sign_in_web` requires a web client_id.
  // If it's missing, constructing `GoogleSignIn()` can throw and crash on startup.
  GoogleSignIn? _googleSignIn;
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// `google_sign_in` is only implemented for Android/iOS. Windows/Linux/macOS
  /// must use Firebase [signInWithProvider] or you get MissingPluginException.
  static bool get _useGoogleSignInNativePlugin =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<UserModel?> _finishGoogleUserCredential(UserCredential userCred) async {
    final fbUser = userCred.user;
    if (fbUser == null) return null;
    final uid = fbUser.uid;
    final existing = await _firestoreService.getUser(uid);
    if (existing != null) return existing;
    final user = UserModel(
      uid: uid,
      name: fbUser.displayName ?? 'User',
      email: fbUser.email ?? '',
      photoUrl: fbUser.photoURL,
      location: 'Davao City, Philippines',
    );
    await _firestoreService.createUser(user);
    return user;
  }

  /// Sign up with email and password
  Future<UserModel?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String location = 'Davao City, Philippines',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name);

      final user = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email.trim(),
        photoUrl: credential.user?.photoURL,
        location: location,
      );

      await _firestoreService.createUser(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Sign in with email and password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      final existing = await _firestoreService.getUser(uid);
      if (existing != null) return existing;

      // If Auth succeeded but Firestore profile doesn't exist yet, create it.
      final fbUser = credential.user!;
      final user = UserModel(
        uid: uid,
        name: fbUser.displayName ?? 'User',
        email: fbUser.email ?? email.trim(),
        photoUrl: fbUser.photoURL,
        location: 'Davao City, Philippines',
      );
      await _firestoreService.createUser(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Web: Firebase popup (no `google_sign_in` plugin init).
      if (kIsWeb) {
        final userCred = await _auth.signInWithPopup(GoogleAuthProvider());
        return _finishGoogleUserCredential(userCred);
      }

      // Windows / Linux / macOS: Firebase desktop OAuth (no `google_sign_in` impl on Windows).
      if (!_useGoogleSignInNativePlugin) {
        final userCred =
            await _auth.signInWithProvider(GoogleAuthProvider());
        return _finishGoogleUserCredential(userCred);
      }

      // Android / iOS: `google_sign_in` + credential.
      final googleUser = await (_googleSignIn ??= GoogleSignIn()).signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      return _finishGoogleUserCredential(userCred);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      // Surface the real error to the UI for easier debugging.
      throw Exception('Google Sign-In failed: $e');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (_) {
      // Ignore sign-out issues (e.g., web misconfiguration).
    }
    await _auth.signOut();
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
  