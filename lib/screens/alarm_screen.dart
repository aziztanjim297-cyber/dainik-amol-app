import 'package:adhan/adhan.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final bool isBn;
  final String language;
  final Coordinates? coords;
  final CalculationMethod calculationMethod;
  final String madhab;

  const AlarmScreen({
    super.key,
    required this.isBn,
    String? language,
    this.coords,
    this.calculationMethod = CalculationMethod.karachi,
    this.madhab = 'hanafi',
  }) : language = language ?? (isBn ? 'bn' : 'en');

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}


class _AlarmScreenState extends State<AlarmScreen> with WidgetsBindingObserver {
  String _t(String bn, String en, String ar) =>
      widget.language == 'ar' ? ar : (widget.isBn ? bn : en);


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
  bool _isPlaying = false;
  bool? _exactAlarmAllowed;
  static const MethodChannel _nativeAlarmChannel = MethodChannel('dainik_amol/alarm');

  final List<Map<String, String>> prayerAlarms = [
    {'id': 'alarm_tahajjud', 'titleBn': 'তাহাজ্জুদ অ্যালার্ম (ফজরের পূর্বে)', 'titleEn': 'Tahajjud Alarm (Before Fajr)', 'titleAr': 'منبه التهجد (قبل الفجر)'},
    {'id': 'alarm_fajr', 'titleBn': 'ফজরের নামাজ অ্যালার্ম', 'titleEn': 'Fajr Prayer Alarm', 'titleAr': 'منبه صلاة الفجر'},
    {'id': 'alarm_dhuhr', 'titleBn': 'যোহরের নামাজ অ্যালার্ম', 'titleEn': 'Dhuhr Prayer Alarm', 'titleAr': 'منبه صلاة الظهر'},
    {'id': 'alarm_asr', 'titleBn': 'আসরের নামাজ অ্যালার্ম', 'titleEn': 'Asr Prayer Alarm', 'titleAr': 'منبه صلاة العصر'},
    {'id': 'alarm_maghrib', 'titleBn': 'মাগরিবের নামাজ অ্যালার্ম', 'titleEn': 'Maghrib Prayer Alarm', 'titleAr': 'منبه صلاة المغرب'},
    {'id': 'alarm_isha', 'titleBn': 'ইশার নামাজ অ্যালার্ম', 'titleEn': 'Isha Prayer Alarm', 'titleAr': 'منبه صلاة العشاء'},
  ];

  final List<Map<String, String>> amalNotifications = [
    {'id': 'notif_yasin', 'titleBn': 'সূরা ইয়াসিন তিলাওয়াত', 'titleEn': 'Surah Yasin Recitation', 'titleAr': 'قراءة سورة يس'},
    {'id': 'notif_morning_dhikr', 'titleBn': 'সকালবেলার জিকির ও আজকার', 'titleEn': 'Morning Adhkar', 'titleAr': 'أذكار الصباح'},
    {'id': 'notif_quran', 'titleBn': 'দৈনিক কুরআন তিলাওয়াত (২ পৃষ্ঠা)', 'titleEn': 'Daily Quran (2 Pages)', 'titleAr': 'تلاوة القرآن يومياً (صفحتان)'},
    {'id': 'notif_evening_dhikr', 'titleBn': 'বিকেলের জিকির ও আজকার', 'titleEn': 'Evening Adhkar', 'titleAr': 'أذكار المساء'},
    {'id': 'notif_waqiah', 'titleBn': 'সূরা ওয়াকিয়াহ তিলাওয়াত', 'titleEn': 'Surah Waqiah Recitation', 'titleAr': 'قراءة سورة الواقعة'},
    {'id': 'notif_mulk', 'titleBn': 'সূরা মুলক (ঘুমানোর পূর্বে)', 'titleEn': 'Surah Mulk (Before Bed)', 'titleAr': 'سورة الملك (قبل النوم)'},
    {'id': 'notif_muhasaba', 'titleBn': 'দিনের কাজের মুহাসাবা / হিসাব', 'titleEn': 'Daily Self-Evaluation', 'titleAr': 'محاسبة النفس اليومية'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAlarmSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshExactAlarmPermission();
    }
  }

