import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../models/helpers.dart';

class AmalListScreen extends StatefulWidget {
  final bool isBn;
  const AmalListScreen({super.key, required this.isBn});

  @override
  State<AmalListScreen> createState() => _AmalListScreenState();
}

class _AmalListScreenState extends State<AmalListScreen> {
  final String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, bool> amolStatus = {};
  PrayerTimes? prayerTimes;

  final List<AmalItem> allAmals = [
    AmalItem(id: 'tahajjud_4', titleBn: 'তাহাজ্জুদ নামাজ (৪ রাকাত)', titleEn: 'Tahajjud Prayer (4 Rak\'ah)', category: 'তাহাজ্জুদ', isFard: false, prayerName: 'tahajjud'),
    AmalItem(id: 'fajr_sunnah', titleBn: 'ফজর ২ রাকাত সুন্নত', titleEn: 'Fajr 2 Rak\'ah Sunnah', category: 'ফজর', isFard: false, prayerName: 'fajr'),
    AmalItem(id: 'fajr_fard', titleBn: 'ফজর ২ রাকাত ফরজ (জামাতে)', titleEn: 'Fajr 2 Rak\'ah Fard (Jama\'ah)', category: 'ফজর', isFard: true, prayerName: 'fajr'),
    AmalItem(id: 'surah_yasin', titleBn: 'সূরা ইয়াসিন তিলাওয়াত', titleEn: 'Surah Yasin Recitation', category: 'ফজর পরবর্তী', isFard: false, prayerName: 'post_fajr'),
    AmalItem(id: 'ishraq', titleBn: 'ইশরাক নামাজ (৪ রাকাত)', titleEn: 'Ishraq Prayer (4 Rak\'ah)', category: 'ইশরাক', isFard: false, prayerName: 'ishraq'),
    AmalItem(id: 'dhuhr_sunnah_pre', titleBn: 'যোহরের পূর্ববর্তী ৪ রাকাত সুন্নত', titleEn: 'Dhuhr 4 Rak\'ah Pre-Sunnah', category: 'যোহর', isFard: false, prayerName: 'dhuhr'),
    AmalItem(id: 'dhuhr_fard', titleBn: 'যোহরের ৪ রাকাত ফরজ', titleEn: 'Dhuhr 4 Rak\'ah Fard', category: 'যোহর', isFard: true, prayerName: 'dhuhr'),
    AmalItem(id: 'dhuhr_sunnah_post', titleBn: 'যোহরের পরবর্তী ২ রাকাত সুন্নত', titleEn: 'Dhuhr 2 Rak\'ah Post-Sunnah', category: 'যোহর', isFard: false, prayerName: 'dhuhr'),
    AmalItem(id: 'asr_fard', titleBn: 'আসরের ৪ রাকাত ফরজ', titleEn: 'Asr 4 Rak\'ah Fard', category: 'আসর', isFard: true, prayerName: 'asr'),
    AmalItem(id: 'evening_dhikr', titleBn: 'বিকেলের জিকির ও আজকার', titleEn: 'Evening Adhkar', category: 'আসর পরবর্তী', isFard: false, prayerName: 'asr'),
    AmalItem(id: 'maghrib_fard', titleBn: 'মাগরিবের ৩ রাকাত ফরজ', titleEn: 'Maghrib 3 Rak\'ah Fard', category: 'মাগরিব', isFard: true, prayerName: 'maghrib'),
    AmalItem(id: 'maghrib_sunnah', titleBn: 'মাগরিবের পরবর্তী ২ রাকাত সুন্নত', titleEn: 'Maghrib 2 Rak\'ah Sunnah', category: 'মাগরিব', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'awwabin', titleBn: 'আওয়াবিন নামাজ', titleEn: 'Awwabin Prayer', category: 'মাগরিব', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'surah_waqiah', titleBn: 'সূরা ওয়াকিয়াহ তিলাওয়াত', titleEn: 'Surah Waqiah Recitation', category: 'মাগরিব পরবর্তী', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'isha_fard', titleBn: 'ইশার ৪ রাকাত ফরজ', titleEn: 'Isha 4 Rak\'ah Fard', category: 'ইশা', isFard: true, prayerName: 'isha'),
    AmalItem(id: 'isha_sunnah', titleBn: 'ইশার ২ রাকাত সুন্নত', titleEn: 'Isha 2 Rak\'ah Sunnah', category: 'ইশা', isFard: false, prayerName: 'isha'),
    AmalItem(id: 'isha_witr', titleBn: '৩ রাকাত বিতর', titleEn: '3 Rak\'ah Witr', category: 'ইশা', isFard: true, prayerName: 'isha'),
    AmalItem(id: 'surah_mulk', titleBn: 'সূরা মুলক তিলাওয়াত', titleEn: 'Surah Mulk Recitation', category: 'ঘুমানোর পূর্বে', isFard: false, prayerName: 'bedtime'),
  ];

