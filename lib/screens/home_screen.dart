import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../models/helpers.dart';

class HomeScreen extends StatefulWidget {
  final bool isBn;
  final String madhab;
  const HomeScreen({super.key, required this.isBn, required this.madhab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerTimes? prayerTimes;
  Timer? _timer;
  String _currentTime = '';
  String _countdown = '';
  String _nextPrayerName = '';
  int _completedAmols = 0;
  int _totalActiveAmols = 0;
  final String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, bool> _amolStatus = {};
  List<AmalItem> _currentAmals = [];
  Map<String, bool> _enabledAmols = {};

  @override
  void initState() {
    super.initState();
    _initTimes();
    _loadAllData();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initTimes() {
    final coords = Coordinates(23.8103, 90.4125);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = widget.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    prayerTimes = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final all = await AmalService.getAllAmals();
    int done = 0;
    int total = 0;
    Map<String, bool> status = {};
    Map<String, bool> enabled = {};

    for (var a in all) {
      bool isEnabled = a.isFard ? true : (prefs.getBool('enabled_${a.id}') ?? true);
      enabled[a.id] = isEnabled;
      bool isDone = prefs.getBool('${todayKey}_${a.id}') ?? false;
      status[a.id] = isDone;

      if (isEnabled) {
        total++;
        if (isDone) done++;
      }
    }

    if (mounted) {
      setState(() {
        _currentAmals = all;
        _amolStatus = status;
        _enabledAmols = enabled;
        _completedAmols = done;
        _totalActiveAmols = total;
      });
    }
  }

  Future<void> _toggleAmolFromHome(String id) async {
    if (_amolStatus[id] == true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${todayKey}_$id', true);
    _loadAllData();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      _currentTime = DateFormat('hh:mm:ss a').format(now);
      if (prayerTimes != null) {
        final nextPrayer = prayerTimes!.nextPrayer();
        DateTime? nextTime = prayerTimes!.timeForPrayer(nextPrayer);
        if (nextTime != null) {
          final diff = nextTime.difference(now);
          if (diff.isNegative) {
            _initTimes();
          } else {
            _nextPrayerName = _getPrayerName(nextPrayer);
            _countdown = '${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
          }
        }
      }
      if (timer.tick % 4 == 0) _loadAllData();
      if (mounted) setState(() {});
    });
  }

  String _getPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr: return widget.isBn ? 'ফজর' : 'Fajr';
      case Prayer.sunrise: return widget.isBn ? 'সূর্যোদয়' : 'Sunrise';
      case Prayer.dhuhr: return widget.isBn ? 'যোহর' : 'Dhuhr';
      case Prayer.asr: return widget.isBn ? 'আসর' : 'Asr';
      case Prayer.maghrib: return widget.isBn ? 'মাগরিব' : 'Maghrib';
      case Prayer.isha: return widget.isBn ? 'ইশা' : 'Isha';
      default: return widget.isBn ? 'তাহাজ্জুদ' : 'Tahajjud';
    }
  }

