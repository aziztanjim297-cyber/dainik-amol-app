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
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double percent = _totalActiveAmols == 0 ? 0 : (_completedAmols / _totalActiveAmols);
    int percentInt = (percent * 100).toInt();
    List<AmalItem> runningAmols = _getRunningAmols();

    String hijriDate = HijriService.getHijriDate(now, widget.isBn, prayerTimes?.maghrib);
    String hijriNote = HijriService.getHijriNote(widget.isBn);
    String banglaDate = BanglaDateHelper.format(now, sunriseTime: prayerTimes?.sunrise);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'দৈনন্দিন আমল' : 'Dainik Amal', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: widget.isBn ? 'আমল রিপোর্ট' : 'Summary Report',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(isBn: widget.isBn))),
          ),
          IconButton(
            icon: const Icon(Icons.alarm),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmScreen(isBn: widget.isBn, coords: _coords, calculationMethod: CalculationMethod.karachi, madhab: widget.madhab))),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { _initTimes(); _loadAllData(); }),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadAllData, child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                        Text(DateFormat('EEEE, d MMMM yyyy').format(now), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : Colors.blue)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF143526) : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.mosque, size: 20, color: Color(0xFF0D5C3A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(hijriDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A), fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('($hijriNote)', style: TextStyle(fontSize: 11, color: isDark ? Colors.greenAccent : Colors.green.shade800, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF332015) : Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 18, color: Colors.deepOrange),
                        Text(banglaDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.orangeAccent : Colors.deepOrange)),
                      ],
                    ),
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time_filled, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _currentTime,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0D5C3A),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: isDark ? const Color(0xFF1B2E24) : const Color(0xFFE8F5E9),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.isBn ? 'আমলের অগ্রগতি' : 'Amal Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                      Text('$_completedAmols/$_totalActiveAmols ${widget.isBn ? "সম্পন্ন" : "Done"} — $percentInt%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: percent.clamp(0.0, 1.0), minHeight: 8, borderRadius: BorderRadius.circular(5), color: const Color(0xFF0D5C3A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.green, size: 22),
                      const SizedBox(width: 6),
                      Text(widget.isBn ? 'বর্তমান সময়ের সক্রিয় আমল (Running)' : 'Active Amals (Running)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
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
                      Text(_nextPrayerName, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
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
          if (prayerTimes != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.isBn ? 'নামাজের সময়' : 'Prayer Times', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmScreen(isBn: widget.isBn, coords: _coords, calculationMethod: CalculationMethod.karachi, madhab: widget.madhab))),
                          child: const Row(
                            children: [
                              Icon(Icons.alarm_on, size: 18, color: Color(0xFF0D5C3A)),
                              SizedBox(width: 4),
                              Text('অ্যালার্ম', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                            ],
                          ),
                        ),
                      ],
                    ),
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
