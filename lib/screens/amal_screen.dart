import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../models/helpers.dart';

class AmalListScreen extends StatefulWidget {
  final bool isBn;
  final String madhab;
  const AmalListScreen({super.key, required this.isBn, required this.madhab});

  @override
  State<AmalListScreen> createState() => _AmalListScreenState();
}

class _AmalListScreenState extends State<AmalListScreen> {
  final String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, bool> amolStatus = {};
  PrayerTimes? prayerTimes;
  Timer? _refreshTimer;

  final List<AmalItem> allAmals = [
    AmalItem(id: 'tahajjud_4', titleBn: 'তাহাজ্জুদ নামাজ (৪ রাকাত)', titleEn: 'Tahajjud (4 Rak\'ah)', category: 'তাহাজ্জুদ', isFard: false, prayerName: 'tahajjud'),
    AmalItem(id: 'fajr_sunnah', titleBn: 'ফজর ২ রাকাত সুন্নত', titleEn: 'Fajr 2 Sunnah', category: 'ফজর', isFard: false, prayerName: 'fajr'),
    AmalItem(id: 'fajr_fard', titleBn: 'ফজর ২ রাকাত ফরজ (জামাতে)', titleEn: 'Fajr 2 Fard (Jama\'ah)', category: 'ফজর', isFard: true, prayerName: 'fajr'),
    AmalItem(id: 'surah_yasin', titleBn: 'সূরা ইয়াসিন তিলাওয়াত', titleEn: 'Surah Yasin', category: 'ফজর পরবর্তী', isFard: false, prayerName: 'post_fajr'),
    AmalItem(id: 'ishraq', titleBn: 'ইশরাক নামাজ (৪ রাকাত)', titleEn: 'Ishraq Prayer (4 Rak\'ah)', category: 'ইশরাক', isFard: false, prayerName: 'ishraq'),
    AmalItem(id: 'dhuhr_sunnah_pre', titleBn: 'যোহরের পূর্ববর্তী ৪ রাকাত সুন্নত', titleEn: 'Dhuhr 4 Pre-Sunnah', category: 'যোহর', isFard: false, prayerName: 'dhuhr'),
    AmalItem(id: 'dhuhr_fard', titleBn: 'যোহরের ৪ রাকাত ফরজ', titleEn: 'Dhuhr 4 Fard', category: 'যোহর', isFard: true, prayerName: 'dhuhr'),
    AmalItem(id: 'dhuhr_sunnah_post', titleBn: 'যোহরের পরবর্তী ২ রাকাত সুন্নত', titleEn: 'Dhuhr 2 Post-Sunnah', category: 'যোহর', isFard: false, prayerName: 'dhuhr'),
    AmalItem(id: 'asr_fard', titleBn: 'আসরের ৪ রাকাত ফরজ', titleEn: 'Asr 4 Fard', category: 'আসর', isFard: true, prayerName: 'asr'),
    AmalItem(id: 'evening_dhikr', titleBn: 'বিকেলের জিকির ও আজকার', titleEn: 'Evening Adhkar', category: 'আসর পরবর্তী', isFard: false, prayerName: 'asr'),
    AmalItem(id: 'maghrib_fard', titleBn: 'মাগরিবের ৩ রাকাত ফরজ', titleEn: 'Maghrib 3 Fard', category: 'মাগরিব', isFard: true, prayerName: 'maghrib'),
    AmalItem(id: 'maghrib_sunnah', titleBn: 'মাগরিবের পরবর্তী ২ রাকাত সুন্নত', titleEn: 'Maghrib 2 Sunnah', category: 'মাগরিব', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'awwabin', titleBn: 'আওয়াবিন নামাজ', titleEn: 'Awwabin Prayer', category: 'মাগরিব', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'surah_waqiah', titleBn: 'সূরা ওয়াকিয়াহ তিলাওয়াত', titleEn: 'Surah Waqiah', category: 'মাগরিব পরবর্তী', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'isha_fard', titleBn: 'ইশার ৪ রাকাত ফরজ', titleEn: 'Isha 4 Fard', category: 'ইশা', isFard: true, prayerName: 'isha'),
    AmalItem(id: 'isha_sunnah', titleBn: 'ইশার ২ রাকাত সুন্নত', titleEn: 'Isha 2 Sunnah', category: 'ইশা', isFard: false, prayerName: 'isha'),
    AmalItem(id: 'isha_witr', titleBn: '৩ রাকাত বিতর', titleEn: '3 Rak\'ah Witr', category: 'ইশা', isFard: true, prayerName: 'isha'),
    AmalItem(id: 'surah_mulk', titleBn: 'সূরা মুলক তিলাওয়াত', titleEn: 'Surah Mulk', category: 'ঘুমানোর পূর্বে', isFard: false, prayerName: 'bedtime'),
  ];