  List<AmalItem> _getRunningAmols() {
    if (prayerTimes == null) return [];
    DateTime now = DateTime.now();

    return _currentAmals.where((item) {
      if (!(_enabledAmols[item.id] ?? true)) return false;
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
      DateTime gracePeriod = end.add(const Duration(minutes: 10));
      return now.isAfter(start) && now.isBefore(gracePeriod);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    double percent = _totalActiveAmols == 0 ? 0 : (_completedAmols / _totalActiveAmols);
    int percentInt = (percent * 100).toInt();
    List<AmalItem> runningAmols = _getRunningAmols();
    String hijriDate = HijriService.getHijriDate(now, widget.isBn);
    String hijriNote = HijriService.getHijriNote(widget.isBn);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'দৈনন্দিন আমল' : 'Dainik Amal', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { _initTimes(); _loadAllData(); })
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // তারিখ কার্ড (হিজরি তারিখ ও নিচে চাঁদ দেখার নোট)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                        Text(DateFormat('EEEE, d MMMM yyyy').format(now), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // হিজরি তারিখ (লাইন ১: তারিখ, লাইন ২: চাঁদ দেখার উপর নির্ভরশীল)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.mosque, size: 20, color: Color(0xFF0D5C3A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(hijriDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A), fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('($hijriNote)', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 18, color: Colors.deepOrange),
                        Text(BanglaDateHelper.format(now), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_filled, color: Color(0xFF0D5C3A), size: 20),
                      const SizedBox(width: 8),
                      Text(_currentTime, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // আমলের লাইভ অগ্রগতি বার
          Card(
            color: const Color(0xFFE8F5E9),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.isBn ? 'আমলের অগ্রগতি' : 'Amal Progress', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D5C3A))),
                      Text('$_completedAmols/$_totalActiveAmols ${widget.isBn ? "সম্পন্ন" : "Done"} — $percentInt%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: percent.clamp(0.0, 1.0), minHeight: 8, borderRadius: BorderRadius.circular(5), color: const Color(0xFF0D5C3A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // বর্তমান সময়ের রানিং আমল
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.green, size: 22),
                          const SizedBox(width: 6),
                          Text(widget.isBn ? 'বর্তমান সময়ের সক্রিয় আমল (Running)' : 'Active Amals (Running)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D5C3A))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Text('${runningAmols.length} ${widget.isBn ? "টি সক্রিয়" : "Active"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (runningAmols.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(widget.isBn ? 'এই মুহূর্তে কোনো নির্দিষ্ট ওয়াক্তের আমল রানিং নেই।' : 'No active amals at this moment.', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    )
                  else
                    ...runningAmols.map((a) {
                      bool isDone = _amolStatus[a.id] ?? false;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(a.isFard ? Icons.star_rounded : Icons.check_circle_outline, color: a.isFard ? Colors.deepOrange : const Color(0xFF0D5C3A)),
                        title: Text(widget.isBn ? a.titleBn : a.titleEn, style: TextStyle(fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null)),
                        subtitle: Text(widget.isBn ? a.categoryBn : a.categoryEn, style: const TextStyle(fontSize: 12)),
                        trailing: isDone
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(widget.isBn ? 'সম্পন্ন ' : 'Done ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const Icon(Icons.lock, color: Colors.green, size: 16),
                                ],
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                onPressed: () => _toggleAmolFromHome(a.id),
                                child: Text(widget.isBn ? 'টিক দিন' : 'Check'),
                              ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // কাউন্টডাউন
          Card(
            color: const Color(0xFF0D5C3A),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.isBn ? 'পরবর্তী নামাজ' : 'Next Prayer', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_nextPrayerName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(widget.isBn ? 'বাকি সময়' : 'Time Left', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_countdown.isEmpty ? '--:--:--' : _countdown, style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // নামাজের সময়
          if (prayerTimes != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.isBn ? 'নামাজের সময়' : 'Prayer Times', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                    const Divider(height: 18),
                    _timeRow(widget.isBn ? 'সাহরীর শেষ সময়' : 'Suhoor Ends', prayerTimes!.fajr.subtract(const Duration(minutes: 10))),
                    _timeRow(widget.isBn ? 'ফজর' : 'Fajr', prayerTimes!.fajr),
                    _timeRow(widget.isBn ? 'সূর্যোদয়' : 'Sunrise', prayerTimes!.sunrise),
                    _timeRow(widget.isBn ? 'যোহর' : 'Dhuhr', prayerTimes!.dhuhr),
                    _timeRow(widget.isBn ? 'আসর' : 'Asr', prayerTimes!.asr),
                    _timeRow(widget.isBn ? 'সূর্যাস্ত ও মাগরিব' : 'Sunset & Maghrib', prayerTimes!.maghrib),
                    _timeRow(widget.isBn ? 'ইশা' : 'Isha', prayerTimes!.isha),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeRow(String title, DateTime time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          Text(DateFormat('hh:mm a').format(time), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
