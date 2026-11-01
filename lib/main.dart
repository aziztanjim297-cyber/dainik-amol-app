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
  String _madhab = 'hanafi';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String t = prefs.getString('theme_mode') ?? 'system';
      _themeMode = t == 'light' ? ThemeMode.light : (t == 'dark' ? ThemeMode.dark : ThemeMode.system);
      _language = prefs.getString('app_lang') ?? 'bn';
      _madhab = prefs.getString('madhab') ?? 'hanafi';
    });
  }

  void _updateTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system'));
  }

  void _updateMadhab(String m) async {
    setState(() => _madhab = m);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('madhab', m);
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
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1B8E5B),
        scaffoldBackgroundColor: const Color(0xFF121815),
      ),
      home: MainMasterScreen(
        language: _language,
        madhab: _madhab,
        themeMode: _themeMode,
        onThemeChanged: _updateTheme,
        onMadhabChanged: _updateMadhab,
      ),
    );
  }
}

class MainMasterScreen extends StatefulWidget {
  final String language;
  final String madhab;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onMadhabChanged;

  const MainMasterScreen({
    super.key,
    required this.language,
    required this.madhab,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onMadhabChanged,
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
      HomeScreen(isBn: isBn, madhab: widget.madhab),
      AmalListScreen(isBn: isBn, madhab: widget.madhab),
      QuranScreen(isBn: isBn),
      HadithScreen(isBn: isBn),
      TasbihScreen(isBn: isBn),
      SettingsScreen(
        isBn: isBn,
        themeMode: widget.themeMode,
        madhab: widget.madhab,
        onThemeChanged: widget.onThemeChanged,
        onLanguageChanged: (_) {},
        onMadhabChanged: widget.onMadhabChanged,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'হোম'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'আমল'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'কুরআন'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'হাদিস'),
          NavigationDestination(icon: Icon(Icons.touch_app), label: 'জিকির'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'সেটিংস'),
        ],
      ),
    );
  }
}
