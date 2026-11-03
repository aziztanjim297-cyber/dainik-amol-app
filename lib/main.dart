import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/amal_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/hadith_screen.dart';
import 'screens/tasbih_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('bn', null);
  await NotificationService.instance.initialize();
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

  void _updateLanguage(String lang) async {
    setState(() => _language = lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', lang);
  }

  void _updateMadhab(String m) async {
    setState(() => _madhab = m);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('madhab', m);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _language == 'bn' ? 'দৈনন্দিন আমল' : 'Dainik Amal',
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
        onLanguageChanged: _updateLanguage,
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
  final Function(String) onLanguageChanged;
  final Function(String) onMadhabChanged;

  const MainMasterScreen({
    super.key,
    required this.language,
    required this.madhab,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onMadhabChanged,
  });

  @override
  State<MainMasterScreen> createState() => _MainMasterScreenState();
}

class _MainMasterScreenState extends State<MainMasterScreen> {
  int _currentIndex = 0;
  int _locationVersion = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isBn = widget.language == 'bn';
    final screens = [
      HomeScreen(key: ValueKey(_locationVersion), isBn: isBn, madhab: widget.madhab),
      AmalListScreen(isBn: isBn, madhab: widget.madhab),
      QuranScreen(isBn: isBn),
      HadithScreen(isBn: isBn),
      TasbihScreen(isBn: isBn),
      SettingsScreen(
        isBn: isBn,
        themeMode: widget.themeMode,
        madhab: widget.madhab,
        onThemeChanged: widget.onThemeChanged,
        onLanguageChanged: widget.onLanguageChanged,
        onMadhabChanged: widget.onMadhabChanged,
        onLocationChanged: () => setState(() => _locationVersion++),
      ),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (idx) {
          setState(() => _currentIndex = idx);
        },
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          _pageController.animateToPage(
            idx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: isBn ? 'হোম' : 'Home'),
          NavigationDestination(icon: const Icon(Icons.checklist), label: isBn ? 'আমল' : 'Amal'),
          NavigationDestination(icon: const Icon(Icons.menu_book), label: isBn ? 'কুরআন' : 'Quran'),
          NavigationDestination(icon: const Icon(Icons.bookmark), label: isBn ? 'হাদিস' : 'Hadith'),
          NavigationDestination(icon: const Icon(Icons.touch_app), label: isBn ? 'জিকির' : 'Tasbih'),
          NavigationDestination(icon: const Icon(Icons.settings), label: isBn ? 'সেটিংস' : 'Settings'),
        ],
      ),
    );
  }
}
