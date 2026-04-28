/// Returns 0 when the value is null, NaN, or infinite — Firestore rejects
/// non-finite doubles with an internal assertion error. Use this around
/// any numeric value that flows into a Firestore write (price, calories,
/// BMI, etc.).
double safeDouble(double? v) {
  if (v == null || v.isNaN || v.isInfinite) return 0;
  return v;
}
