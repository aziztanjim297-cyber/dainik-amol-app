cat << 'EOF' > lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../models/helpers.dart';
import '../models/history_service.dart';
import 'alarm_screen.dart';
import 'summary_screen.dart';

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
  String _activeDateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, bool> _amolStatus = {};
  List<AmalItem> _currentAmals = [];
  Map<String, bool> _enabledAmols = {};

  final Coordinates _coords = Coordinates(23.8103, 90.4125);

  @override
  void initState() {
    super.initState();
    _initTimes();
    HistoryService.checkAndAutoArchive(); // রাত ১২টার পূর্ববর্তী হিসাব সংরক্ষণ
    _loadAllData();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  CalculationParameters _getParams() {
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = widget.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    return params;
  }

  void _initTimes() {
    prayerTimes = PrayerTimes(_coords, DateComponents.from(DateTime.now()), _getParams());
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final all = await AmalService.getAllAmals();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _activeDateKey = today;

    int done = 0;
    int total = 0;
    Map<String, bool> status = {};
    Map<String, bool> enabled = {};

    for (var a in all) {
      bool isEnabled = a.isFard ? true : (prefs.getBool('enabled_${a.id}') ?? true);
      enabled[a.id] = isEnabled;
      bool isDone = prefs.getBool('${today}_${a.id}') ?? false;
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

    HistoryService.saveTodayRecord(
      totalAmols: total,
      completedAmols: done,
      zikrCounts: {},
      amolStatus: status,
    );
  }

  Future<void> _toggleAmolFromHome(String id) async {
    if (_amolStatus[id] == true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_activeDateKey}_$id', true);
    _loadAllData();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      _currentTime = DateFormat('hh:mm:ss a').format(now);
      final currentFormattedDate = DateFormat('yyyy-MM-dd').format(now);

      // রাত ১২:০০ টা বাজার সাথে সাথে নতুন দিনের অটো-রিসেট ও আর্কাইভ ট্রিগার
      if (_activeDateKey != currentFormattedDate) {
        HistoryService.checkAndAutoArchive();
        _initTimes();
        _loadAllData();
      }

      if (prayerTimes != null) {
        final nextPrayer = prayerTimes!.nextPrayer();
        DateTime? nextTime;
        String nextName = '';

        if (nextPrayer == Prayer.none || nextPrayer == Prayer.fajr && now.isAfter(prayerTimes!.isha)) {
          final tomorrow = now.add(const Duration(days: 1));
          final tomorrowPrayerTimes = PrayerTimes(_coords, DateComponents.from(tomorrow), _getParams());
          nextTime = tomorrowPrayerTimes.fajr;
          nextName = widget.isBn ? 'ফজর (পরের দিন)' : 'Fajr (Tomorrow)';
        } else {
          nextTime = prayerTimes!.timeForPrayer(nextPrayer);
          nextName = _getPrayerName(nextPrayer);
        }

        if (nextTime != null) {
          final diff = nextTime.difference(now);
          if (diff.isNegative) {
            _initTimes();
          } else {
            _nextPrayerName = nextName;
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
      default: return widget.isBn ? 'ফজর' : 'Fajr';
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