  Future<void> _refreshExactAlarmPermission() async {
    final service = NotificationService.instance;
    final allowed = await service.canScheduleExactAlarms();
    if (!mounted) return;

    setState(() => _exactAlarmAllowed = allowed);

    if (allowed) {
      await _schedulePrayerAlarms();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final service = NotificationService.instance;
    await service.initialize();

    final now = DateTime.now();

    // আগের নির্ধারিত ইশরাক অ্যালার্ম সব অবস্থায় বাতিল।
    for (int day = 0; day < 7; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      final dayNumber = DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).difference(DateTime.utc(2020, 1, 1)).inDays;
      await service.cancelPrayerAlarm(dayNumber * 10 + 2);
    }

    if (_coords == null) return;

    final exactAllowed = await service.canScheduleExactAlarms();
    if (mounted) {
      setState(() => _exactAlarmAllowed = exactAllowed);
    }
    if (!exactAllowed) return;


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

        const alarmSlots = <String, int>{
          'alarm_tahajjud': 0,
          'alarm_fajr': 1,
          'alarm_dhuhr': 3,
          'alarm_asr': 4,
          'alarm_maghrib': 5,
          'alarm_isha': 6,
        };
        final notificationId = dayNumber * 10 + alarmSlots[id]!;

        await service.cancelPrayerAlarm(notificationId);
        if (!enabled) continue;

        DateTime? alarmTime;

        final supportsCustomMode =
            id != 'alarm_tahajjud';

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

        await service.schedulePrayerAlarm(
          id: notificationId,
          title: widget.language == 'ar'
              ? item['titleAr']!
              : (widget.language == 'en' ? item['titleEn']! : item['titleBn']!),
          dateTime: alarmTime,
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
        title: Text(_t('কত মিনিট যোগ করবেন?', 'Add how many minutes?', 'كم دقيقة تريد إضافتها؟'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _t('মিনিট', 'Minutes', 'دقائق'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('বাতিল', 'Cancel', 'إلغاء'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
          ),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n >= 0 && n <= 1440) {
                Navigator.pop(ctx, n);
              }
            },
            child: Text(_t('সংরক্ষণ', 'Save', 'حفظ'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
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

  void _playSystemAlarm() {
    _nativeAlarmChannel.invokeMethod<void>('startTestAlarm').catchError((e) {
      debugPrint('Test alarm start failed: $e');
    });
  }

  void _playSystemNotification() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('সিস্টেম নোটিফিকেশন সাউন্ড ও ভাইব্রেশন সক্রিয়!', 'System alert tone triggered!', 'تم تشغيل صوت تنبيه النظام والاهتزاز!'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr)),
    );
  }

  Future<void> _stopAlarm() async {
    try {
      await _nativeAlarmChannel.invokeMethod<void>('stopAlarm');
    } catch (e) {
      debugPrint('Alarm stop failed: $e');
    }
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('অ্যালার্ম ও নোটিফিকেশন', 'Alarms & Notifications', 'المنبهات والإشعارات'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      Text(_t('সিস্টেম এক্সেস ও অ্যালার্ম টেস্ট', 'System Access & Test', 'صلاحيات النظام واختبار المنبه'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('ওয়াক্ত অনুযায়ী সিস্টেম অ্যালার্ট ও ভাইব্রেশন নিশ্চিত করতে নিচের বাটন দিয়ে পরীক্ষা করুন.', 'Test system alert sound and hardware vibration for prayers.', 'اختبر صوت تنبيه النظام واهتزاز الجهاز لمواقيت الصلاة.'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  if (_exactAlarmAllowed == false) ...[
                    const SizedBox(height: 10),
                    Text(
                      'নির্দিষ্ট সময়ে নামাজের অ্যালার্ম পেতে Exact Alarm অনুমতি চালু করুন।',
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await NotificationService.instance
                              .openExactAlarmSettings();
                        },
                        icon: const Icon(Icons.settings),
                        label: Text(_t('Exact Alarm অনুমতি চালু করুন', 'Enable Exact Alarm permission', 'تفعيل إذن المنبه الدقيق'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                      ),
                    ),
                  ],
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
                          icon: const Icon(Icons.alarm, size: 18),
                          label: Text(_t('অ্যালার্ম বাজান', 'Test Alarm', 'اختبار المنبه'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                          onPressed: _playSystemAlarm,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D5C3A)),
                          icon: const Icon(Icons.notifications_active, size: 18),
                          label: Text(_t('নোটিফিকেশন', 'Test Tone', 'اختبار نغمة الإشعار'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
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

          Text(_t('নামাজের পূর্ণাঙ্গ অ্যালার্ম (Alarm System)', 'Prayer Alarms', 'منبهات الصلاة'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
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
                        widget.language == 'ar' ? (a['titleAr'] ?? a['titleEn']!) : (widget.isBn ? a['titleBn']! : a['titleEn']!),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: isSet,
                      activeColor: const Color(0xFF0D5C3A),
                      onChanged: (val) => _toggleAlarm(id, val),
                    ),
                    if (isSet && id != 'alarm_tahajjud') ...[
                      const Divider(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('অ্যালার্মের সময় নির্ধারণ', 'Alarm time setting', 'إعداد وقت المنبه'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
                                  child: Text(_t('ওয়াক্ত অনুযায়ী', 'Prayer time', 'حسب وقت الصلاة'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                                ),
                                DropdownMenuItem(
                                  value: 'delay',
                                  child: Text(_t('ওয়াক্তের পর মিনিট যোগ', 'Minutes after prayer', 'دقائق بعد الصلاة'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                                ),
                                DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text(_t('প্রতিদিন নির্দিষ্ট ঘড়ির সময়', 'Fixed daily clock time', 'وقت ثابت يومياً'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) _changeAlarmMode(id, value);
                              },
                            ),
                            if (mode == 'delay') ...[
                              const SizedBox(height: 12),
                              Text(_t('কত মিনিট পরে অ্যালার্ম বাজবে?', 'Delay after prayer', 'التأخير بعد الصلاة'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [0, 10, 15, 20, 30, 45, 60].map((m) {
                                  return ChoiceChip(
                                    label: Text('$m ${_t('মিনিট', 'min', 'دقيقة')}',
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
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
                                  _t('নিজের মতো মিনিট লিখুন (বর্তমান: $delay)', 'Custom minutes (current: $delay)', 'تحديد دقائق مخصصة (الحالي: $delay)'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                                ),
                              ),
                            ],
                            if (mode == 'fixed') ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _pickFixedTime(id),
                                icon: const Icon(Icons.access_time),
                                label: Text(
                                  '${_t('নির্দিষ্ট সময়', 'Fixed time', 'وقت محدد')}: ${fixedTime.format(context)}',
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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

          Text(_t('আমলের নোটিফিকেশন (Reminders)', 'Amal Reminders', 'تذكيرات الأعمال'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
          const SizedBox(height: 8),
          ...amalNotifications.map((n) {
            bool isSet = _notifications[n['id']] ?? true;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                secondary: Icon(isSet ? Icons.notifications_active : Icons.notifications_off, color: isSet ? Colors.teal : Colors.grey),
                title: Text(widget.language == 'ar' ? (n['titleAr'] ?? n['titleEn']!) : (widget.isBn ? n['titleBn']! : n['titleEn']!),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w500)),
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
