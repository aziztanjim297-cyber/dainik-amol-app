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
  String _hijriDate = 'লোড হচ্ছে...';
  int _completedAmols = 0;
  int _totalAmols = 18;

  @override
  void initState() {
    super.initState();
    _initTimes();
    _fetchHijri();
    _loadProgress();
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

  Future<void> _fetchHijri() async {
    String h = await HijriService.getHijriDate(DateTime.now());
    if (mounted) setState(() => _hijriDate = h);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int done = 0;
    Set<String> keys = prefs.getKeys();
    for (String k in keys) {
      if (k.startsWith(todayKey) && prefs.getBool(k) == true) {
        done++;
      }
    }
    if (mounted) setState(() => _completedAmols = done);
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    double percent = _totalAmols == 0 ? 0 : (_completedAmols / _totalAmols);
    int percentInt = (percent * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'দৈনন্দিন আমল' : 'Dainik Amal', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { _initTimes(); _loadProgress(); })
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ১. রঙিন আলাদা আলাদা তারিখ ও রিয়েলটাইম ঘড়ি
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                        Text(DateFormat('EEEE, d MMMM yyyy').format(now), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.mosque, size: 18, color: Color(0xFF0D5C3A)),
                        Text(_hijriDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A), fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 18, color: Colors.deepOrange),
                        Text(BanglaDateHelper.format(now), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 14)),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
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
          const SizedBox(height: 14),

          // ৪. আমলের অগ্রগতি (Progress Bar)
          Card(
            color: const Color(0xFFE8F5E9),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.isBn ? 'আমলের অগ্রগতি' : 'Amal Progress', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D5C3A))),
                      Text('$_completedAmols/$_totalAmols সম্পন্ন — $percentInt%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: percent.clamp(0.0, 1.0), minHeight: 9, borderRadius: BorderRadius.circular(5), color: const Color(0xFF0D5C3A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // কাউন্টডাউন কার্ড
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

          // ৩. নামাজের সময় (কোনো মাজহাবের নাম ছাড়া সাধারণ শিরোনাম)
          if (prayerTimes != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('নামাজের সময়', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D5C3A))),
                    const Divider(height: 18),
                    _timeRow('সাহরীর শেষ সময়', prayerTimes!.fajr.subtract(const Duration(minutes: 10))),
                    _timeRow('ফজর', prayerTimes!.fajr),
                    _timeRow('সূর্যোদয়', prayerTimes!.sunrise),
                    _timeRow('যোহর', prayerTimes!.dhuhr),
                    _timeRow('আসর', prayerTimes!.asr),
                    _timeRow('সূর্যাস্ত ও মাগরিব', prayerTimes!.maghrib),
                    _timeRow('ইশা', prayerTimes!.isha),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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
