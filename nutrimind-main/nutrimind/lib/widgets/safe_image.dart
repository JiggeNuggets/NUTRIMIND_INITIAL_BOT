import 'package:flutter/material.dart';
import '../services/food_image_resolver.dart';
import '../theme/app_theme.dart';

/// CircleAvatar that never passes an empty string to NetworkImage.
/// Falls back to the first letter of [displayName] on a softGreen background.
class SafeAvatar extends StatelessWidget {
  const SafeAvatar({
    super.key,
    required this.radius,
    this.photoUrl,
    required this.displayName,
    this.backgroundColor,
    this.textStyle,
  });

  final double radius;
  final String? photoUrl;
  final String displayName;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  String? get _safePhotoUrl {
    final url = photoUrl?.trim();
    return url == null || url.isEmpty ? null : url;
  }

  bool get _valid => _safePhotoUrl != null;
  String get _initial =>
      displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.softGreen,
      backgroundImage: _valid ? NetworkImage(_safePhotoUrl!) : null,
      child: _valid
          ? null
          : Text(
              _initial,
              style: textStyle ??
                  TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: radius * 0.7,
                  ),
            ),
    );
  }
}

/// Shows a network image with an icon-gradient fallback.
/// Never calls NetworkImage with a null or empty URL.
///
/// When [mealName] is provided, tries to resolve a bundled local asset
/// via [FoodImageResolver] before falling back to [imageUrl] or the
/// placeholder icon.
class SafeFoodImage extends StatelessWidget {
  const SafeFoodImage({
    super.key,
    this.imageUrl,
    this.mealName,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.restaurant,
    this.placeholderColor,
  });

  final String? imageUrl;
  final String? mealName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;
  final Color? placeholderColor;

  String? get _safeImageUrl {
    final url = imageUrl?.trim();
    return url == null || url.isEmpty ? null : url;
  }

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(12);

    // 1. Try local asset from meal name
    final localAsset = FoodImageResolver.resolve(mealName);
    if (localAsset != null) {
      return ClipRRect(
        borderRadius: br,
        child: Image.asset(
          localAsset,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _tryNetwork(br),
        ),
      );
    }

    // 2. Fall back to network image or placeholder
    return _tryNetwork(br);
  }

  Widget _tryNetwork(BorderRadius br) {
    final url = _safeImageUrl;
    if (url != null) {
      return ClipRRect(
        borderRadius: br,
        child: Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _placeholder(br),
        ),
      );
    }
    return _placeholder(br);
  }

  Widget _placeholder(BorderRadius br) {
    final color = placeholderColor ?? AppTheme.primaryGreen;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child:
          Icon(placeholderIcon, color: color.withValues(alpha: 0.4), size: 28),
    );
  }
}
