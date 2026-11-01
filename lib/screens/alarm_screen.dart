import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class AlarmScreen extends StatefulWidget {
  final bool isBn;
  const AlarmScreen({super.key, required this.isBn});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final Map<String, bool> _alarms = {};
  final Map<String, bool> _notifications = {};
  bool _isPlayingAlarm = false;

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
    _stopSound();
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

  // ফোনের আসল সিস্টেম অ্যালার্ম সাউন্ড বাজানো
  void _playSystemAlarm() {
    setState(() => _isPlayingAlarm = true);
    FlutterRingtonePlayer().playAlarm(
      volume: 1.0,
      looping: true,
      asAlarm: true,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.alarm_on, color: Colors.deepOrange, size: 30),
            const SizedBox(width: 8),
            Text(widget.isBn ? 'ফোনের আসল অ্যালার্ম বাজছে!' : 'Phone Alarm Ringing!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isBn ? 'حي على الصلاة • নামাজের অ্যালার্ম!' : 'Hayya \'alas-Salah • Time for Prayer!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A)),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isBn
                  ? 'আপনার ফোনের নিজস্ব সিস্টেম অ্যালার্ম রিংটোনটি সফলভাবে বাজছে। এটি বন্ধ করতে নিচের বাটনে চাপ দিন।'
                  : 'Your phone\'s native alarm ringtone is playing. Tap below to stop.',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.stop),
            label: Text(widget.isBn ? 'অ্যালার্ম বন্ধ করুন' : 'Stop Alarm'),
            onPressed: () {
              _stopSound();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ফোনের আসল নোটিফিকেশন সাউন্ড বাজানো
  void _playSystemNotification() {
    FlutterRingtonePlayer().playNotification(
      volume: 1.0,
      looping: false,
      asAlarm: false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.isBn ? 'ফোনের আসল নোটিফিকেশন সাউন্ড বাজানো হয়েছে!' : 'System notification tone played!')),
    );
  }

  void _stopSound() {
    FlutterRingtonePlayer().stop();
    if (mounted) setState(() => _isPlayingAlarm = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'অ্যালার্ম ও নোটিফিকেশন এক্সেস' : 'Alarms & Access', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ফোনের পারমিশন ও এক্সেস কার্ড
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
                      const Icon(Icons.security, color: Color(0xFF0D5C3A), size: 22),
                      const SizedBox(width: 8),
                      Text(widget.isBn ? 'ফোনের এক্সেস ও সাউন্ড টেস্ট' : 'System Access & Sound Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isBn
                        ? 'এই অ্যাপটি আপনার ফোনের ডিফল্ট অ্যালার্ম রিংটোন এবং নোটিফিকেশন টিউন ব্যবহার করার সম্পূর্ণ এক্সেস রাখে।'
                        : 'This app accesses your device\'s native system alarm tones and notification channels.',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
                          icon: const Icon(Icons.alarm, size: 18),
                          label: Text(widget.isBn ? 'অ্যালার্ম বাজান' : 'Test Alarm'),
                          onPressed: _playSystemAlarm,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D5C3A)),
                          icon: const Icon(Icons.notifications_active, size: 18),
                          label: Text(widget.isBn ? 'নোটিফিকেশন টিউন' : 'Test Tone'),
                          onPressed: _playSystemNotification,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ১. গুরুত্বপূর্ণ নামাজের অ্যালার্ম
          Text(widget.isBn ? 'নামাজের পূর্ণাঙ্গ অ্যালার্ম (Alarm System)' : 'Prayer Alarms (Ringtone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
          const SizedBox(height: 8),
          ...prayerAlarms.map((a) {
            bool isSet = _alarms[a['id']] ?? true;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                secondary: Icon(isSet ? Icons.alarm_on : Icons.alarm_off, color: isSet ? const Color(0xFF0D5C3A) : Colors.grey),
                title: Text(widget.isBn ? a['titleBn']! : a['titleEn']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(widget.isBn ? 'ফোনের রিংটোনে বাজবে' : 'Rings phone alarm tone', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                value: isSet,
                activeColor: const Color(0xFF0D5C3A),
                onChanged: (val) => _toggleAlarm(a['id']!, val),
              ),
            );
          }),

          const SizedBox(height: 20),

          // ২. আমল নোটিফিকেশন
          Text(widget.isBn ? 'আমলের নোটিফিকেশন (Notification Tune)' : 'Amal Notification Tunes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
          const SizedBox(height: 8),
          ...amalNotifications.map((n) {
            bool isSet = _notifications[n['id']] ?? true;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                secondary: Icon(isSet ? Icons.notifications_active : Icons.notifications_off, color: isSet ? Colors.teal : Colors.grey),
                title: Text(widget.isBn ? n['titleBn']! : n['titleEn']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(widget.isBn ? 'ফোনের নোটিফিকেশন সাউন্ডে আসবে' : 'Plays system notification tone', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
