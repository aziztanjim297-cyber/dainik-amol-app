import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class AlarmScreen extends StatefulWidget {
  final bool isBn;
  const AlarmScreen({super.key, required this.isBn});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final Map<String, bool> _alarms = {};
  final Map<String, bool> _notifications = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  final List<Map<String, String>> prayerAlarms = [
    {'id': 'alarm_tahajjud', 'titleBn': 'তাহাজ্জুদ অ্যালার্ম (ফজরের পূর্বে)', 'titleEn': 'Tahajjud Alarm (Before Fajr)'},
    {'id': 'alarm_fajr', 'titleBn': 'ফজরের নামাজ অ্যালার্ম', 'titleEn': 'Fajr Prayer Alarm'},
    {'id': 'alarm_ishraq', 'titleBn': 'ইশরাক নামাজ অ্যালার্ম', 'titleEn': 'Ishraq Prayer Alarm'},
    {'id': 'alarm_dhuhr', 'titleBn': 'যোহরের নামাজ অ্যালার্ম', 'titleEn': 'Dhuhr Prayer Alarm'},
    {'id': 'alarm_asr', 'titleBn': 'আসরের নামাজ অ্যালার্ম', 'titleEn': 'Asr Prayer Alarm'},
    {'id': 'alarm_maghrib', 'titleBn': 'মাগরিবের নামাজ অ্যালার্ম', 'titleEn': 'Maghrib Prayer Alarm'},
    {'id': 'alarm_isha', 'titleBn': 'ইশার নামাজ অ্যালার্ম', 'titleEn': 'Isha Prayer Alarm'},
  ];

  final List<Map<String, String>> amalNotifications = [
    {'id': 'notif_yasin', 'titleBn': 'সূরা ইয়াসিন তিলাওয়াত', 'titleEn': 'Surah Yasin Recitation'},
    {'id': 'notif_morning_dhikr', 'titleBn': 'সকালবেলার জিকির ও আজকার', 'titleEn': 'Morning Adhkar'},
    {'id': 'notif_quran', 'titleBn': 'দৈনিক কুরআন তিলাওয়াত (২ পৃষ্ঠা)', 'titleEn': 'Daily Quran (2 Pages)'},
    {'id': 'notif_evening_dhikr', 'titleBn': 'বিকেলের জিকির ও আজকার', 'titleEn': 'Evening Adhkar'},
    {'id': 'notif_waqiah', 'titleBn': 'সূরা ওয়াকিয়াহ তিলাওয়াত', 'titleEn': 'Surah Waqiah Recitation'},
    {'id': 'notif_mulk', 'titleBn': 'সূরা মুলক (ঘুমানোর পূর্বে)', 'titleEn': 'Surah Mulk (Before Bed)'},
    {'id': 'notif_muhasaba', 'titleBn': 'দিনের কাজের মুহাসাবা / হিসাব', 'titleEn': 'Daily Self-Evaluation'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAlarmSettings();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var a in prayerAlarms) {
        _alarms[a['id']!] = prefs.getBool(a['id']!) ?? true;
      }
      for (var n in amalNotifications) {
        _notifications[n['id']!] = prefs.getBool(n['id']!) ?? true;
      }
    });
  }

  Future<void> _toggleAlarm(String id, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(id, val);
    setState(() => _alarms[id] = val);
  }

  Future<void> _toggleNotification(String id, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(id, val);
    setState(() => _notifications[id] = val);
  }

  // আযান ও অ্যালার্ম বাজানো (অনলাইন ইসলামিক আযান অডিও)
  Future<void> _playAdhanAlarm() async {
    setState(() => _isPlaying = true);
    try {
      // পবিত্র মক্কা শরীফের আযানের সুর
      await _audioPlayer.play(UrlSource('https://media.sd.ma/assabile/adhan_3742/al-azhar.mp3'));
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.alarm_on, color: Color(0xFF0D5C3A), size: 28),
            const SizedBox(width: 8),
            Text(widget.isBn ? 'নামাজের আযান বাজছে' : 'Prayer Adhan Playing'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isBn ? 'حي على الصلاة • নামাজের সময় হয়েছে!' : 'Hayya \'alas-Salah • Time for Prayer!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A)),
            ),
            const SizedBox(height: 8),
            Text(widget.isBn ? 'অ্যালার্ম সাউন্ড সফলভাবে বাজছে। আযান বন্ধ করতে নিচের বাটনে চাপ দিন।' : 'Alarm sound is playing. Tap below to stop.'),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.stop),
            label: Text(widget.isBn ? 'আযান বন্ধ করুন' : 'Stop Adhan'),
            onPressed: () async {
              await _audioPlayer.stop();
              setState(() => _isPlaying = false);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'অ্যালার্ম ও নোটিফিকেশন' : 'Alarms & Notifications', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFFE8F5E9),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Color(0xFF0D5C3A), size: 22),
                      const SizedBox(width: 8),
                      Text(widget.isBn ? 'নামাজের আযান ও অ্যালার্ম টেস্ট' : 'Adhan & Sound Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isBn
                        ? 'ওয়াক্তের শুরুতে আযানের সুর বাজাতে অ্যালার্ম সক্রিয় রাখুন।'
                        : 'Keep alarms active to hear adhan tone at prayer times.',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const Divider(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(widget.isBn ? 'আযান সাউন্ড টেস্ট করুন' : 'Test Adhan Sound'),
                    onPressed: _playAdhanAlarm,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(widget.isBn ? 'নামাজের অ্যালার্ম (Alarm System)' : 'Prayer Alarms', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
          const SizedBox(height: 8),
          ...prayerAlarms.map((a) {
            bool isSet = _alarms[a['id']] ?? true;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                secondary: Icon(isSet ? Icons.alarm_on : Icons.alarm_off, color: isSet ? const Color(0xFF0D5C3A) : Colors.grey),
                title: Text(widget.isBn ? a['titleBn']! : a['titleEn']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                value: isSet,
                activeColor: const Color(0xFF0D5C3A),
                onChanged: (val) => _toggleAlarm(a['id']!, val),
              ),
            );
          }),

          const SizedBox(height: 20),

          Text(widget.isBn ? 'আমলের নোটিফিকেশন (Reminders)' : 'Amal Reminders', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
          const SizedBox(height: 8),
          ...amalNotifications.map((n) {
            bool isSet = _notifications[n['id']] ?? true;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                secondary: Icon(isSet ? Icons.notifications_active : Icons.notifications_off, color: isSet ? Colors.teal : Colors.grey),
                title: Text(widget.isBn ? n['titleBn']! : n['titleEn']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                value: isSet,
                activeColor: Colors.teal,
                onChanged: (val) => _toggleNotification(n['id']!, val),
              ),
            );
          }),
        ],
      ),
    );
  }
}
