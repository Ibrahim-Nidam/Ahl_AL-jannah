/// Central feature switches for the Ahl Jannah app.
///
/// ⚠️ These are compile-time constants: changing a value takes effect only
/// after rebuilding the app.
///
/// Tajweed (rule colouring of the mushaf) is shipped in a hidden state.
/// To bring it back for a riwaya, set that riwaya's switch to `true` and
/// rebuild. When a switch is `false` nothing tajweed-related is shown — no
/// colouring in the mushaf and no toggle in the reader settings sheet.
/// Re-enabling a riwaya restores the reader's previously saved preference,
/// so the feature "reappears with its settings".
abstract final class FeatureFlags {
  /// Show tajweed colouring and its settings toggle when reading the Hafs
  /// riwaya.
  static const bool tajweedHafsEnabled = false;

  /// Show tajweed colouring and its settings toggle when reading the Warsh
  /// riwaya.
  static const bool tajweedWarshEnabled = false;
}
