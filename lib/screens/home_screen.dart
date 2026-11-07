import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import '../models/helpers.dart';
import '../services/notification_service.dart';
import '../models/history_service.dart';
import 'alarm_screen.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isBn;
  final String madhab;
  final String language;

  const HomeScreen({
    super.key,
    required this.isBn,
    required this.madhab,
    String? language,
  }) : language = language ?? (isBn ? 'bn' : 'en');

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _t(String bn, String en, String ar) =>
      widget.language == 'ar' ? ar : (widget.isBn ? bn : en);

  ui.TextDirection get _textDirection =>
      widget.language == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr;

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
  String? _bangladeshHijriDate;
  String _hijriDateKey = '';

  Future<void> _refreshHijriDate() async {
    final now = DateTime.now();
    DateTime effectiveDate = now;
    final maghrib = prayerTimes?.maghrib;
    if (maghrib != null && !now.isBefore(maghrib)) {
      effectiveDate = now.add(const Duration(days: 1));
    }
    final key = DateFormat('yyyy-MM-dd').format(effectiveDate);
    if (key == _hijriDateKey) return;
    _hijriDateKey = key;

    final value = await HijriService.getBangladeshHijriDate(
      now, widget.isBn, maghrib, widget.language,
    );
    if (!mounted || key != _hijriDateKey) return;
    setState(() => _bangladeshHijriDate = value);
  }

  PrayerTimes? prayerTimes;
  Timer? _timer;
  String _currentTime = '';
  String _countdown = '';
  String _nextPrayerName = '';
  String _waqtLabel = '';
  bool _isMakruhTime = false;
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
    _refreshHijriDate();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  Future<void> _initializeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('location_mode');
    final lat = prefs.getDouble('location_lat');
    final lon = prefs.getDouble('location_lon');

    if (mode != null && lat != null && lon != null) {
      _coords = Coordinates(lat, lon);
      _locationMessage = prefs.getString('location_label') ?? '';
      _loadingLocation = false;
      _initTimes();
      if (_coords != null) {
        await NotificationService.instance.scheduleAmalReminders(
          coords: _coords!,
          madhab: widget.madhab,
        );
      }
      if (mounted) setState(() {});
      return;
    }

    if (mode == 'country') {
      _setLocationFallback(
        widget.isBn
            ? 'শুধু দেশের নাম দিয়ে নামাজের সময় নির্ণয় সম্ভব নয়। GPS নির্বাচন করুন।'
            : 'Country alone is insufficient. Select GPS location.',
      );
      return;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception();
      }

      final pos = await Geolocator.getCurrentPosition();
      _coords = Coordinates(pos.latitude, pos.longitude);
      _locationMessage = widget.isBn ? 'বর্তমান GPS অবস্থান' : 'Current GPS location';
      await prefs.setString('location_mode', 'gps');
      await prefs.setDouble('location_lat', pos.latitude);
      await prefs.setDouble('location_lon', pos.longitude);
      await prefs.setString('location_label', _locationMessage);
      _loadingLocation = false;
      _initTimes();
      if (_coords != null) {
        await NotificationService.instance.scheduleAmalReminders(
          coords: _coords!,
          madhab: widget.madhab,
        );
      }
      if (mounted) setState(() {});
    } catch (_) {
      _setLocationFallback(
        widget.isBn ? 'লোকেশন পাওয়া যায়নি। সেটিংস থেকে GPS বা অবস্থান নির্বাচন করুন।' : 'Location unavailable. Select a location in Settings.',
      );
    }
  }

  void _setLocationFallback(String message) {
    if (!mounted) return;
    setState(() {
      _coords = null;
      prayerTimes = null;
      _locationMessage = message;
      _loadingLocation = false;
    });
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
    _refreshHijriDate();
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
    await NotificationService.instance.cancelAmalReminders(id);

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
      if (_coords != null) {
        await NotificationService.instance.scheduleAmalReminders(
          coords: _coords!,
          madhab: widget.madhab,
        );
      }
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
    _refreshHijriDate();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);

      if (todayKey != _activeDateKey && !_dateChangeProcessing) {
        _handleDateChange(todayKey);
      }

      final timeText = DateFormat(
        'hh:mm:ss a',
        widget.language,
      ).format(now);

      String countdown = '';
      String nextPrayer = '';
      String waqtLabel = '';
      bool isMakruh = false;

      if (prayerTimes != null && _coords != null) {
        final params = _getParams();
        final times = prayerTimes!;

        final fajr = times.fajr;
        final sunrise = times.sunrise;
        final dhuhr = times.dhuhr;
        final asr = times.asr;
        final maghrib = times.maghrib;
        final isha = times.isha;

        final prayerList = [
          {'name': 'Fajr', 'time': fajr},
          {'name': 'Dhuhr', 'time': dhuhr},
          {'name': 'Asr', 'time': asr},
          {'name': 'Maghrib', 'time': maghrib},
          {'name': 'Isha', 'time': isha},
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
            DateComponents.from(now.add(const Duration(days: 1))),
            params,
          );
          nextTime = tomorrow.fajr;
          nextPrayer = 'Fajr';
        }

        DateTime countdownTarget = nextTime;

        final makruhPeriods = [
          {
            'bn': 'সূর্যোদয়ের',
            'en': 'Sunrise',
            'ar': 'الشروق',
            'start': sunrise,
            'end': sunrise.add(const Duration(minutes: 15)),
          },
          {
            'bn': 'যাওয়ালের',
            'en': 'Zawal',
            'ar': 'الزوال',
            'start': dhuhr.subtract(const Duration(minutes: 5)),
            'end': dhuhr,
          },
          {
            'bn': 'সূর্যাস্তের',
            'en': 'Sunset',
            'ar': 'الغروب',
            'start': maghrib.subtract(const Duration(minutes: 15)),
            'end': maghrib,
          },
        ];

        for (final period in makruhPeriods) {
          final start = period['start'] as DateTime;
          final end = period['end'] as DateTime;
          if (!now.isBefore(start) && now.isBefore(end)) {
            isMakruh = true;
            countdownTarget = end;
            waqtLabel = _t(
              '${period['bn']} মাকরুহ ওয়াক্ত শেষ হতে বাকি',
              '${period['en']} makruh time ends in',
              'ينتهي وقت الكراهة بعد ${period['ar']}',
            );
            break;
          }
        }

        if (!isMakruh) {
          if (now.isBefore(fajr)) {
            waqtLabel = _t('ফজর শুরু হতে বাকি', 'Fajr begins in', 'يبدأ الفجر بعد');
            countdownTarget = fajr;
          } else if (now.isBefore(sunrise)) {
            waqtLabel = _t('ফজরের ওয়াক্ত বাকি আছে', 'Fajr time remaining', 'الوقت المتبقي للفجر');
            countdownTarget = sunrise;
          } else if (now.isBefore(dhuhr.subtract(const Duration(minutes: 5)))) {
            waqtLabel = _t('যোহরের ওয়াক্ত শুরু হতে বাকি', 'Dhuhr begins in', 'يبدأ الظهر بعد');
            countdownTarget = dhuhr;
          } else if (now.isBefore(asr)) {
            waqtLabel = _t('চাশতের সময় বাকি আছে', 'Dhuhr time remaining', 'الوقت المتبقي للظهر');
            countdownTarget = asr;
          } else if (now.isBefore(maghrib.subtract(const Duration(minutes: 15)))) {
            waqtLabel = _t('আসরের ওয়াক্ত বাকি আছে', 'Asr time remaining', 'الوقت المتبقي للعصر');
            countdownTarget = maghrib;
          } else if (now.isBefore(isha)) {
            waqtLabel = _t('মাগরিবের ওয়াক্ত বাকি আছে', 'Maghrib time remaining', 'الوقت المتبقي للمغرب');
            countdownTarget = isha;
          } else {
            waqtLabel = _t('ইশার ওয়াক্ত বাকি আছে', 'Isha time remaining', 'الوقت المتبقي للعشاء');
          }
        }

        final difference = countdownTarget.difference(now);
        countdown =
            '${difference.inHours.toString().padLeft(2, '0')}:'
            '${(difference.inMinutes % 60).toString().padLeft(2, '0')}:'
            '${(difference.inSeconds % 60).toString().padLeft(2, '0')}';
      }

      setState(() {
        _currentTime = timeText;
        _countdown = countdown;
        _nextPrayerName = nextPrayer;
        _waqtLabel = waqtLabel;
        _isMakruhTime = isMakruh;
      });
    }

    updateClock();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateClock(),
    );
  }

  String _getPrayerName(String name) {
    switch (name) {
      case 'Fajr':
        return _t('ফজর', 'Fajr', 'الفجر');
      case 'Dhuhr':
        return _t('যোহর', 'Dhuhr', 'الظهر');
      case 'Asr':
        return _t('আসর', 'Asr', 'العصر');
      case 'Maghrib':
        return _t('মাগরিব', 'Maghrib', 'المغرب');
      case 'Isha':
        return _t('ইশা', 'Isha', 'العشاء');
      default:
        return name;
    }
  }

  List<AmalItem> _getRunningAmols() {
    if (prayerTimes == null) {
      return _currentAmals
          .where((amal) =>
              _enabledAmols[amal.id] == true &&
              _amolStatus[amal.id] != true)
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
            _amolStatus[amal.id] != true &&
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
              _t('নামাজের সময়সূচি', 'Prayer Times', 'مواقيت الصلاة'),
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
              Text(_t('নামাজের সময় লোড হচ্ছে...', 'Loading prayer times...', 'جارٍ تحميل مواقيت الصلاة...'))
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
                      widget.language,
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
                _t('পরবর্তী ওয়াক্ত: ${_getPrayerName(_nextPrayerName)}', 'Next prayer: ${_getPrayerName(_nextPrayerName)}', 'الصلاة القادمة: ${_getPrayerName(_nextPrayerName)}'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                _t('সময় বাকি: $_countdown', 'Time remaining: $_countdown', 'الوقت المتبقي: $_countdown'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmolCard(AmalItem amal) {
    final completed = _amolStatus[amal.id] ?? false;
    final title = _amalTitle(amal);

    return Card(
      child: CheckboxListTile(
        value: completed,
        onChanged: (_) => _toggleAmolFromHome(amal.id),
        title: Text(title, textDirection: _textDirection),
        subtitle: Text(
          _amalCategory(amal),
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
      widget.language,
    ).format(now);

    final hijri = (_bangladeshHijriDate ?? HijriService.getHijriDate(now, widget.isBn, prayerTimes?.maghrib, widget.language));
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
            if (widget.language == 'bn') Text(bangla),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<AmalItem> runningAmols = _getRunningAmols();

    String hijriDate = (_bangladeshHijriDate ?? HijriService.getHijriDate(now, widget.isBn, prayerTimes?.maghrib, widget.language));
    String hijriNote = HijriService.getHijriNote(widget.isBn, widget.language);
    String banglaDate = BanglaDateHelper.format(now, sunriseTime: prayerTimes?.sunrise);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('দৈনন্দিন আমল', 'Dainik Amal', 'الأعمال اليومية'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: _t('আমল রিপোর্ট', 'Summary Report', 'ملخص الأعمال'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(isBn: widget.isBn, language: widget.language))),
          ),
          IconButton(
            icon: const Icon(Icons.alarm),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmScreen(isBn: widget.isBn, language: widget.language, coords: _coords, calculationMethod: CalculationMethod.karachi, madhab: widget.madhab))),
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
                        Text(DateFormat('EEEE, d MMMM yyyy', widget.language).format(now), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : Colors.blue)),
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
                        if (widget.language == 'bn') Text(banglaDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.orangeAccent : Colors.deepOrange)),
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
                      Text(_t('বর্তমান সময়ের সক্রিয় আমল (চলমান)', 'Active Amals (Running)', 'الأعمال النشطة الآن'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                    ],
                  ),
                  const Divider(height: 16),
                  if (runningAmols.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_t('এই মুহূর্তে কোনো নির্দিষ্ট ওয়াক্তের আমল চলমান নেই।', 'No active amals at this moment.', 'لا توجد أعمال مرتبطة بوقت الصلاة الآن'), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    )
                  else
                    ...runningAmols.map((a) {
                      bool isDone = _amolStatus[a.id] ?? false;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(a.isFard ? Icons.star_rounded : Icons.check_circle_outline, color: a.isFard ? Colors.deepOrange : const Color(0xFF0D5C3A)),
                        title: Text(_amalTitle(a), textDirection: _textDirection, style: TextStyle(fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null)),
                        subtitle: Text(_amalCategory(a), textDirection: _textDirection, style: const TextStyle(fontSize: 12)),
                        trailing: isDone
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_t('সম্পন্ন ', 'Done ', 'مكتمل '), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const Icon(Icons.lock, color: Colors.green, size: 16),
                                ],
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                onPressed: () => _toggleAmolFromHome(a.id),
                                child: Text(_t('টিক দিন', 'Check', 'تم')),
                              ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Card(
            color: _isMakruhTime
                ? (isDark ? const Color(0xFF7F1D1D) : Colors.red.shade100)
                : (isDark ? const Color(0xFF1B2E24) : const Color(0xFFE8F5E9)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _waqtLabel,
                          style: TextStyle(
                            color: _isMakruhTime
                                ? (isDark ? Colors.red.shade100 : Colors.red.shade900)
                                : (isDark ? Colors.white : const Color(0xFF0D5C3A)),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _countdown.isEmpty ? '--:--:--' : _countdown,
                        style: TextStyle(
                          color: _isMakruhTime
                              ? (isDark ? Colors.white : Colors.red.shade900)
                              : (isDark ? Colors.amberAccent : const Color(0xFF0D5C3A)),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 18,
                    color: _isMakruhTime ? Colors.red.shade300 : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _t('পরবর্তী নামাজ', 'Next Prayer', 'الصلاة القادمة'),
                        style: TextStyle(
                          color: _isMakruhTime
                              ? (isDark ? Colors.red.shade100 : Colors.red.shade900)
                              : (isDark ? Colors.white70 : const Color(0xFF0D5C3A)),
                        ),
                      ),
                      Text(
                        _getPrayerName(_nextPrayerName),
                        style: TextStyle(
                          color: _isMakruhTime
                              ? (isDark ? Colors.white : Colors.red.shade900)
                              : (isDark ? Colors.white : const Color(0xFF0D5C3A)),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                        Text(_t('নামাজের সময়', 'Prayer Times', 'مواقيت الصلاة'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmScreen(isBn: widget.isBn, language: widget.language, coords: _coords, calculationMethod: CalculationMethod.karachi, madhab: widget.madhab))),
                          child: Row(
                            children: [
                              Icon(Icons.alarm_on, size: 18, color: Color(0xFF0D5C3A)),
                              SizedBox(width: 4),
                              Text(_t('অ্যালার্ম', 'Alarm', 'التنبيه'), textDirection: _textDirection, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    _timeRow(_t('সাহরীর শেষ সময়', 'Suhoor Ends', 'نهاية السحور'), prayerTimes!.fajr.subtract(const Duration(minutes: 10))),
                    _timeRow(_t('ফজর', 'Fajr', 'الفجر'), prayerTimes!.fajr),
                    _timeRow(_t('সূর্যোদয়', 'Sunrise', 'الشروق'), prayerTimes!.sunrise),
                    _timeRow(_t('যোহর', 'Dhuhr', 'الظهر'), prayerTimes!.dhuhr),
                    _timeRow(_t('আসর', 'Asr', 'العصر'), prayerTimes!.asr),
                    _timeRow(_t('সূর্যাস্ত ও মাগরিব', 'Sunset & Maghrib', 'الغروب والمغرب'), prayerTimes!.maghrib),
                    _timeRow(_t('ইশা', 'Isha', 'العشاء'), prayerTimes!.isha),
                    const Divider(height: 20),
                    Text(
                      _t('মাকরুহ ওয়াক্ত', 'Makruh Times', 'أوقات الكراهة'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    _timeRangeRow(
                      widget.isBn ? 'সূর্যোদয়' : 'Sunrise',
                      prayerTimes!.sunrise,
                      prayerTimes!.sunrise.add(const Duration(minutes: 15)),
                    ),
                    _timeRangeRow(
                      _t('যাওয়াল (সতর্কতামূলক)', 'Zawal (precaution)', 'وقت الزوال (احتياطًا)'),
                      prayerTimes!.dhuhr.subtract(const Duration(minutes: 5)),
                      prayerTimes!.dhuhr,
                    ),
                    _timeRangeRow(
                      widget.isBn ? 'সূর্যাস্ত' : 'Sunset',
                      prayerTimes!.maghrib.subtract(const Duration(minutes: 15)),
                      prayerTimes!.maghrib,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _timeRangeRow(String title, DateTime start, DateTime end) {
    final now = DateTime.now();
    final isMakruh = !now.isBefore(start) && now.isBefore(end);
    final color = isMakruh ? Colors.red : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            textDirection: _textDirection,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: isMakruh ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${DateFormat('hh:mm a', widget.language).format(start)} - ${DateFormat('hh:mm a', widget.language).format(end)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
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
          Text(title, textDirection: _textDirection, style: const TextStyle(fontSize: 14)),
          Text(DateFormat('hh:mm a', widget.language).format(time), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
