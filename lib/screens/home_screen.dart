import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import '../models/helpers.dart';

class HomeScreen extends StatefulWidget {
  final bool isBn;
  final int hijriAdj;
  const HomeScreen({super.key, required this.isBn, required this.hijriAdj});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerTimes? prayerTimes;
  Timer? _timer;
  String _countdown = '';
  String _nextPrayerName = '';

  @override
  void initState() {
    super.initState();
    _initTimes();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initTimes() {
    final coords = Coordinates(23.8103, 90.4125);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    prayerTimes = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
  }

  void _startCountdownTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (prayerTimes == null) return;
      final now = DateTime.now();
      final nextPrayer = prayerTimes!.nextPrayer();
      DateTime? nextTime = prayerTimes!.timeForPrayer(nextPrayer);
      if (nextTime != null) {
        final diff = nextTime.difference(now);
        if (diff.isNegative) {
          _initTimes();
        } else {
          setState(() {
            _nextPrayerName = _getPrayerName(nextPrayer);
            _countdown = '${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
          });
        }
      }
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
    final hijri = HijriCalendar.now();
    if (widget.hijriAdj != 0) hijri.hDay += widget.hijriAdj;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'দৈনন্দিন আমল' : 'Dainik Amal', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(DateFormat('EEEE, d MMMM yyyy').format(now), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${hijri.hDay} ${hijri.longMonthName}, ${hijri.hYear} হিজরি', style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(BanglaDateHelper.format(now), style: const TextStyle(color: Color(0xFF0D5C3A), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF0D5C3A),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.isBn ? 'পরবর্তী নামাজ' : 'Next Prayer', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(_nextPrayerName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(widget.isBn ? 'কাউন্টডাউন' : 'Remaining Time', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(_countdown.isEmpty ? '--:--:--' : _countdown, style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (prayerTimes != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.isBn ? 'নামাজের পূর্ণাঙ্গ সময়সূচি (হানাফি)' : 'Prayer Timetable (Hanafi)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D5C3A))),
                    const Divider(height: 20),
                    _timeRow(widget.isBn ? 'সাহরীর শেষ সময়' : 'Suhoor Ends', prayerTimes!.fajr.subtract(const Duration(minutes: 10))),
                    _timeRow(widget.isBn ? 'ফজর' : 'Fajr', prayerTimes!.fajr),
                    _timeRow(widget.isBn ? 'সূর্যোদয়' : 'Sunrise', prayerTimes!.sunrise),
                    _timeRow(widget.isBn ? 'যোহর' : 'Dhuhr', prayerTimes!.dhuhr),
                    _timeRow(widget.isBn ? 'আসর (হানাফি)' : 'Asr (Hanafi)', prayerTimes!.asr),
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
