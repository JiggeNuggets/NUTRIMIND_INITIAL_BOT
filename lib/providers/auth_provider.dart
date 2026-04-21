import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _userModel;
  String? _error;
  bool _loading = false;
  bool _isNewUser = false;

  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  String? get error => _error;
  bool get loading => _loading;
  bool get isNewUser => _isNewUser;
  User? get firebaseUser => _authService.currentUser;

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _userModel = null;
    } else {
      final existing = await _firestoreService.getUser(user.uid);
      if (existing != null) {
        _userModel = existing;
      } else {
        // Auth is valid but Firestore profile is missing (first login / failed seed).
        // Create a minimal user profile so the app can proceed.
        try {
          final newUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? 'User',
            email: user.email ?? '',
            photoUrl: user.photoURL,
            location: 'Davao City, Philippines',
          );
          await _firestoreService.createUser(newUser);
          _userModel = newUser;
        } catch (e) {
          // If Firestore is still blocked (rules/config), keep auth state but surface error.
          _userModel = null;
          _error = e.toString();
        }
      }
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String location = 'Davao City, Philippines',
  }) async {
    _setLoading(true);
    try {
      _userModel = await _authService.signUpWithEmail(
        name: name, email: email, password: password, location: location,
      );
      _isNewUser = true;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      _userModel = await _authService.signInWithEmail(
        email: email, password: password,
      );
      _isNewUser = false;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        _setLoading(false);
        return false;
      }
      _userModel = user;
      _isNewUser = false;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _authService.resetPassword(email);
      _setLoading(false);
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userModel = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> updateOnboarding({
    required String goal,
    required String gender,
    required double height,
    required double weight,
    required int age,
  }) async {
    if (_userModel == null) return;
    final updated = _userModel!.copyWith(
      goal: goal, gender: gender, height: height, weight: weight, age: age,
    );
    await _firestoreService.updateUserProfile(updated);
    _userModel = updated;
    notifyListeners();
  }

  Future<void> updateSettings({
    double? dailyBudget,
    bool? allowNonLocal,
    double? budgetBuffer,
  }) async {
    if (_userModel == null) return;
    final data = <String, dynamic>{};
    if (dailyBudget != null) data['dailyBudget'] = dailyBudget;
    if (allowNonLocal != null) data['allowNonLocal'] = allowNonLocal;
    if (budgetBuffer != null) data['budgetBuffer'] = budgetBuffer;
    await _firestoreService.updateUser(_userModel!.uid, data);
    _userModel = _userModel!.copyWith(
      dailyBudget: dailyBudget,
      allowNonLocal: allowNonLocal,
      budgetBuffer: budgetBuffer,
    );
    notifyListeners();
  }

  Future<void> updateProfilePhoto(String photoUrl) async {
    if (_userModel == null) return;
    await _firestoreService.updateUser(_userModel!.uid, {'photoUrl': photoUrl});
    _userModel = _userModel!.copyWith(photoUrl: photoUrl);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
