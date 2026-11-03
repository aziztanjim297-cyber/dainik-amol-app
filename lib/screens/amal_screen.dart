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
  const AmalListScreen({super.key, required this.isBn, required this.madhab});

  @override
  State<AmalListScreen> createState() => _AmalListScreenState();
}

class _AmalListScreenState extends State<AmalListScreen> {
  final String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _customTitleController.dispose();
    super.dispose();
  }

  void _initTimes() {
    final coords = Coordinates(23.8103, 90.4125);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = widget.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    prayerTimes = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
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
    if (amolStatus[id] == true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${todayKey}_$id', true);
    await NotificationService.instance.cancelAmalReminders(id);
    if (!mounted) return;
    setState(() => amolStatus[id] = true);
  }

  // নতুন আমল যোগ ও ঐচ্ছিক আমল কাস্টমাইজেশন ডায়ালগ
  void _openCustomizationDialog() {
    showModalBottomSheet(
      context: context,
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
                  Text(widget.isBn ? 'আমল কাস্টমাইজ ও নতুন আমল যোগ' : 'Customize & Add Amals', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),

              // নতুন আমল যোগ করার ফর্ম
              Card(
                color: const Color(0xFFF1F8F5),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.isBn ? '+ নিজের নতুন আমল যুক্ত করুন' : '+ Add Custom Amal', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customTitleController,
                        decoration: InputDecoration(
                          hintText: widget.isBn ? 'আমলের নাম লিখুন (যেমন: ৪ রাকাত চাশত)' : 'Enter amal title',
                          filled: true,
                          fillColor: Colors.white,
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
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), border: OutlineInputBorder()),
                              items: [
                                DropdownMenuItem(value: 'tahajjud', child: Text(widget.isBn ? 'তাহাজ্জুদ সময়' : 'Tahajjud')),
                                DropdownMenuItem(value: 'fajr', child: Text(widget.isBn ? 'ফজর সময়' : 'Fajr')),
                                DropdownMenuItem(value: 'post_fajr', child: Text(widget.isBn ? 'সকাল/ইশরাক' : 'Morning/Ishraq')),
                                DropdownMenuItem(value: 'dhuhr', child: Text(widget.isBn ? 'যোহর সময়' : 'Dhuhr')),
                                DropdownMenuItem(value: 'asr', child: Text(widget.isBn ? 'আসর সময়' : 'Asr')),
                                DropdownMenuItem(value: 'maghrib', child: Text(widget.isBn ? 'মাগরিব সময়' : 'Maghrib')),
                                DropdownMenuItem(value: 'isha', child: Text(widget.isBn ? 'ইশা সময়' : 'Isha')),
                                DropdownMenuItem(value: 'bedtime', child: Text(widget.isBn ? 'ঘুমানোর সময়' : 'Bedtime')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _selectedPrayerCategory = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
                            onPressed: () async {
                              if (_customTitleController.text.trim().isNotEmpty) {
                                String title = _customTitleController.text.trim();
                                await AmalService.addCustomAmal(title, _selectedPrayerCategory, widget.isBn ? 'কাস্টম আমল' : 'Custom');
                                _customTitleController.clear();
                                await _loadAmolData();
                                await _refreshAmalReminders();
                                setModalState(() {});
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isBn ? 'নতুন আমল সফলভাবে যুক্ত হয়েছে!' : 'New amal added!')));
                              }
                            },
                            child: Text(widget.isBn ? 'যোগ করুন' : 'Add'),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(widget.isBn ? 'আমল তালিকা (চালু / বন্ধ করুন):' : 'Amal List (Enable / Disable):', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),

              Expanded(
                child: ListView(
                  children: allAmals.map((a) {
                    bool isEnabled = enabledAmols[a.id] ?? true;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        dense: true,
                        title: Text(widget.isBn ? a.titleBn : a.titleEn, style: TextStyle(fontWeight: FontWeight.w600, color: a.isFard ? Colors.black87 : null)),
                        subtitle: Text(a.isFard ? (widget.isBn ? 'ফরজ (বাদ দেওয়া যাবে না)' : 'Fard (Mandatory)') : (a.isCustom ? (widget.isBn ? 'আপনার কাস্টম আমল' : 'Custom') : (widget.isBn ? 'ঐচ্ছিক' : 'Optional'))),
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
    if (prayerTimes == null) return {'status': 'running', 'label': widget.isBn ? 'চলমান' : 'Running', 'color': Colors.green, 'canCheck': true};
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
      return {'status': 'upcoming', 'label': widget.isBn ? 'Upcoming' : 'Upcoming', 'color': Colors.blueGrey, 'canCheck': false};
    } else if (now.isAfter(start) && now.isBefore(end)) {
      return {'status': 'running', 'label': widget.isBn ? 'Running' : 'Running', 'color': Colors.green, 'canCheck': true};
    } else if (now.isAfter(end) && now.isBefore(gracePeriodEnd)) {
      return {'status': 'just_passed', 'label': widget.isBn ? 'Just Passed (১০ মি.)' : 'Just Passed (10m)', 'color': Colors.deepOrange, 'canCheck': true};
    } else {
      return {'status': 'past', 'label': widget.isBn ? 'Past' : 'Past', 'color': Colors.red, 'canCheck': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAmals = allAmals.where((a) => enabledAmols[a.id] ?? true).toList();
    int completedCount = activeAmals.where((a) => amolStatus[a.id] == true).length;
    double progress = activeAmals.isEmpty ? 0 : completedCount / activeAmals.length;
    int percent = (progress * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'দৈনন্দিন আমল তালিকা' : 'Daily Amal Checklist', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: widget.isBn ? 'আমল কাস্টমাইজ' : 'Customize Amals',
            onPressed: _openCustomizationDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        onPressed: _openCustomizationDialog,
        icon: const Icon(Icons.add_task),
        label: Text(widget.isBn ? 'আমল কাস্টমাইজ ও নতুন আমল' : 'Customize & Add Amals'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
        children: [
          Card(
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.isBn ? "অগ্রগতি" : "Progress"}: $completedCount/${activeAmals.length} ${widget.isBn ? "সম্পন্ন" : "Done"} — $percent%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                  const Icon(Icons.check_circle, color: Color(0xFF0D5C3A)),
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
                color: isDone ? Colors.green.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDone ? Colors.green : (item.isFard ? Colors.deepOrange.shade300 : Colors.grey.shade300), width: item.isFard ? 1.5 : 1.0),
              ),
              child: ListTile(
                leading: Icon(
                  item.isFard ? Icons.star_rounded : (item.isCustom ? Icons.bookmark_added : Icons.radio_button_checked),
                  color: item.isFard ? Colors.deepOrange : const Color(0xFF0D5C3A),
                ),
                title: Text(widget.isBn ? item.titleBn : item.titleEn, style: TextStyle(fontWeight: FontWeight.w600, decoration: isDone ? TextDecoration.lineThrough : null)),
                subtitle: Row(
                  children: [
                    Text(widget.isBn ? item.categoryBn : item.categoryEn, style: const TextStyle(fontSize: 12)),
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
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.isBn ? 'লক ' : 'Locked ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          const Icon(Icons.lock, color: Colors.green, size: 18),
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
                            child: Text(widget.isBn ? 'টিক দিন' : 'Check'),
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
