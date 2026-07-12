import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class AppAppearanceProvider extends ChangeNotifier {
  final DatabaseService _database;

  AppPalette _palette = AppPalette.board;
  ThemeMode _themeMode = ThemeMode.system;

  AppAppearanceProvider({DatabaseService? database})
    : _database = database ?? DatabaseService();

  AppPalette get palette => _palette;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    try {
      final paletteName = await _database.getSetting('appearance_palette');
      final modeName = await _database.getSetting('appearance_mode');
      _palette = AppPalette.values.firstWhere(
        (value) => value.name == paletteName,
        orElse: () => AppPalette.board,
      );
      _themeMode = ThemeMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    } catch (error) {
      debugPrint('Darstellung konnte nicht geladen werden: $error');
    }
  }

  Future<void> setPalette(AppPalette value) async {
    if (_palette == value) return;
    _palette = value;
    notifyListeners();
    try {
      await _database.setSetting('appearance_palette', value.name);
    } catch (error) {
      debugPrint('Farbstimmung konnte nicht gespeichert werden: $error');
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    try {
      await _database.setSetting('appearance_mode', value.name);
    } catch (error) {
      debugPrint('Helligkeitsmodus konnte nicht gespeichert werden: $error');
    }
  }
}