  @override
  void initState() {
    super.initState();
    final coords = Coordinates(23.8103, 90.4125);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    prayerTimes = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
    _loadAmolStatus();
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

  Map<String, dynamic> _getAmolWindow(AmalItem item) {
    if (prayerTimes == null) return {'status': 'active'};
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
    if (now.isBefore(start)) return {'status': 'upcoming', 'label': 'Upcoming'};
    if (now.isAfter(gracePeriodEnd)) return {'status': 'past', 'label': 'Past'};
    return {'status': 'active', 'label': 'Active'};
  }

  @override
  Widget build(BuildContext context) {
    int completedCount = amolStatus.values.where((v) => v == true).length;
    double progress = allAmals.isEmpty ? 0 : completedCount / allAmals.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'দৈনন্দিন আমল তালিকা' : 'Daily Amal Checklist', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.isBn ? 'আজকের অগ্রগতি' : 'Today\'s Progress', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                      Text('$completedCount / ${allAmals.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(4), color: const Color(0xFF0D5C3A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...allAmals.map((item) {
            bool isDone = amolStatus[item.id] ?? false;
            var window = _getAmolWindow(item);
            String status = window['status'];

            Color borderColor = isDone ? Colors.green : (item.isFard ? Colors.deepOrange.shade300 : Colors.teal.shade200);
            Color bgColor = isDone ? Colors.green.shade50 : (item.isFard ? const Color(0xFFFFF7F2) : Colors.white);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor, width: item.isFard ? 1.6 : 1.0)),
              child: ListTile(
                leading: Icon(item.isFard ? Icons.star_rounded : Icons.radio_button_checked, color: item.isFard ? Colors.deepOrange : const Color(0xFF0D5C3A)),
                title: Text(widget.isBn ? item.titleBn : item.titleEn, style: TextStyle(fontWeight: FontWeight.w600, decoration: isDone ? TextDecoration.lineThrough : null)),
                subtitle: Text('${item.category} • ${item.isFard ? (widget.isBn ? "ফরজ" : "Fard") : (widget.isBn ? "সুন্নত/নফল" : "Sunnah")}'),
                trailing: isDone
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('সম্পন্ন ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                          Icon(Icons.lock, color: Colors.green, size: 20),
                        ],
                      )
                    : (status == 'upcoming'
                        ? Chip(label: Text(window['label'], style: const TextStyle(fontSize: 11, color: Colors.blueGrey)))
                        : (status == 'past'
                            ? Chip(label: Text(window['label'], style: const TextStyle(fontSize: 11, color: Colors.red)), backgroundColor: Colors.red[50])
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
                                onPressed: () => _toggleAmol(item.id),
                                child: Text(widget.isBn ? 'সম্পন্ন' : 'Check'),
                              ))),
              ),
            );
          }),
        ],
      ),
    );
  }
}
