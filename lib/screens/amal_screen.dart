import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../models/helpers.dart';
import '../services/notification_service.dart';

class AmalListScreen extends StatefulWidget {
  final bool isBn;
  final String madhab;
  final VoidCallback onAmalCompleted;
  final String language;
  const AmalListScreen({
    super.key,
    required this.isBn,
    required this.madhab,
    required this.onAmalCompleted,
    String? language,
  }) : language = language ?? (isBn ? 'bn' : 'en');

  @override
  State<AmalListScreen> createState() => _AmalListScreenState();
}

class _AmalListScreenState extends State<AmalListScreen> {
  String _t(String bn, String en, String ar) =>
      widget.language == 'ar' ? ar : (widget.isBn ? bn : en);

  String _amalTitle(AmalItem item) {
    if (widget.language == 'ar') {
      return item.titleAr.isNotEmpty ? item.titleAr : item.titleEn;
    }
    return widget.isBn ? item.titleBn : item.titleEn;
  }

  String _amalCategory(AmalItem item) {
    if (widget.language == 'ar') {
      return item.categoryAr.isNotEmpty ? item.categoryAr : item.categoryEn;
    }
    return widget.isBn ? item.categoryBn : item.categoryEn;
  }

  ui.TextDirection get _textDirection =>
      widget.language == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr;

  String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, bool> amolStatus = {};
  Map<String, bool> enabledAmols = {};
  List<AmalItem> allAmals = [];
  PrayerTimes? prayerTimes;
  Timer? _refreshTimer;

  final TextEditingController _customTitleController = TextEditingController();
  String _selectedPrayerCategory = 'fajr';

  @override
  void initState() {
    super.initState();
    _initTimes();
    _loadAmolData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final newTodayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (newTodayKey != todayKey) {
        todayKey = newTodayKey;
        _initTimes();
        _loadAmolData();
        _refreshAmalReminders();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _customTitleController.dispose();
    super.dispose();
  }

  Future<void> _initTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('location_lat');
    final lon = prefs.getDouble('location_lon');

    final coords = (lat != null && lon != null)
        ? Coordinates(lat, lon)
        : Coordinates(23.8103, 90.4125);

    final params = CalculationMethod.karachi.getParameters();
    params.madhab = widget.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

    final updatedTimes = PrayerTimes(
      coords,
      DateComponents.from(DateTime.now()),
      params,
    );

    if (!mounted) return;
    setState(() {
      prayerTimes = updatedTimes;
    });
  }

  Future<void> _loadAmolData() async {
    final prefs = await SharedPreferences.getInstance();
    final amals = await AmalService.getAllAmals();
    Map<String, bool> status = {};
    Map<String, bool> enabled = {};

    for (var a in amals) {
      status[a.id] = prefs.getBool('${todayKey}_${a.id}') ?? false;
      enabled[a.id] = a.isFard ? true : (prefs.getBool('enabled_${a.id}') ?? true);
    }

    if (mounted) {
      setState(() {
        allAmals = amals;
        amolStatus = status;
        enabledAmols = enabled;
      });
    }
  }

  Future<void> _refreshAmalReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('location_lat');
    final lon = prefs.getDouble('location_lon');
    if (lat == null || lon == null) return;

