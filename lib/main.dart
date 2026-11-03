import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'services/background_task_service.dart';
import 'screens/home_screen.dart';
import 'screens/amal_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/hadith_screen.dart';
import 'screens/tasbih_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('bn', null);
  runApp(const DainikAmolApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await initializeBackgroundReminderRefresh();
    } catch (e) {
      debugPrint('Background reminder initialization failed: $e');
    }
  });
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

  Future<void> _updateMadhab(String m) async {
    setState(() => _madhab = m);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('madhab', m);

    final lat = prefs.getDouble('location_lat');
    final lon = prefs.getDouble('location_lon');

    if (lat != null && lon != null) {
      await NotificationService.instance.scheduleAmalReminders(
        coords: Coordinates(lat, lon),
        madhab: m,
      );
    }
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
  static const MethodChannel _alarmChannel = MethodChannel('dainik_amol/alarm');
  Timer? _alarmStatusTimer;
  bool _showingAlarmDialog = false;

  @override
  void initState() {
    super.initState();
    _checkAlarmStatus();
    _alarmStatusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkAlarmStatus(),
    );
  }

  Future<void> _checkAlarmStatus() async {
    if (!mounted) return;
    try {
      final active =
          await _alarmChannel.invokeMethod<bool>('isAlarmRinging') ?? false;
      if (!mounted) return;

      if (active && !_showingAlarmDialog) {
        _showingAlarmDialog = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.alarm_on, color: Colors.deepOrange, size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('নামাজের অ্যালার্ম বাজছে!')),
              ],
            ),
            content: const Text(
              'নামাজের সময় হয়েছে। অ্যালার্ম বন্ধ করতে নিচের বাটনে চাপ দিন।',
            ),
            actions: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop),
                label: const Text('অ্যালার্ম বন্ধ করুন'),
                onPressed: () async {
                  try {
                    await _alarmChannel.invokeMethod<void>('stopAlarm');
                  } catch (e) {
                    debugPrint('Alarm stop failed: $e');
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          ),
        ).whenComplete(() {
          _showingAlarmDialog = false;
        });
      } else if (!active && _showingAlarmDialog) {
        Navigator.of(context, rootNavigator: true).maybePop();
        _showingAlarmDialog = false;
      }
    } catch (e) {
      debugPrint('Alarm status check failed: $e');
    }
  }

  @override
  void dispose() {
    _alarmStatusTimer?.cancel();
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
          _pageController.jumpToPage(idx);
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