  @override
  void initState() {
    super.initState();
    _initTimes();
    _loadAmolStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _initTimes() {
    final coords = Coordinates(23.8103, 90.4125);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = widget.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    prayerTimes = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
  }

  Future<void> _loadAmolStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var a in allAmals) {
        amolStatus[a.id] = prefs.getBool('${todayKey}_${a.id}') ?? false;
      }
    });
  }

  Future<void> _toggleAmol(String id) async {
    if (amolStatus[id] == true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${todayKey}_$id', true);
    setState(() => amolStatus[id] = true);
  }

  // ২. Upcoming, Running, Just Passed স্ট্যাটাস লজিক
  Map<String, dynamic> _getAmolStatus(AmalItem item) {
    if (prayerTimes == null) return {'status': 'running', 'label': 'Running', 'color': Colors.green};
    DateTime now = DateTime.now();
    DateTime start, end;

    switch (item.prayerName) {
      case 'tahajjud':
        start = prayerTimes!.fajr.subtract(const Duration(minutes: 90));
        end = prayerTimes!.fajr.subtract(const Duration(minutes: 10));
        break;
      case 'fajr':
        start = prayerTimes!.fajr;
        end = prayerTimes!.sunrise;
        break;
      case 'post_fajr':
      case 'ishraq':
        start = prayerTimes!.sunrise;
        end = prayerTimes!.dhuhr.subtract(const Duration(minutes: 30));
        break;
      case 'dhuhr':
        start = prayerTimes!.dhuhr;
        end = prayerTimes!.asr;
        break;
      case 'asr':
        start = prayerTimes!.asr;
        end = prayerTimes!.maghrib;
        break;
      case 'maghrib':
        start = prayerTimes!.maghrib;
        end = prayerTimes!.isha;
        break;
      case 'isha':
      case 'bedtime':
      default:
        start = prayerTimes!.isha;
        end = DateTime(now.year, now.month, now.day, 23, 59);
        break;
    }

    DateTime gracePeriodEnd = end.add(const Duration(minutes: 10));

    if (now.isBefore(start)) {
      return {'status': 'upcoming', 'label': 'Upcoming', 'color': Colors.blueGrey, 'canCheck': false};
    } else if (now.isAfter(start) && now.isBefore(end)) {
      return {'status': 'running', 'label': 'Running', 'color': Colors.green, 'canCheck': true};
    } else if (now.isAfter(end) && now.isBefore(gracePeriodEnd)) {
      return {'status': 'just_passed', 'label': 'Just Passed (১০ মি.)', 'color': Colors.deepOrange, 'canCheck': true};
    } else {
      return {'status': 'past', 'label': 'Past', 'color': Colors.red, 'canCheck': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    int completedCount = amolStatus.values.where((v) => v == true).length;
    double progress = allAmals.isEmpty ? 0 : completedCount / allAmals.length;
    int percent = (progress * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'দৈনন্দিন আমল তালিকা' : 'Amal Checklist', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('অগ্রগতি: $completedCount/${allAmals.length} — $percent%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                  const Icon(Icons.check_circle, color: Color(0xFF0D5C3A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...allAmals.map((item) {
            bool isDone = amolStatus[item.id] ?? false;
            var st = _getAmolStatus(item);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isDone ? Colors.green.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDone ? Colors.green : (item.isFard ? Colors.deepOrange.shade300 : Colors.grey.shade300), width: item.isFard ? 1.5 : 1.0),
              ),
              child: ListTile(
                leading: Icon(
                  item.isFard ? Icons.star_rounded : Icons.radio_button_checked,
                  color: item.isFard ? Colors.deepOrange : const Color(0xFF0D5C3A),
                ),
                title: Text(widget.isBn ? item.titleBn : item.titleEn, style: TextStyle(fontWeight: FontWeight.w600, decoration: isDone ? TextDecoration.lineThrough : null)),
                subtitle: Row(
                  children: [
                    Text(item.category, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if (!isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: (st['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(st['label'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: st['color'])),
                      ),
                  ],
                ),
                trailing: isDone
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('লক ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          Icon(Icons.lock, color: Colors.green, size: 18),
                        ],
                      )
                    : (st['canCheck'] == true
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: st['status'] == 'just_passed' ? Colors.deepOrange : const Color(0xFF0D5C3A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => _toggleAmol(item.id),
                            child: const Text('টিক দিন'),
                          )
                        : Chip(label: Text(st['label'], style: const TextStyle(fontSize: 11, color: Colors.grey)))),
              ),
            );
          }),
        ],
      ),
    );
  }
}