    await NotificationService.instance.scheduleAmalReminders(
      coords: Coordinates(lat, lon),
      madhab: widget.madhab,
    );
  }

  Future<void> _toggleAmol(String id) async {
    if (amolStatus[id] == true || prayerTimes == null) return;

    final item = allAmals.firstWhere(
      (amal) => amal.id == id,
      orElse: () => allAmals.first,
    );
    if (_getAmolStatus(item)['canCheck'] != true) return;

    final dateKey = todayKey;
    final prefs = await SharedPreferences.getInstance();

    if (!mounted || dateKey != todayKey) return;
    if (_getAmolStatus(item)['canCheck'] != true) return;

    await prefs.setBool('${dateKey}_$id', true);
    await NotificationService.instance.cancelAmalReminders(id);

    if (!mounted || dateKey != todayKey) return;
    setState(() => amolStatus[id] = true);
    widget.onAmalCompleted();
  }

  // নতুন আমল যোগ ও ঐচ্ছিক আমল কাস্টমাইজেশন ডায়ালগ
  void _openCustomizationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2923) : null,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_t('আমল কাস্টমাইজ ও নতুন আমল যোগ', 'Customize & Add Amals', 'تخصيص الأعمال وإضافة عمل جديد'), textDirection: _textDirection, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF80D6A8) : const Color(0xFF0D5C3A))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),

              // নতুন আমল যোগ করার ফর্ম
              Card(
                color: isDark ? const Color(0xFF26352D) : const Color(0xFFF1F8F5),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('+ নিজের নতুন আমল যুক্ত করুন', '+ Add Custom Amal', '+ أضف عملاً مخصصاً'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF80D6A8) : const Color(0xFF0D5C3A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customTitleController,
                        style: TextStyle(color: isDark ? Colors.white : null),
                        decoration: InputDecoration(
                          hintText: _t('আমলের নাম লিখুন (যেমন: ৪ রাকাত চাশত)', 'Enter amal title', 'أدخل اسم العمل'),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF18221D) : Colors.white,
                          hintStyle: TextStyle(color: isDark ? Colors.white54 : null),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedPrayerCategory,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                filled: isDark,
                                fillColor: isDark ? const Color(0xFF18221D) : null,
                                border: const OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF80D6A8) : const Color(0xFF0D5C3A),
                                  ),
                                ),
                              ),
                              style: TextStyle(color: isDark ? Colors.white : null),
                              items: [
                                DropdownMenuItem(value: 'tahajjud', child: Text(_t('তাহাজ্জুদ সময়', 'Tahajjud', 'وقت التهجد'))),
                                DropdownMenuItem(value: 'fajr', child: Text(_t('ফজর সময়', 'Fajr', 'وقت الفجر'))),
                                DropdownMenuItem(value: 'post_fajr', child: Text(_t('সকাল/ইশরাক', 'Morning/Ishraq', 'الصباح / الإشراق'))),
                                DropdownMenuItem(value: 'dhuhr', child: Text(_t('যোহর সময়', 'Dhuhr', 'وقت الظهر'))),
                                DropdownMenuItem(value: 'asr', child: Text(_t('আসর সময়', 'Asr', 'وقت العصر'))),
                                DropdownMenuItem(value: 'maghrib', child: Text(_t('মাগরিব সময়', 'Maghrib', 'وقت المغرب'))),
                                DropdownMenuItem(value: 'isha', child: Text(_t('ইশা সময়', 'Isha', 'وقت العشاء'))),
                                DropdownMenuItem(value: 'bedtime', child: Text(_t('ঘুমানোর সময়', 'Bedtime', 'وقت النوم'))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _selectedPrayerCategory = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF1B8E5B) : const Color(0xFF0D5C3A),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (_customTitleController.text.trim().isNotEmpty) {
                                String title = _customTitleController.text.trim();
                                await AmalService.addCustomAmal(title, _selectedPrayerCategory, _t('কাস্টম আমল', 'Custom', 'عمل مخصص'));
                                _customTitleController.clear();
                                await _loadAmolData();
                                await _refreshAmalReminders();
                                setModalState(() {});
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('নতুন আমল সফলভাবে যুক্ত হয়েছে!', 'New amal added!', 'تمت إضافة العمل الجديد بنجاح!'))));
                              }
                            },
                            child: Text(_t('যোগ করুন', 'Add', 'إضافة')),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(_t('আমল তালিকা (চালু / বন্ধ করুন):', 'Amal List (Enable / Disable):', 'قائمة الأعمال (تفعيل / تعطيل):'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),

              Expanded(
                child: ListView(
                  children: allAmals.map((a) {
                    bool isEnabled = enabledAmols[a.id] ?? true;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2923) : null,
                        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(_amalTitle(a), textDirection: _textDirection, style: TextStyle(fontWeight: FontWeight.w600, color: a.isFard ? (isDark ? Colors.white : Colors.black87) : null)),
                        subtitle: Text(a.isFard ? (_t('ফরজ (বাদ দেওয়া যাবে না)', 'Fard (Mandatory)', 'فرض (لا يمكن تعطيله)')) : (a.isCustom ? (_t('আপনার কাস্টম আমল', 'Custom', 'عمل مخصص')) : (_t('ঐচ্ছিক', 'Optional', 'اختياري'))), textDirection: _textDirection),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (a.isCustom)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  await NotificationService.instance.cancelAmalReminders(a.id, allDays: true);
                                  await AmalService.deleteCustomAmal(a.id);
                                  await _refreshAmalReminders();
                                  await _loadAmolData();
                                  setModalState(() {});
                                  setState(() {});
                                },
                              ),
                            Switch(
                              value: isEnabled,
                              activeColor: const Color(0xFF0D5C3A),
                              onChanged: a.isFard ? null : (val) async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('enabled_${a.id}', val);
                                if (!val) {
                                  await NotificationService.instance.cancelAmalReminders(a.id, allDays: true);
                                } else {
                                  await _refreshAmalReminders();
                                }
                                setModalState(() => enabledAmols[a.id] = val);
                                setState(() => enabledAmols[a.id] = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getAmolStatus(AmalItem item) {
    if (prayerTimes == null) {
      return {
        'status': 'upcoming',
        'label': _t('সময় নির্ধারণ হচ্ছে', 'Calculating time', 'جارٍ تحديد الوقت'),
        'color': Colors.blueGrey,
        'canCheck': false,
      };
    }

    final now = DateTime.now();
    DateTime start = now;
    DateTime end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    final isMidnightLocked = item.id == 'surah_mulk' ||
        item.id == 'muhasabah' ||
        item.prayerName == 'isha' ||
        item.prayerName == 'bedtime';

    switch (item.id) {
      case 'surah_mulk':
        start = DateTime(now.year, now.month, now.day, 20, 0);
        break;
      case 'muhasabah':
        start = DateTime(now.year, now.month, now.day, 21, 30);
        break;
      default:
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
            break;
        }
    }

    if (isMidnightLocked) {
      end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    }

    final gracePeriodEnd = end.add(const Duration(minutes: 10));

    if (now.isBefore(start)) {
      return {'status': 'upcoming', 'label': _t('আসন্ন', 'Upcoming', 'قادم'), 'color': Colors.blueGrey, 'canCheck': false};
    } else if (now.isBefore(end)) {
      return {'status': 'running', 'label': _t('চলমান', 'Running', 'جارٍ'), 'color': Colors.green, 'canCheck': true};
    } else if (!isMidnightLocked && now.isBefore(gracePeriodEnd)) {
      return {'status': 'just_passed', 'label': _t('এইমাত্র শেষ (১০ মি.)', 'Just Passed (10m)', 'انتهى للتو (١٠ دقائق)'), 'color': Colors.deepOrange, 'canCheck': true};
    } else {
      return {'status': 'past', 'label': _t('সময় শেষ', 'Past', 'انتهى الوقت'), 'color': Colors.red, 'canCheck': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeAmals = allAmals.where((a) => enabledAmols[a.id] ?? true).toList();
    int completedCount = activeAmals.where((a) => amolStatus[a.id] == true).length;
    double progress = activeAmals.isEmpty ? 0 : completedCount / activeAmals.length;
    int percent = (progress * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('দৈনন্দিন আমল তালিকা', 'Daily Amal Checklist', 'قائمة الأعمال اليومية'), textDirection: _textDirection, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: _t('আমল কাস্টমাইজ', 'Customize Amals', 'تخصيص الأعمال'),
            onPressed: _openCustomizationDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? const Color(0xFF1B8E5B) : const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        onPressed: _openCustomizationDialog,
        icon: const Icon(Icons.add_task),
        label: Text(_t('আমল কাস্টমাইজ ও নতুন আমল', 'Customize & Add Amals', 'تخصيص الأعمال وإضافة عمل')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
        children: [
          Card(
            color: isDark ? const Color(0xFF26352D) : const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_t('অগ্রগতি', 'Progress', 'التقدم')}: $completedCount/${activeAmals.length} ${_t('সম্পন্ন', 'Done', 'مكتمل')} — $percent%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFF80D6A8) : const Color(0xFF0D5C3A))),
                  Icon(Icons.check_circle, color: isDark ? const Color(0xFF80D6A8) : const Color(0xFF0D5C3A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...activeAmals.map((item) {
            bool isDone = amolStatus[item.id] ?? false;
            var st = _getAmolStatus(item);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? (isDone ? const Color(0xFF203A2C) : const Color(0xFF1E2923))
                    : (isDone ? Colors.green.shade50 : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDone
                    ? (isDark ? const Color(0xFF66BB8A) : Colors.green)
                    : (item.isFard
                        ? Colors.deepOrange.shade300
                        : (isDark ? Colors.white24 : Colors.grey.shade300)), width: item.isFard ? 1.5 : 1.0),
              ),
              child: ListTile(
                leading: Icon(
                  item.isFard ? Icons.star_rounded : (item.isCustom ? Icons.bookmark_added : Icons.radio_button_checked),
                  color: item.isFard ? Colors.deepOrange : (isDark ? const Color(0xFF80D6A8) : const Color(0xFF0D5C3A)),
                ),
                title: Text(_amalTitle(item), textDirection: _textDirection, style: TextStyle(fontWeight: FontWeight.w600, decoration: isDone ? TextDecoration.lineThrough : null)),
                subtitle: Row(
                  children: [
                    Text(_amalCategory(item), textDirection: _textDirection, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if (!isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: (st['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(st['label'], textDirection: _textDirection, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: st['color'])),
                      ),
                  ],
                ),
                trailing: isDone
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_t('লক ', 'Locked ', 'مقفل '), style: TextStyle(color: isDark ? const Color(0xFF80D6A8) : Colors.green, fontWeight: FontWeight.bold)),
                          Icon(Icons.lock, color: isDark ? const Color(0xFF80D6A8) : Colors.green, size: 18),
                        ],
                      )
                    : (st['canCheck'] == true
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: st['status'] == 'just_passed' ? Colors.deepOrange : (isDark ? const Color(0xFF1B8E5B) : const Color(0xFF0D5C3A)),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => _toggleAmol(item.id),
                            child: Text(_t('টিক দিন', 'Check', 'تحديد')),
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
