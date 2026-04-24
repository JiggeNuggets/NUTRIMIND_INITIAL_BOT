import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/recipe_model.dart';

class RecipeApiConfig {
  RecipeApiConfig._();

  static const String _overrideBaseUrl =
      String.fromEnvironment('RECIPE_API_BASE_URL');
  static const bool _allowLocalApiInRelease = bool.fromEnvironment(
    'ALLOW_LOCAL_RECIPE_API_IN_RELEASE',
    defaultValue: false,
  );

  static bool get hasConfiguredBaseUrl => _overrideBaseUrl.trim().isNotEmpty;

  static bool get usesLocalDevelopmentDefault => !hasConfiguredBaseUrl;

  static String? get configurationError {
    if (kReleaseMode &&
        usesLocalDevelopmentDefault &&
        !_allowLocalApiInRelease) {
      return 'RECIPE_API_BASE_URL is required for production builds. '
          'Recipe Browser will not use localhost or sample recipe APIs silently.';
    }
    return null;
  }

  static String get disclosure {
    if (configurationError != null) return configurationError!;
    if (usesLocalDevelopmentDefault) {
      return 'Prototype Recipe API: using local development URL and sample backend data when available.';
    }
    return 'Recipe API configured by RECIPE_API_BASE_URL. Verify backend data source before production release.';
  }

  static String get baseUrl {
    if (_overrideBaseUrl.trim().isNotEmpty) {
      return _normalizeBaseUrl(_overrideBaseUrl);
    }

    if (kIsWeb) return 'http://localhost:8000';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8000';
    }
  }

  static String _normalizeBaseUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'\/+$'), '');
}

class RecipeApiException implements Exception {
  const RecipeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecipeApiService {
  RecipeApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _configurationError =
            baseUrl == null ? RecipeApiConfig.configurationError : null,
        _baseUrl = RecipeApiConfig._normalizeBaseUrl(
          baseUrl ?? RecipeApiConfig.baseUrl,
        );

  final http.Client _client;
  final bool _ownsClient;
  final String? _configurationError;
  final String _baseUrl;

  String get baseUrl => _baseUrl;
  String? get configurationError => _configurationError;
  bool get hasConfigurationError => _configurationError != null;
  String get disclosure => _configurationError ?? RecipeApiConfig.disclosure;

  String disclosureFromHealth(Map<String, dynamic> health) {
    final warning = health['data_warning'];
    if (warning is String && warning.trim().isNotEmpty) {
      return warning.trim();
    }
    final mode = health['data_mode'];
    if (mode is String && mode.trim().isNotEmpty) {
      return 'Recipe backend data mode: ${mode.trim()}.';
    }
    return disclosure;
  }

  Future<List<RecipeModel>> fetchRecipes({
    String query = '',
    int limit = 50,
    String? mealType,
  }) async {
    final trimmedQuery = query.trim();
    final normalizedMealType = mealType?.trim();
    final path = trimmedQuery.isEmpty ? 'recipes' : 'recipes/search';
    final uri = _buildUri(
      path,
      queryParameters: {
        if (trimmedQuery.isNotEmpty) 'q': trimmedQuery,
        'limit': '$limit',
        if (normalizedMealType != null && normalizedMealType.isNotEmpty)
          'meal_type': normalizedMealType,
      },
    );

    final decoded = await _getJson(uri);
    if (decoded is! List) {
      throw const RecipeApiException(
        'Recipe API returned an unexpected list response.',
      );
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RecipeModel.fromApiJson)
        .toList(growable: false);
  }

  Future<RecipeModel> fetchRecipeById(String recipeId) async {
    final trimmedId = recipeId.trim();
    if (trimmedId.isEmpty) {
      throw const RecipeApiException('Recipe id is required.');
    }

    final uri = _buildUri('recipes/$trimmedId');
    final decoded = await _getJson(uri);
    if (decoded is! Map<String, dynamic>) {
      throw const RecipeApiException(
        'Recipe API returned an unexpected detail response.',
      );
    }
    return RecipeModel.fromApiJson(decoded);
  }

  Future<Map<String, dynamic>> healthCheck() async {
    final uri = _buildUri('health');
    final decoded = await _getJson(uri);
    if (decoded is! Map<String, dynamic>) {
      throw const RecipeApiException(
        'Recipe API returned an unexpected health response.',
      );
    }
    return decoded;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }

  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final base = Uri.parse('$_baseUrl/');
    return base.resolve(path).replace(
          queryParameters: queryParameters == null || queryParameters.isEmpty
              ? null
              : queryParameters,
        );
  }

  Future<dynamic> _getJson(Uri uri) async {
    final configurationError = _configurationError;
    if (configurationError != null) {
      throw RecipeApiException(configurationError);
    }

    http.Response response;
    try {
      response = await _client.get(uri, headers: const {
        'Accept': 'application/json',
      });
    } catch (_) {
      throw RecipeApiException(
        'Could not reach the recipe API at $_baseUrl. '
        'Make sure the backend is running.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecipeApiException(_readErrorMessage(response));
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw const RecipeApiException(
        'Recipe API returned invalid JSON.',
      );
    }
  }

  String _readErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    } catch (_) {
      // Fall back to a simple HTTP error below.
    }

    return 'Recipe API error (${response.statusCode}).';
  }
}
