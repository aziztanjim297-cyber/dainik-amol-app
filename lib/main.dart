import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DainikAmolApp());
}

class DainikAmolApp extends StatelessWidget {
  const DainikAmolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'দৈনন্দিন আমল',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D5C3A),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TasbihScreen(),
    const HadithScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'আমল'),
          NavigationDestination(icon: Icon(Icons.touch_app_outlined), label: 'তাসবিহ'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'হাদিস'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerTimes? prayerTimes;
  final String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, bool> amolStatus = {};

  final List<Map<String, dynamic>> amolList = [
    {'id': 'tahajjud', 'title': 'তাহাজ্জুদ নামাজ (৪ রাকাত)', 'category': 'তাহাজ্জুদ'},
    {'id': 'fajr_sunnah', 'title': 'ফজর ২ রাকাত সুন্নত', 'category': 'ফজর'},
    {'id': 'fajr_fard', 'title': 'ফজর ২ রাকাত ফরজ', 'category': 'ফজর'},
    {'id': 'surah_yasin', 'title': 'সূরা ইয়াসিন তিলাওয়াত', 'category': 'ফজর পরবর্তী'},
    {'id': 'dhuhr_sunnah', 'title': 'যোহরের ৪ রাকাত সুন্নত', 'category': 'যোহর'},
    {'id': 'dhuhr_fard', 'title': 'যোহরের ৪ রাকাত ফরজ', 'category': 'যোহর'},
    {'id': 'asr_fard', 'title': 'আসরের ৪ রাকাত ফরজ', 'category': 'আসর'},
    {'id': 'maghrib_fard', 'title': 'মাগরিবের ৩ রাকাত ফরজ', 'category': 'মাগরিব'},
    {'id': 'isha_fard', 'title': 'ইশার ৪ রাকাত ফরজ', 'category': 'ইশা'},
    {'id': 'witr', 'title': '৩ রাকাত বিতর', 'category': 'ইশা'},
    {'id': 'surah_mulk', 'title': 'সূরা মুলক তিলাওয়াত', 'category': 'রাতের আমল'},
  ];

  @override
  void initState() {
    super.initState();
    _calculateTimes();
    _loadAmolStatus();
  }

  void _calculateTimes() {
    try {
      final myCoordinates = Coordinates(23.8103, 90.4125);
      final params = CalculationMethod.karachi.getParameters();
      params.madhab = Madhab.hanafi;
      final date = DateComponents.from(DateTime.now());
      prayerTimes = PrayerTimes(myCoordinates, date, params);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _loadAmolStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var amol in amolList) {
        amolStatus[amol['id']] = prefs.getBool('${todayKey}_${amol['id']}') ?? false;
      }
    });
  }

  Future<void> _completeAmol(String id) async {
    if (amolStatus[id] == true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${todayKey}_$id', true);
    setState(() => amolStatus[id] = true);
  }

  @override
  Widget build(BuildContext context) {
    final hijriDate = HijriCalendar.now();
    int completedCount = amolStatus.values.where((v) => v == true).length;
    double progress = amolList.isEmpty ? 0 : completedCount / amolList.length;

    return Scaffold(
      appBar: AppBar(title: const Text('দৈনন্দিন আমল'), backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${hijriDate.hDay} ${hijriDate.longMonthName}, ${hijriDate.hYear} হিজরি'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (prayerTimes != null)
            Card(
              color: const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _prayerItem('ফজর', prayerTimes!.fajr),
                    _prayerItem('যোহর', prayerTimes!.dhuhr),
                    _prayerItem('আসর', prayerTimes!.asr),
                    _prayerItem('মাগরিব', prayerTimes!.maghrib),
                    _prayerItem('ইশা', prayerTimes!.isha),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 15),
          Text('অগ্রগতি: $completedCount/${amolList.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          LinearProgressIndicator(value: progress, color: const Color(0xFF0D5C3A), minHeight: 6),
          const SizedBox(height: 15),
          ...amolList.map((amol) {
            bool isDone = amolStatus[amol['id']] ?? false;
            return Card(
              color: isDone ? Colors.green[50] : Colors.white,
              child: ListTile(
                title: Text(amol['title']),
                subtitle: Text(amol['category']),
                trailing: isDone
                    ? const Icon(Icons.lock, color: Colors.green)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
                        onPressed: () => _completeAmol(amol['id']),
                        child: const Text('সম্পন্ন'),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _prayerItem(String name, DateTime time) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(DateFormat('hh:mm a').format(time), style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ডিজিタル তাসবিহ'), backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => setState(() => _counter++),
              child: CircleAvatar(
                radius: 100,
                backgroundColor: const Color(0xFF0D5C3A),
                child: Text('$_counter', style: const TextStyle(fontSize: 50, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: () => setState(() => _counter = 0), child: const Text('রিসেট', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}

class HadithScreen extends StatelessWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('হাদিস'), backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          Card(
            child: ListTile(
              title: Text('হাদিস - ১: নিয়তের উপর আমল নির্ভরশীল'),
              subtitle: Text('সমস্ত কাজের ফলাফল নির্ভর করে নিয়্যতের উপর... [সহীহ বুখারী ও মুসলিম]'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('হাদিস - ২: ঈমান, ইসলাম ও ইহসান'),
              subtitle: Text('জিবরীল (আঃ)-এর আগমন ও দ্বীনের মৌলিক স্তম্ভের বর্ণনা... [সহীহ মুসলিম]'),
            ),
          ),
        ],
      ),
    );
  }
}
