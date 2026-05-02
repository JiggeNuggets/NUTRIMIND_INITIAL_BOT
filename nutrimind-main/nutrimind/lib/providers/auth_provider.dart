import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, profileLoadFailed }

const String _profileLoadErrorMessage =
    'We could not load your profile. Please check your connection and try again.';
const Duration _profileLoadTimeout = Duration(seconds: 10);

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _userModel;
  String? _error;
  bool _loading = false;
  bool _isNewUser = false;
  StreamSubscription<User?>? _authSubscription;
  int _authChangeVersion = 0;

  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  String? get error => _error;
  bool get loading => _loading;
  bool get isNewUser => _isNewUser;
  User? get firebaseUser => _authService.currentUser;

  AuthProvider() {
    _authSubscription = _authService.authStateChanges.listen(_onAuthChanged);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onAuthChanged(User? user) async {
    final version = ++_authChangeVersion;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _userModel = null;
      _error = null;
      _loading = false;
      _isNewUser = false;
      notifyListeners();
      return;
    }

    _status = AuthStatus.unknown;
    _userModel = null;
    _error = null;
    _loading = false;
    notifyListeners();
    await _resolveSignedInUser(user, version);
  }

  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String location = 'Davao City, Philippines',
  }) async {
    _error = null;
    _setLoading(true);
    try {
      _userModel = await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
        location: location,
      );
      _status = AuthStatus.authenticated;
      _error = null;
      _isNewUser = true;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _messageForError(e);
      _setLoading(false);
      return firebaseUser != null;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _error = null;
    _setLoading(true);
    try {
      _userModel = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _status = AuthStatus.authenticated;
      _error = null;
      _isNewUser = false;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _messageForError(e);
      _setLoading(false);
      return firebaseUser != null;
    }
  }

  Future<bool> signInWithGoogle() async {
    _error = null;
    _setLoading(true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        _setLoading(false);
        return false;
      }
      _userModel = user;
      _status = AuthStatus.authenticated;
      _error = null;
      _isNewUser = false;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _messageForError(e);
      _setLoading(false);
      return firebaseUser != null;
    }
  }

  Future<bool> resetPassword(String email) async {
    _error = null;
    _setLoading(true);
    try {
      await _authService.resetPassword(email);
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _messageForError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _authChangeVersion++;
    await _authService.signOut();
    _userModel = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    _loading = false;
    _isNewUser = false;
    notifyListeners();
  }

  Future<void> retryProfileLoad() async {
    final user = firebaseUser;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _userModel = null;
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }

    final version = ++_authChangeVersion;
    _status = AuthStatus.unknown;
    _userModel = null;
    _error = null;
    _loading = false;
    notifyListeners();
    await _resolveSignedInUser(user, version);
  }

  Future<void> updateOnboarding({
    required String goal,
    required String gender,
    required double height,
    required double weight,
    required int age,
  }) async {
    if (_userModel == null) return;
    final bmi = UserModel.computeBmi(heightCm: height, weightKg: weight);
    final updated = _userModel!.copyWith(
      goal: goal,
      gender: gender,
      height: height,
      weight: weight,
      age: age,
      bmi: bmi,
      bmiCategory: UserModel.computeBmiCategory(bmi),
      profileCompleted: true,
      updatedAt: DateTime.now(),
    );
    await _firestoreService.updateUserProfile(updated);
    _userModel = updated;
    notifyListeners();
  }

  Future<void> updateProfileSetup({
    required String goal,
    required String gender,
    required double height,
    required double weight,
    required int age,
    required double dailyBudget,
  }) async {
    if (_userModel == null) return;
    final bmi = UserModel.computeBmi(heightCm: height, weightKg: weight);
    final updated = _userModel!.copyWith(
      goal: goal,
      gender: gender,
      height: height,
      weight: weight,
      age: age,
      bmi: bmi,
      bmiCategory: UserModel.computeBmiCategory(bmi),
      dailyBudget: dailyBudget,
      profileCompleted: true,
      budgetConfigured: true,
      updatedAt: DateTime.now(),
    );
    await _firestoreService.updateUserProfile(updated);
    _userModel = updated;
    notifyListeners();
  }

  Future<void> updateProfileDetails({
    String? name,
    String? location,
    String? goal,
    String? gender,
    double? height,
    double? weight,
    int? age,
    double? dailyBudget,
  }) async {
    if (_userModel == null) return;
    final newHeight = height ?? _userModel!.height;
    final newWeight = weight ?? _userModel!.weight;
    final bmi = UserModel.computeBmi(heightCm: newHeight, weightKg: newWeight);
    final updated = _userModel!.copyWith(
      name: name,
      location: location,
      goal: goal,
      gender: gender,
      height: height,
      weight: weight,
      age: age,
      bmi: bmi,
      bmiCategory: UserModel.computeBmiCategory(bmi),
      dailyBudget: dailyBudget,
      budgetConfigured:
          dailyBudget != null ? true : _userModel!.budgetConfigured,
      updatedAt: DateTime.now(),
    );
    await _firestoreService.updateUserProfile(updated);
    _userModel = updated;
    notifyListeners();
  }

  Future<void> updateGoal(String goal) async {
    if (_userModel == null) return;
    await _firestoreService.updateUser(_userModel!.uid, {'goal': goal});
    _userModel = _userModel!.copyWith(goal: goal);
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
    if (dailyBudget != null) data['budgetConfigured'] = true;
    await _firestoreService.updateUser(_userModel!.uid, data);
    _userModel = _userModel!.copyWith(
      dailyBudget: dailyBudget,
      allowNonLocal: allowNonLocal,
      budgetBuffer: budgetBuffer,
      budgetConfigured:
          dailyBudget != null ? true : _userModel!.budgetConfigured,
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

  Future<void> _resolveSignedInUser(User user, int version) async {
    try {
      if (user.uid.trim().isEmpty) {
        throw StateError('Firebase user had an empty uid during profile load.');
      }

      final existing = await _firestoreService
          .getUser(user.uid)
          .timeout(_profileLoadTimeout);
      if (!_isCurrentAuthChange(version, user.uid)) return;

      if (existing != null) {
        if (existing.uid.trim().isEmpty) {
          throw StateError('Loaded profile had an empty uid.');
        }
        _userModel = existing;
      } else {
        final newUser = UserModel(
          uid: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          location: 'Davao City, Philippines',
        );
        await _firestoreService
            .createUser(newUser)
            .timeout(_profileLoadTimeout);
        if (!_isCurrentAuthChange(version, user.uid)) return;
        _userModel = newUser;
      }

      _status = AuthStatus.authenticated;
      _error = null;
      _loading = false;
      notifyListeners();
    } catch (e, st) {
      if (!_isCurrentAuthChange(version, user.uid)) return;
      developer.log(
        'Failed to load signed-in user profile',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      _userModel = null;
      _status = AuthStatus.profileLoadFailed;
      _error = _profileLoadErrorMessage;
      _loading = false;
      notifyListeners();
    }
  }

  bool _isCurrentAuthChange(int version, String uid) {
    return version == _authChangeVersion &&
        _authService.currentUser?.uid == uid &&
        _authService.currentUser != null;
  }

  String _messageForError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
