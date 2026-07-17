import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A font family offered for Bible reading.
class ReaderFont {
  /// Flutter font family name (null = system default).
  final String? family;
  final String label;

  const ReaderFont(this.family, this.label);
}

/// The user's Bible-text preferences. They apply only to the verse text in
/// the reader (and the settings sample) — never to the rest of the UI.
class ReaderSettings extends ChangeNotifier {
  static const _familyKey = 'reader_font_family';
  static const _sizeKey = 'reader_font_size';

  static const double defaultSize = 17;
  static const double minSize = 14;
  static const double maxSize = 26;

  /// Bundled, offline font choices (assets/fonts/, see tool/fetch_fonts.ps1).
  static const List<ReaderFont> fonts = [
    ReaderFont(null, 'Default'),
    ReaderFont('Lora', 'Lora'),
    ReaderFont('Merriweather', 'Merriweather'),
    ReaderFont('EB Garamond', 'EB Garamond'),
    ReaderFont('Open Sans', 'Open Sans'),
  ];

  String? _fontFamily;
  double _fontSize = defaultSize;

  String? get fontFamily => _fontFamily;
  double get fontSize => _fontSize;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(_familyKey);
    _fontSize = prefs.getDouble(_sizeKey) ?? defaultSize;
    notifyListeners();
  }

  Future<void> setFontFamily(String? family) async {
    _fontFamily = family;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (family == null) {
      await prefs.remove(_familyKey);
    } else {
      await prefs.setString(_familyKey, family);
    }
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sizeKey, size);
  }

  Future<void> reset() async {
    await setFontFamily(null);
    await setFontSize(defaultSize);
  }
}
