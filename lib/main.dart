import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/amal_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/hadith_screen.dart';
import 'screens/tasbih_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DainikAmolApp());
}

class DainikAmolApp extends StatefulWidget {
  const DainikAmolApp({super.key});

  @override
  State<DainikAmolApp> createState() => _DainikAmolAppState();
}

class _DainikAmolAppState extends State<DainikAmolApp> {
  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'bn';
  int _hijriAdjustment = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String theme = prefs.getString('theme_mode') ?? 'system';
      if (theme == 'light') _themeMode = ThemeMode.light;
      else if (theme == 'dark') _themeMode = ThemeMode.dark;
      else _themeMode = ThemeMode.system;

      _language = prefs.getString('app_lang') ?? 'bn';
      _hijriAdjustment = prefs.getInt('hijri_adjust') ?? 0;
    });
  }

  void _updateTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system'));
  }

  void _updateLanguage(String lang) async {
    setState(() => _language = lang);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('app_lang', lang);
  }

  void _updateHijriAdjustment(int adj) async {
    setState(() => _hijriAdjustment = adj);
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('hijri_adjust', adj);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'দৈনন্দিন আমল',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF0D5C3A),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1B8E5B),
        scaffoldBackgroundColor: const Color(0xFF121815),
      ),
      home: MainMasterScreen(
        language: _language,
        hijriAdjustment: _hijriAdjustment,
        themeMode: _themeMode,
        onThemeChanged: _updateTheme,
        onLanguageChanged: _updateLanguage,
        onHijriAdjustmentChanged: _updateHijriAdjustment,
      ),
    );
  }
}

class MainMasterScreen extends StatefulWidget {
  final String language;
  final int hijriAdjustment;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onLanguageChanged;
  final Function(int) onHijriAdjustmentChanged;

  const MainMasterScreen({
    super.key,
    required this.language,
    required this.hijriAdjustment,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onHijriAdjustmentChanged,
  });

  @override
  State<MainMasterScreen> createState() => _MainMasterScreenState();
}

class _MainMasterScreenState extends State<MainMasterScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    bool isBn = widget.language == 'bn';
    final screens = [
      HomeScreen(isBn: isBn, hijriAdj: widget.hijriAdjustment),
      AmalListScreen(isBn: isBn),
      QuranScreen(isBn: isBn),
      HadithScreen(isBn: isBn),
      TasbihScreen(isBn: isBn),
      SettingsScreen(
        isBn: isBn,
        themeMode: widget.themeMode,
        hijriAdj: widget.hijriAdjustment,
        onThemeChanged: widget.onThemeChanged,
        onLanguageChanged: widget.onLanguageChanged,
        onHijriChanged: widget.onHijriAdjustmentChanged,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: isBn ? 'হোম' : 'Home'),
          NavigationDestination(icon: const Icon(Icons.playlist_add_check), selectedIcon: const Icon(Icons.checklist), label: isBn ? 'আমল' : 'Amal'),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: isBn ? 'কুরআন' : 'Quran'),
          NavigationDestination(icon: const Icon(Icons.collections_bookmark_outlined), selectedIcon: const Icon(Icons.collections_bookmark), label: isBn ? 'হাদিস' : 'Hadith'),
          NavigationDestination(icon: const Icon(Icons.touch_app_outlined), selectedIcon: const Icon(Icons.touch_app), label: isBn ? 'জিকির' : 'Tasbih'),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: isBn ? 'সেটিংস' : 'Settings'),
        ],
      ),
    );
  }
}
