import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/meal_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../services/groq_meal_narrative_service.dart';
import '../../theme/app_theme.dart';

enum _ScannerPhase { camera, preview, analyzing, result, error }

class _FoodAnalysis {
  const _FoodAnalysis({
    required this.dishName,
    required this.calories,
    required this.ingredients,
    required this.comment,
    required this.mealType,
    required this.price,
  });

  final String dishName;
  final int calories;
  final List<String> ingredients;
  final String comment;
  final MealType mealType;
  final double price;
}

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  late final GroqMealNarrativeService _groq;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  bool _cameraLoading = true;
  String? _cameraError;

  _ScannerPhase _phase = _ScannerPhase.camera;
  Uint8List? _imageBytes;
  _FoodAnalysis? _analysis;
  String? _rawAnalysis;
  String? _errorMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _groq = GroqMealNarrativeService();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _groq.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _cameraLoading = true;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameras = const [];
          _cameraLoading = false;
          _cameraError = 'No camera was found on this device.';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameras = cameras;
        _cameraController = controller;
        _cameraLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraError =
            'Camera access is unavailable. Allow camera permission or use Gallery.';
      });
    }
  }

  Future<void> _captureImage() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _pickImage(ImageSource.camera);
      return;
    }

    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      _setPreview(bytes);
    } catch (e) {
      _showSnack('Could not capture photo. Try again or choose Gallery.');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 88,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      _setPreview(bytes);
    } catch (e) {
      final sourceName = source == ImageSource.camera ? 'camera' : 'gallery';
      _showSnack('Could not open $sourceName. Check app permissions.');
    }
  }

  void _setPreview(Uint8List bytes) {
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _analysis = null;
      _rawAnalysis = null;
      _errorMessage = null;
      _phase = _ScannerPhase.preview;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    final current = _cameraController?.description;
    final next = _cameras.firstWhere(
      (camera) => camera.name != current?.name,
      orElse: () => _cameras.first,
    );

    setState(() => _cameraLoading = true);

    try {
      await _cameraController?.dispose();
      final controller = CameraController(
        next,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraLoading = false);
      _showSnack('Could not switch camera.');
    }
  }

  Future<void> _analyzeFood() async {
    final bytes = _imageBytes;
    if (bytes == null) return;

    setState(() {
      _phase = _ScannerPhase.analyzing;
      _errorMessage = null;
    });

    try {
      final result = await _groq.analyzeFoodImageBytes(bytes);
      if (_looksLikeNonFoodResult(result)) {
        _setError(result.trim());
        return;
      }

      final parsed = _parseAnalysis(result);
      if (!mounted) return;
      setState(() {
        _rawAnalysis = result;
        _analysis = parsed;
        _phase = _ScannerPhase.result;
      });
    } catch (e) {
      _setError(_friendlyAnalysisError(e));
    }
  }

  bool _looksLikeNonFoodResult(String text) {
    final lower = text.toLowerCase();
    return lower.contains("couldn't detect any food") ||
        lower.contains('could not detect any food') ||
        lower.contains('does not clearly contain food');
  }

  String _friendlyAnalysisError(Object error) {
    final text = error.toString();
    if (text.contains('GROQ_API_KEY') || text.contains('API key')) {
      return 'Groq API key is missing. Run Flutter with --dart-define=GROQ_API_KEY=your_key.';
    }
    if (text.toLowerCase().contains('permission')) {
      return 'Camera permission was denied. Allow camera access or upload from Gallery.';
    }
    return 'Food analysis failed. Please try another photo.';
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _phase = _ScannerPhase.error;
    });
  }

  _FoodAnalysis _parseAnalysis(String text) {
    final dishName =
        _fieldValue(text, ['Dish Name', 'Detected', 'Food']) ?? 'Food item';
    final calorieText = _fieldValue(
        text, ['Estimated Calories', 'Calories', 'Calorie Estimate']);
    final calories = _parseCalories(calorieText ?? text);
    final ingredientText =
        _fieldValue(text, ['Main Ingredients', 'Ingredients']) ?? '';
    final ingredients = ingredientText
        .split(',')
        .map(_cleanValue)
        .where((item) => item.isNotEmpty)
        .take(6)
        .toList();
    final comment = _fieldValue(
          text,
          ['Nutrition Comment', 'Comment', 'Nutrition Note'],
        ) ??
        _lastReadableLine(text);
    final mealTypeText =
        _fieldValue(text, ['Possible Meal Type', 'Meal Type']) ?? '';
    final priceText = _fieldValue(text, ['Estimated Price', 'Price']);

    return _FoodAnalysis(
      dishName: _cleanValue(dishName),
      calories: calories,
      ingredients: ingredients,
      comment: _cleanValue(comment),
      mealType: _parseMealType(mealTypeText),
      price: _parsePrice(priceText),
    );
  }

  String? _fieldValue(String text, List<String> labels) {
    for (final label in labels) {
      final pattern = RegExp(
        r'^\s*(?:[-*]\s*)?' + RegExp.escape(label) + r'\s*:\s*(.+?)\s*$',
        caseSensitive: false,
        multiLine: true,
      );
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String _cleanValue(String value) {
    return value
        .replaceAll(RegExp(r'[*_`#]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _parseCalories(String value) {
    final match = RegExp(r'(\d{2,5})').firstMatch(value);
    return int.tryParse(match?.group(1) ?? '') ?? 300;
  }

  double _parsePrice(String? value) {
    if (value == null) return 0;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(value);
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }

  MealType _parseMealType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('breakfast')) return MealType.breakfast;
    if (lower.contains('lunch')) return MealType.lunch;
    if (lower.contains('dinner')) return MealType.dinner;
    if (lower.contains('snack')) return MealType.snack;
    return _guessMealType();
  }

  String _lastReadableLine(String text) {
    final lines = text
        .split('\n')
        .map(_cleanValue)
        .where((line) => line.isNotEmpty)
        .where((line) => !line.contains(':'))
        .toList();
    return lines.isEmpty
        ? 'Review the estimate before saving it to your meal log.'
        : lines.last;
  }

  MealType _guessMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return MealType.breakfast;
    if (hour < 14) return MealType.lunch;
    if (hour < 18) return MealType.snack;
    return MealType.dinner;
  }

  Future<void> _saveAnalyzedMeal() async {
    final analysis = _analysis;
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (analysis == null) return;
    if (uid == null || uid.isEmpty) {
      _showSnack('Please sign in before saving meals.');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<MealProvider>().addManualMeal(
            uid: uid,
            name: analysis.dishName,
            type: analysis.mealType,
            price: analysis.price,
            calories: analysis.calories,
            ingredients: analysis.ingredients,
            notes: analysis.comment,
          );
      if (!mounted) return;
      _showSnack('Saved to Meal Log.');
      Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Could not save meal. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openManualLog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualLogSheet(
        initialMealType: _guessMealType(),
        onSave: _saveManualMeal,
      ),
    );
  }

  Future<void> _saveManualMeal(_ManualMealInput input) async {
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid == null || uid.isEmpty) {
      _showSnack('Please sign in before saving meals.');
      return;
    }

    try {
      await context.read<MealProvider>().addManualMeal(
            uid: uid,
            name: input.name,
            type: input.mealType,
            price: input.price,
            calories: input.calories,
            ingredients: input.ingredients,
            notes: input.notes,
          );
    } catch (e) {
      _showSnack('Could not save meal. Please try again.');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    _showSnack('Manual meal saved to Log.');
    Navigator.of(context).pop();
  }

  void _resetScanner() {
    setState(() {
      _imageBytes = null;
      _analysis = null;
      _rawAnalysis = null;
      _errorMessage = null;
      _phase = _ScannerPhase.camera;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Food Scanner',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openManualLog,
            icon: const Icon(Icons.edit_note, color: Colors.white70, size: 20),
            label: const Text(
              'Manual Log',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
      body: switch (_phase) {
        _ScannerPhase.camera => _buildCameraView(),
        _ScannerPhase.preview => _buildPreviewView(),
        _ScannerPhase.analyzing => _buildAnalyzingView(),
        _ScannerPhase.result => _buildResultView(),
        _ScannerPhase.error => _buildErrorView(),
      },
    );
  }

  Widget _buildCameraView() {
    if (_cameraLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Starting camera...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_cameraError != null ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return _buildCameraFallback();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
        Container(color: Colors.black.withValues(alpha: 0.12)),
        Center(
          child: Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryGreen, width: 2.5),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                kIsWeb
                    ? 'Allow browser camera access, then point at your food'
                    : 'Point camera at your food',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _roundAction(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              GestureDetector(
                onTap: _captureImage,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              _roundAction(
                icon: _cameras.length > 1
                    ? Icons.flip_camera_ios_outlined
                    : Icons.edit_note,
                label: _cameras.length > 1 ? 'Flip' : 'Manual',
                onTap: _cameras.length > 1 ? _switchCamera : _openManualLog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraFallback() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                color: AppTheme.primaryGreen,
                size: 46,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Scan Your Food',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _cameraError ??
                  'Use Gallery or Manual Log while camera preview is unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            _wideButton(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 12),
            _wideButton(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              onPressed: () => _pickImage(ImageSource.camera),
              outlined: true,
            ),
            const SizedBox(height: 12),
            _wideButton(
              icon: Icons.edit_note,
              label: 'Manual Log',
              onPressed: _openManualLog,
              outlined: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewView() {
    final bytes = _imageBytes;
    if (bytes == null) return _buildCameraView();

    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
          child: Column(
            children: [
              const Text(
                'Review your food photo before analysis.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              _wideButton(
                icon: Icons.auto_awesome,
                label: 'Analyze Food',
                onPressed: _analyzeFood,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _wideButton(
                      icon: Icons.refresh,
                      label: 'Retake',
                      onPressed: _resetScanner,
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _wideButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onPressed: () => _pickImage(ImageSource.gallery),
                      outlined: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingView() {
    final bytes = _imageBytes;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null) Image.memory(bytes, fit: BoxFit.contain),
        Container(
          color: Colors.black.withValues(alpha: 0.68),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 3,
              ),
              SizedBox(height: 18),
              Text(
                'Analyzing your food...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'NutriMind AI is estimating nutrition details',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final analysis = _analysis;
    final bytes = _imageBytes;
    if (analysis == null) return _buildErrorView();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bytes != null)
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI ANALYSIS',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        analysis.dishName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _resultChip(
                            Icons.local_fire_department,
                            '${analysis.calories} kcal',
                            AppTheme.orangeAccent,
                          ),
                          _resultChip(
                            Icons.restaurant_menu,
                            analysis.mealType.name,
                            AppTheme.primaryGreen,
                          ),
                          if (analysis.price > 0)
                            _resultChip(
                              Icons.payments_outlined,
                              'PHP ${analysis.price.toStringAsFixed(0)}',
                              AppTheme.infoBlue,
                            ),
                        ],
                      ),
                      if (analysis.ingredients.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Ingredients',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: analysis.ingredients
                              .map(
                                (ingredient) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryGreen
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    ingredient,
                                    style: const TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Nutrition Comment',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        analysis.comment,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      if (_rawAnalysis != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Review AI estimates before saving.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _wideButton(
                  icon: Icons.save_outlined,
                  label: _saving ? 'Saving...' : 'Save to Meal Log',
                  onPressed: _saving ? null : _saveAnalyzedMeal,
                ),
                const SizedBox(height: 10),
                _wideButton(
                  icon: Icons.document_scanner_outlined,
                  label: 'Scan Another',
                  onPressed: _resetScanner,
                  outlined: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppTheme.errorRed,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Analysis Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            _wideButton(
              icon: Icons.refresh,
              label: _imageBytes == null ? 'Back to Camera' : 'Try Again',
              onPressed: _imageBytes == null ? _resetScanner : _analyzeFood,
            ),
            const SizedBox(height: 10),
            _wideButton(
              icon: Icons.photo_library_outlined,
              label: 'Choose Another Photo',
              onPressed: () => _pickImage(ImageSource.gallery),
              outlined: true,
            ),
            const SizedBox(height: 10),
            _wideButton(
              icon: Icons.edit_note,
              label: 'Manual Log',
              onPressed: _openManualLog,
              outlined: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _wideButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool outlined = false,
  }) {
    const minimumSize = Size(double.infinity, 52);
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white30),
          minimumSize: minimumSize,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.5),
        minimumSize: minimumSize,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _resultChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualMealInput {
  const _ManualMealInput({
    required this.name,
    required this.mealType,
    required this.calories,
    required this.price,
    required this.ingredients,
    required this.notes,
  });

  final String name;
  final MealType mealType;
  final int calories;
  final double price;
  final List<String> ingredients;
  final String? notes;
}

class _ManualLogSheet extends StatefulWidget {
  const _ManualLogSheet({
    required this.initialMealType,
    required this.onSave,
  });

  final MealType initialMealType;
  final Future<void> Function(_ManualMealInput input) onSave;

  @override
  State<_ManualLogSheet> createState() => _ManualLogSheetState();
}

class _ManualLogSheetState extends State<_ManualLogSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _priceController =
      TextEditingController(text: '0');
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late MealType _mealType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _priceController.dispose();
    _ingredientsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final input = _ManualMealInput(
        name: _nameController.text.trim(),
        mealType: _mealType,
        calories: int.parse(_caloriesController.text.trim()),
        price: double.tryParse(_priceController.text.trim()) ?? 0,
        ingredients: _ingredientsController.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      await widget.onSave(input);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 22,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Manual Log',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppTheme.textMid),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _label('Food name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Example: Chicken adobo',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _label('Meal type'),
                const SizedBox(height: 6),
                DropdownButtonFormField<MealType>(
                  initialValue: _mealType,
                  decoration: const InputDecoration(),
                  items: MealType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_mealTypeLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _mealType = value);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Calories'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _caloriesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '350'),
                            validator: (value) {
                              final calories =
                                  int.tryParse(value?.trim() ?? '');
                              if (calories == null || calories <= 0) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Price'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(hintText: '0'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Ingredients'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _ingredientsController,
                  decoration: const InputDecoration(
                    hintText: 'rice, chicken, soy sauce',
                  ),
                ),
                const SizedBox(height: 14),
                _label('Notes'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Optional serving size, brand, or nutrition note',
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Saving...' : 'Save to Meal Log'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textDark,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _mealTypeLabel(MealType type) {
    return type.name[0].toUpperCase() + type.name.substring(1);
  }
}
