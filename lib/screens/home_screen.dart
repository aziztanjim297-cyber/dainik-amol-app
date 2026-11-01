import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import '../models/helpers.dart';
import '../models/history_service.dart';
import 'alarm_screen.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isBn;
  final String madhab;

  const HomeScreen({
    super.key,
    required this.isBn,
    required this.madhab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerTimes? prayerTimes;
  Timer? _timer;
  String _currentTime = '';
  String _countdown = '';
  String _nextPrayerName = '';
  String _locationMessage = '';

  int _completedAmols = 0;
  int _totalActiveAmols = 0;

  String _activeDateKey =
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<String, bool> _amolStatus = {};
  List<AmalItem> _currentAmals = [];
  Map<String, bool> _enabledAmols = {};

  Coordinates? _coords;

  bool _loadingData = false;
  bool _dateChangeProcessing = false;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeData();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _setLocationFallback(
          widget.isBn
              ? 'লোকেশন সার্ভিস বন্ধ'
              : 'Location service is disabled',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setLocationFallback(
          widget.isBn
              ? 'লোকেশন অনুমতি পাওয়া যায়নি'
              : 'Location permission denied',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (!mounted) return;

      setState(() {
        _coords = Coordinates(
          position.latitude,
          position.longitude,
        );
        _locationMessage =
            widget.isBn ? 'বর্তমান অবস্থান ব্যবহার হচ্ছে' : 'Using current location';
        _loadingLocation = false;
      });

      _initTimes();
    } catch (e) {
      _setLocationFallback(
        widget.isBn
            ? 'লোকেশন পাওয়া যায়নি'
            : 'Unable to get location',
      );
    }
  }

  void _setLocationFallback(String message) {
    if (!mounted) return;

    setState(() {
      _coords = Coordinates(22.3596, 90.3298);
      _locationMessage = message;
      _loadingLocation = false;
    });

    _initTimes();
  }

  CalculationParameters _getParams() {
    final params = CalculationMethod.karachi.getParameters();
    params.madhab =
        widget.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    return params;
  }

  void _initTimes() {
    if (_coords == null) return;

    prayerTimes = PrayerTimes(
      _coords!,
      DateComponents.from(DateTime.now()),
      _getParams(),
    );
  }

  Future<void> _initializeData() async {
    await HistoryService.checkAndAutoArchive();
    await _loadAllData();
  }
  Future<void> _loadAllData() async {
    if (_loadingData) return;
    _loadingData = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      final amals = await AmalService.getAllAmals();
      final enabled = <String, bool>{};
      final status = <String, bool>{};

      for (final amal in amals) {
        enabled[amal.id] = amal.isFard ? true : (prefs.getBool('enabled_${amal.id}') ?? true);
        status[amal.id] = prefs.getBool('${_activeDateKey}_${amal.id}') ?? false;
      }

      if (!mounted) return;

      setState(() {
        _currentAmals = amals;
        _enabledAmols = enabled;
        _amolStatus = status;
        _totalActiveAmols =
            amals.where((a) => enabled[a.id] == true).length;
        _completedAmols = status.entries
            .where((e) => e.value && enabled[e.key] == true)
            .length;
      });

      await HistoryService.saveTodayRecord(
        totalAmols: _totalActiveAmols,
        completedAmols: _completedAmols,
        zikrCounts: {},
        amolStatus: status,
      );
    } catch (e) {
      debugPrint('Data loading error: $e');
    } finally {
      _loadingData = false;
    }
  }

  Future<void> _toggleAmolFromHome(String id) async {
    if (_amolStatus[id] == true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_activeDateKey}_$id', true);

    if (!mounted) return;

    setState(() {
      _amolStatus[id] = true;
      _completedAmols = _amolStatus.entries
          .where((e) => e.value && _enabledAmols[e.key] == true)
          .length;
    });

    await HistoryService.saveTodayRecord(
      totalAmols: _totalActiveAmols,
      completedAmols: _completedAmols,
      zikrCounts: {},
      amolStatus: _amolStatus,
    );
  }

  Future<void> _handleDateChange(String newDate) async {
    if (_dateChangeProcessing || newDate == _activeDateKey) return;

    _dateChangeProcessing = true;

    try {
      await HistoryService.checkAndAutoArchive();

      while (_loadingData) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (!mounted) return;

      _activeDateKey = newDate;
      _initTimes();
      await _loadAllData();
    } catch (e) {
      debugPrint('Date change error: $e');
    } finally {
      _dateChangeProcessing = false;
    }
  }

  void _startClock() {
    _timer?.cancel();

    void updateClock() {
      if (!mounted) return;

      final now = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);

      if (todayKey != _activeDateKey && !_dateChangeProcessing) {
        _handleDateChange(todayKey);
      }

      final timeText = DateFormat(
        'hh:mm:ss a',
        widget.isBn ? 'bn' : 'en',
      ).format(now);

      String countdown = '';
      String nextPrayer = '';

      if (prayerTimes != null && _coords != null) {
        final params = _getParams();
        final todayTimes = prayerTimes!;

        final prayerList = [
          {'name': 'Fajr', 'time': todayTimes.fajr},
          {'name': 'Dhuhr', 'time': todayTimes.dhuhr},
          {'name': 'Asr', 'time': todayTimes.asr},
          {'name': 'Maghrib', 'time': todayTimes.maghrib},
          {'name': 'Isha', 'time': todayTimes.isha},
        ];

        DateTime? nextTime;

        for (final prayer in prayerList) {
          final prayerTime = prayer['time'] as DateTime;
          if (prayerTime.isAfter(now)) {
            nextTime = prayerTime;
            nextPrayer = prayer['name'] as String;
            break;
          }
        }

        if (nextTime == null) {
          final tomorrow = PrayerTimes(
            _coords!,
            DateComponents.from(
              now.add(const Duration(days: 1)),
            ),
            params,
          );
          nextTime = tomorrow.fajr;
          nextPrayer = 'Fajr';
        }

        final difference = nextTime.difference(now);
        countdown =
            '${difference.inHours.toString().padLeft(2, '0')}:'
            '${(difference.inMinutes % 60).toString().padLeft(2, '0')}:'
            '${(difference.inSeconds % 60).toString().padLeft(2, '0')}';
      }

      setState(() {
        _currentTime = timeText;
        _countdown = countdown;
        _nextPrayerName = nextPrayer;
      });
    }

    updateClock();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateClock(),
    );
  }

  String _getPrayerName(String name) {
    if (!widget.isBn) return name;

    switch (name) {
      case 'Fajr':
        return 'ফজর';
      case 'Dhuhr':
        return 'যোহর';
      case 'Asr':
        return 'আসর';
      case 'Maghrib':
        return 'মাগরিব';
      case 'Isha':
        return 'ইশা';
      default:
        return name;
    }
  }

  List<AmalItem> _getRunningAmols() {
    if (prayerTimes == null) {
      return _currentAmals
          .where((amal) => _enabledAmols[amal.id] == true)
          .toList();
    }

    final now = DateTime.now();
    final times = prayerTimes!;

    final fajr = times.fajr;
    final sunrise = times.sunrise;
    final dhuhr = times.dhuhr;
    final asr = times.asr;
    final maghrib = times.maghrib;
    final isha = times.isha;

    bool isRunning(String prayerName) {
      switch (prayerName) {
        case 'tahajjud':
          return now.isBefore(fajr) && now.isAfter(isha);
        case 'fajr':
          return !now.isBefore(fajr) && now.isBefore(sunrise);
        case 'post_fajr':
          return !now.isBefore(fajr) && now.isBefore(dhuhr);
        case 'ishraq':
          return !now.isBefore(sunrise.add(const Duration(minutes: 15))) &&
              now.isBefore(dhuhr);
        case 'dhuhr':
          return !now.isBefore(dhuhr) && now.isBefore(asr);
        case 'asr':
          return !now.isBefore(asr) && now.isBefore(maghrib);
        case 'maghrib':
          return !now.isBefore(maghrib) && now.isBefore(isha);
        case 'isha':
          return !now.isBefore(isha) || now.isBefore(fajr);
        case 'bedtime':
          return !now.isBefore(isha) || now.isBefore(fajr);
        default:
          return true;
      }
    }

    return _currentAmals
        .where((amal) =>
            _enabledAmols[amal.id] == true &&
            isRunning(amal.prayerName))
        .toList();
  }

  Widget _buildPrayerCard() {
    final now = DateTime.now();

    final prayerData = prayerTimes == null
        ? <Map<String, dynamic>>[]
        : [
            {'name': 'Fajr', 'time': prayerTimes!.fajr},
            {'name': 'Dhuhr', 'time': prayerTimes!.dhuhr},
            {'name': 'Asr', 'time': prayerTimes!.asr},
            {'name': 'Maghrib', 'time': prayerTimes!.maghrib},
            {'name': 'Isha', 'time': prayerTimes!.isha},
          ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isBn ? 'নামাজের সময়সূচি' : 'Prayer Times',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingLocation)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                _locationMessage,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 12),
            if (prayerData.isEmpty)
              Text(widget.isBn
                  ? 'নামাজের সময় লোড হচ্ছে...'
                  : 'Loading prayer times...')
            else
              ...prayerData.map((prayer) {
                final time = prayer['time'] as DateTime;
                final isNext = prayer['name'] == _nextPrayerName;

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_getPrayerName(prayer['name'])),
                  trailing: Text(
                    DateFormat(
                      'hh:mm a',
                      widget.isBn ? 'bn' : 'en',
                    ).format(time),
                    style: TextStyle(
                      fontWeight:
                          isNext ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isNext,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primaryContainer,
                );
              }),
            if (prayerTimes != null) ...[
              const Divider(),
              Text(
                widget.isBn
                    ? 'পরবর্তী ওয়াক্ত: ${_getPrayerName(_nextPrayerName)}'
                    : 'Next prayer: $_nextPrayerName',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                widget.isBn
                    ? 'সময় বাকি: $_countdown'
                    : 'Time remaining: $_countdown',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmolCard(AmalItem amal) {
    final completed = _amolStatus[amal.id] ?? false;
    final title = widget.isBn ? amal.titleBn : amal.titleEn;

    return Card(
      child: CheckboxListTile(
        value: completed,
        onChanged: (_) => _toggleAmolFromHome(amal.id),
        title: Text(title),
        subtitle: Text(
          widget.isBn ? amal.categoryBn : amal.categoryEn,
        ),
        secondary: Icon(
          amal.isFard ? Icons.star : Icons.check_circle_outline,
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    final now = DateTime.now();

    final gregorian = DateFormat(
      'EEEE, d MMMM yyyy',
      widget.isBn ? 'bn' : 'en',
    ).format(now);

    final hijri = HijriService.getHijriDate(now, widget.isBn, prayerTimes?.maghrib);
    final bangla = BanglaDateHelper.format(now, sunriseTime: prayerTimes?.sunrise);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              gregorian,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(hijri),
            const SizedBox(height: 4),
            Text(bangla),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final runningAmols = _getRunningAmols();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isBn ? 'দৈনন্দিন আমল' : 'Daily Amal',
        ),
        actions: [
          IconButton(
            tooltip: widget.isBn ? 'সারসংক্ষেপ' : 'Summary',
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SummaryScreen(isBn: widget.isBn),
                ),
              );
            },
          ),
          IconButton(
            tooltip: widget.isBn ? 'অ্যালার্ম' : 'Alarms',
            icon: const Icon(Icons.alarm),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlarmScreen(
  isBn: widget.isBn,
  coords: _coords,
  calculationMethod: CalculationMethod.karachi,
  madhab: widget.madhab,
),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildDateCard(),
            const SizedBox(height: 10),
            _buildPrayerCard(),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isBn
                          ? 'আজকের আমলের অগ্রগতি'
                          : 'Today’s Amal Progress',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _totalActiveAmols == 0
                          ? 0
                          : _completedAmols / _totalActiveAmols,
                      minHeight: 9,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_completedAmols / $_totalActiveAmols',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isBn ? 'দৈনন্দিন আমলসমূহ' : 'Daily Activities',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            if (runningAmols.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.isBn
                      ? 'কোনো আমল চালু করা নেই।'
                      : 'No activities are enabled.',
                ),
              )
            else
              ...runningAmols.map(_buildAmolCard),
          ],
        ),
      ),
    );
  }
}
