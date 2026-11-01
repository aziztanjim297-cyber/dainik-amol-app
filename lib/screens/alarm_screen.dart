import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmScreen extends StatefulWidget {
  final bool isBn;
  const AlarmScreen({super.key, required this.isBn});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final Map<String, bool> _alarms = {};
  final Map<String, bool> _notifications = {};
  Timer? _alarmVibrateTimer;
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
    _stopAlarm();
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

  // ফোনের আসল সিস্টেম অ্যালার্ট সাউন্ড ও হার্ডওয়্যার ভাইব্রেশন অ্যালার্ম
  void _playSystemAlarm() {
    setState(() => _isPlaying = true);
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    _alarmVibrateTimer?.cancel();
    _alarmVibrateTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!_isPlaying) {
        timer.cancel();
      } else {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.alarm_on, color: Colors.deepOrange, size: 28),
            const SizedBox(width: 8),
            Text(widget.isBn ? 'নামাজের অ্যালার্ম বাজছে!' : 'Prayer Alarm Ringing!'),
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
            const SizedBox(height: 10),
            Text(
              widget.isBn
                  ? 'আপনার ফোনের সিস্টেম অ্যালার্ট ও ভাইব্রেশন সফলভাবে সক্রিয় হয়েছে। অ্যালার্ম বন্ধ করতে নিচের বাটনে চাপ দিন।'
                  : 'Your phone alert tone and vibration are active. Tap below to stop.',
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
              _stopAlarm();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _playSystemNotification() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.isBn ? 'সিস্টেম নোটিফিকেশন সাউন্ড ও ভাইব্রেশন সক্রিয়!' : 'System alert tone triggered!')),
    );
  }

  void _stopAlarm() {
    _alarmVibrateTimer?.cancel();
    if (mounted) setState(() => _isPlaying = false);
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
                      const Icon(Icons.security, color: Color(0xFF0D5C3A), size: 22),
                      const SizedBox(width: 8),
                      Text(widget.isBn ? 'সিস্টেম এক্সেস ও অ্যালার্ম টেস্ট' : 'System Access & Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isBn
                        ? 'ওয়াক্ত অনুযায়ী সিস্টেম অ্যালার্ট ও ভাইব্রেশন নিশ্চিত করতে নিচের বাটন দিয়ে পরীক্ষা করুন।'
                        : 'Test system alert sound and hardware vibration for prayers.',
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
                          label: Text(widget.isBn ? 'নোটিফিকেশন' : 'Test Tone'),
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

          Text(widget.isBn ? 'নামাজের পূর্ণাঙ্গ অ্যালার্ম (Alarm System)' : 'Prayer Alarms', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
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
