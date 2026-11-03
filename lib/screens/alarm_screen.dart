import 'package:adhan/adhan.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final bool isBn;
  final Coordinates? coords;
  final CalculationMethod calculationMethod;
  final String madhab;

  const AlarmScreen({
    super.key,
    required this.isBn,
    this.coords,
    this.calculationMethod = CalculationMethod.karachi,
    this.madhab = 'hanafi',
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}


class _AlarmScreenState extends State<AlarmScreen> {
  Coordinates? _coords;
  DateTime? _getAlarmTime(String id, DateTime date) {
    if (_coords == null) return null;

    final params = _getParams();
    final times = PrayerTimes(
      _coords!,
      DateComponents.from(date),
      params,
    );

    switch (id) {
      case 'alarm_tahajjud':
        return times.fajr.subtract(const Duration(minutes: 30));
      case 'alarm_fajr':
        return times.fajr;
      case 'alarm_ishraq':
        return times.sunrise.add(const Duration(minutes: 15));
      case 'alarm_dhuhr':
        return times.dhuhr;
      case 'alarm_asr':
        return times.asr;
      case 'alarm_maghrib':
        return times.maghrib;
      case 'alarm_isha':
        return times.isha;
      default:
        return null;
    }
  }

  CalculationParameters _getParams() {
    final params = widget.calculationMethod.getParameters();
    params.madhab = widget.madhab == 'hanafi'
        ? Madhab.hanafi
        : Madhab.shafi;
    return params;
  }

  final Map<String, bool> _alarms = {};
  final Map<String, bool> _notifications = {};
  final Map<String, String> _alarmModes = {};
  final Map<String, int> _alarmDelays = {};
  final Map<String, TimeOfDay> _fixedTimes = {};
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
    _coords = widget.coords;
    if (_coords == null) {
      final lat = prefs.getDouble('location_lat');
      final lon = prefs.getDouble('location_lon');
      if (lat != null && lon != null) {
        _coords = Coordinates(lat, lon);
      }
    }
    setState(() {
      for (var a in prayerAlarms) {
        final id = a['id']!;
        _alarms[id] = prefs.getBool(id) ?? true;
        _alarmModes[id] = prefs.getString('alarm_mode_$id') ?? 'prayer';
        _alarmDelays[id] = prefs.getInt('alarm_delay_$id') ?? 15;
        final parts = (prefs.getString('alarm_fixed_$id') ?? '07:30').split(':');
        _fixedTimes[id] = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      for (var n in amalNotifications) {
        _notifications[n['id']!] = prefs.getBool(n['id']!) ?? true;
      }
    });

    await _schedulePrayerAlarms();
  }

  Future<void> _schedulePrayerAlarms() async {
    if (_coords == null) return;

    final service = NotificationService.instance;
    await service.initialize();

    final now = DateTime.now();

    for (int day = 0; day < 7; day++) {
      final date = DateTime(now.year, now.month, now.day + day);

      for (int index = 0; index < prayerAlarms.length; index++) {
        final item = prayerAlarms[index];
        final id = item['id']!;
        final enabled = _alarms[id] ?? true;

        final dayNumber = DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(2020, 1, 1)).inDays;

        final notificationId = dayNumber * 10 + index;

        await service.cancelAlarm(notificationId);
        if (!enabled) continue;

        DateTime? alarmTime;

        final supportsCustomMode =
            id != 'alarm_tahajjud' && id != 'alarm_ishraq';

        final mode = supportsCustomMode
            ? (_alarmModes[id] ?? 'prayer')
            : 'prayer';

        if (mode == 'fixed') {
          final fixed = _fixedTimes[id] ??
              const TimeOfDay(hour: 7, minute: 30);

          alarmTime = DateTime(
            date.year,
            date.month,
            date.day,
            fixed.hour,
            fixed.minute,
          );
        } else {
          alarmTime = _getAlarmTime(id, date);

          if (alarmTime != null && mode == 'delay') {
            alarmTime = alarmTime.add(
              Duration(minutes: _alarmDelays[id] ?? 15),
            );
          }
        }

        if (alarmTime == null || !alarmTime.isAfter(now)) continue;

        await service.scheduleAlarm(
          id: notificationId,
          title: item['titleBn']!,
          body: 'নামাজের অ্যালার্ম • দৈনিক আমল',
          dateTime: alarmTime,
          payload: id,
        );
      }
    }
  }

  Future<void> _toggleAlarm(String id, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(id, val);
    setState(() => _alarms[id] = val);
    await _schedulePrayerAlarms();
  }

  Future<String> _getAlarmMode(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('alarm_mode_$id') ?? 'prayer';
  }

  Future<int> _getAlarmDelay(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('alarm_delay_$id') ?? 15;
  }

  Future<TimeOfDay> _getFixedAlarmTime(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('alarm_fixed_$id') ?? '07:30';
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _saveAlarmMode(String id, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_mode_$id', mode);
  }

  Future<void> _saveAlarmDelay(String id, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('alarm_delay_$id', minutes);
  }

  Future<void> _saveFixedAlarmTime(String id, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    final value = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await prefs.setString('alarm_fixed_$id', value);
  }

  Future<void> _toggleNotification(String id, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(id, val);

    const amalIds = <String, String>{
      'notif_yasin': 'surah_yasin',
      'notif_morning_dhikr': 'morning_adhkar',
      'notif_quran': 'quran_2_pages',
      'notif_evening_dhikr': 'evening_dhikr',
      'notif_waqiah': 'surah_waqiah',
      'notif_mulk': 'surah_mulk',
      'notif_muhasaba': 'muhasabah',
    };

    final amalId = amalIds[id];
    if (amalId != null) {
      if (!val) {
        await NotificationService.instance.cancelAmalReminders(amalId, allDays: true);
      } else if (_coords != null) {
        await NotificationService.instance.scheduleAmalReminders(
          coords: _coords!,
          madhab: widget.madhab,
        );
      }
    }

    if (mounted) setState(() => _notifications[id] = val);
  }

  Future<void> _changeAlarmMode(String id, String mode) async {
    await _saveAlarmMode(id, mode);
    if (mounted) setState(() => _alarmModes[id] = mode);
    await _schedulePrayerAlarms();
  }

  Future<void> _changeAlarmDelay(String id, int minutes) async {
    await _saveAlarmDelay(id, minutes);
    if (mounted) setState(() => _alarmDelays[id] = minutes);
    await _schedulePrayerAlarms();
  }

  Future<void> _customAlarmDelay(String id) async {
    final controller = TextEditingController(
      text: (_alarmDelays[id] ?? 15).toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isBn ? 'কত মিনিট যোগ করবেন?' : 'Add how many minutes?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.isBn ? 'মিনিট' : 'Minutes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.isBn ? 'বাতিল' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n >= 0 && n <= 1440) {
                Navigator.pop(ctx, n);
              }
            },
            child: Text(widget.isBn ? 'সংরক্ষণ' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await _changeAlarmDelay(id, value);
  }

  Future<void> _pickFixedTime(String id) async {
    final initial = _fixedTimes[id] ?? const TimeOfDay(hour: 7, minute: 30);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    await _saveFixedAlarmTime(id, picked);
    if (mounted) setState(() => _fixedTimes[id] = picked);
    await _schedulePrayerAlarms();
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
            final id = a['id']!;
            final isSet = _alarms[id] ?? true;
            final mode = _alarmModes[id] ?? 'prayer';
            final delay = _alarmDelays[id] ?? 15;
            final fixedTime = _fixedTimes[id] ?? const TimeOfDay(hour: 7, minute: 30);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        isSet ? Icons.alarm_on : Icons.alarm_off,
                        color: isSet ? const Color(0xFF0D5C3A) : Colors.grey,
                      ),
                      title: Text(
                        widget.isBn ? a['titleBn']! : a['titleEn']!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: isSet,
                      activeColor: const Color(0xFF0D5C3A),
                      onChanged: (val) => _toggleAlarm(id, val),
                    ),
                    if (isSet && id != 'alarm_tahajjud' && id != 'alarm_ishraq') ...[
                      const Divider(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isBn ? 'অ্যালার্মের সময় নির্ধারণ' : 'Alarm time setting',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: mode,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'prayer',
                                  child: Text(widget.isBn ? 'ওয়াক্ত অনুযায়ী' : 'Prayer time'),
                                ),
                                DropdownMenuItem(
                                  value: 'delay',
                                  child: Text(widget.isBn ? 'ওয়াক্তের পর মিনিট যোগ' : 'Minutes after prayer'),
                                ),
                                DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text(widget.isBn ? 'প্রতিদিন নির্দিষ্ট ঘড়ির সময়' : 'Fixed daily clock time'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) _changeAlarmMode(id, value);
                              },
                            ),
                            if (mode == 'delay') ...[
                              const SizedBox(height: 12),
                              Text(widget.isBn ? 'কত মিনিট পরে অ্যালার্ম বাজবে?' : 'Delay after prayer'),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [0, 10, 15, 20, 30, 45, 60].map((m) {
                                  return ChoiceChip(
                                    label: Text('$m ${widget.isBn ? 'মিনিট' : 'min'}'),
                                    selected: delay == m,
                                    onSelected: (_) => _changeAlarmDelay(id, m),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _customAlarmDelay(id),
                                icon: const Icon(Icons.edit),
                                label: Text(
                                  widget.isBn
                                      ? 'নিজের মতো মিনিট লিখুন (বর্তমান: $delay)'
                                      : 'Custom minutes (current: $delay)',
                                ),
                              ),
                            ],
                            if (mode == 'fixed') ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _pickFixedTime(id),
                                icon: const Icon(Icons.access_time),
                                label: Text(
                                  '${widget.isBn ? 'নির্দিষ্ট সময়' : 'Fixed time'}: ${fixedTime.format(context)}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
