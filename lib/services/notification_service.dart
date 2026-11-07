import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/helpers.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int _amalIdStart = 1000000;
  static const int _amalIdEnd = 9000000;

  Future<void> initialize({bool requestPermissions = true}) async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (requestPermissions) {
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
  }) async {
    await initialize();

    if (!dateTime.isAfter(DateTime.now())) return;

    final scheduledTime = tz.TZDateTime.from(dateTime, tz.local);

    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('app_lang') ?? 'bn';
    final channelId = 'dainik_amol_alarms_${language}_v2';
    final channelName = language == 'ar'
        ? 'تنبيهات الأعمال اليومية'
        : (language == 'en' ? 'Dainik Amal Alarms' : 'দৈনিক আমল অ্যালার্ম');
    final channelDescription = language == 'ar'
        ? 'تنبيهات الصلاة والأعمال مع الصوت والاهتزاز'
        : (language == 'en'
            ? 'Prayer and amal alarms with sound and vibration'
            : 'শব্দ ও ভাইব্রেশনসহ নামাজের অ্যালার্ম');

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      debugPrint(
        'NOTIFICATION_EXACT_SCHEDULED id=$id time=$scheduledTime',
      );
    } on PlatformException catch (e, st) {
      debugPrint(
        'NOTIFICATION_EXACT_FAILED id=$id code=${e.code} '
        'message=${e.message} details=${e.details}\\n$st',
      );

      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        debugPrint(
          'NOTIFICATION_INEXACT_SCHEDULED id=$id time=$scheduledTime',
        );
      } catch (fallbackError, fallbackStack) {
        debugPrint(
          'NOTIFICATION_INEXACT_FAILED id=$id error=$fallbackError\\n'
          '$fallbackStack',
        );
        rethrow;
      }
    } catch (e, st) {
      debugPrint('NOTIFICATION_SCHEDULE_FAILED id=$id error=$e\\n$st');
      rethrow;
    }
  }


  static const MethodChannel _nativeAlarmChannel =
      MethodChannel('dainik_amol/alarm');

  Future<bool> canScheduleExactAlarms() async {
    try {
      return await _nativeAlarmChannel.invokeMethod<bool>(
            'canScheduleExactAlarms',
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('Exact alarm permission check failed: $e');
      return false;
    }
  }

  Future<void> openExactAlarmSettings() async {
    await _nativeAlarmChannel.invokeMethod<void>(
      'openExactAlarmSettings',
    );
  }

  Future<void> schedulePrayerAlarm({
    required int id,
    required String title,
    required DateTime dateTime,
  }) async {
    if (!dateTime.isAfter(DateTime.now())) return;

    await initialize();
    await _plugin.cancel(id);

    try {
      await _nativeAlarmChannel.invokeMethod<void>('scheduleAlarm', {
        'id': id,
        'title': title,
        'timestamp': dateTime.millisecondsSinceEpoch,
      });
      debugPrint(
        'PRAYER_ALARM_SCHEDULED id=$id title=$title time=$dateTime',
      );
    } on PlatformException catch (e, st) {
      debugPrint(
        'PRAYER_ALARM_FAILED id=$id code=${e.code} '
        'message=${e.message} details=${e.details}\\n$st',
      );
      rethrow;
    } catch (e, st) {
      debugPrint('PRAYER_ALARM_FAILED id=$id error=$e\\n$st');
      rethrow;
    }
  }

  Future<void> cancelPrayerAlarm(int id) async {
    await _plugin.cancel(id);
    await _nativeAlarmChannel.invokeMethod<void>('cancelAlarm', {'id': id});
  }

  int _amalNotificationId(int amalIndex, int dayOffset, int index) {
    return _amalIdStart +
        (dayOffset * 4000000) +
        (amalIndex * 100) +
        index;
  }

  Future<void> cancelAmalReminders(
    String amalId, {
    bool allDays = false,
  }) async {
    await initialize();

    final pending = await _plugin.pendingNotificationRequests();
    final payloadPrefix = 'amal:$amalId:';
    final todayPayload = '$payloadPrefix${_dateKey(DateTime.now())}';

    for (final request in pending) {
      if (allDays
          ? (request.payload?.startsWith(payloadPrefix) ?? false)
          : request.payload == todayPayload) {
        await _plugin.cancel(request.id);
      }
    }
  }

  Future<void> _cancelAllAmalReminders() async {
    final pending = await _plugin.pendingNotificationRequests();

    for (final request in pending) {
      if (request.id >= _amalIdStart &&
          request.id < _amalIdEnd) {
        await _plugin.cancel(request.id);
      }
    }
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String? _notificationSettingKey(String amalId) {
    const keys = <String, String>{
      'surah_yasin': 'notif_yasin',
      'morning_adhkar': 'notif_morning_dhikr',
      'quran_2_pages': 'notif_quran',
      'evening_dhikr': 'notif_evening_dhikr',
      'surah_waqiah': 'notif_waqiah',
      'surah_mulk': 'notif_mulk',
      'muhasabah': 'notif_muhasaba',
    };

    return keys[amalId];
  }

  DateTime _at(DateTime date, int hour, int minute) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  ({DateTime start, DateTime end})? _reminderWindow(
    AmalItem amal,
    DateTime date,
    PrayerTimes times,
    PrayerTimes tomorrowTimes,
  ) {
    switch (amal.id) {
      case 'surah_yasin':
      case 'morning_adhkar':
        return (start: times.fajr, end: _at(date, 9, 0));

      case 'quran_2_pages':
        return (
          start: times.sunrise.add(const Duration(minutes: 15)),
          end: _at(date, 11, 0),
        );

      case 'evening_dhikr':
        return (start: times.asr, end: times.maghrib);

      case 'surah_waqiah':
        return (start: times.maghrib, end: times.isha);

      case 'surah_mulk':
        return (start: _at(date, 20, 0), end: _at(date.add(const Duration(days: 1)), 0, 0));

      case 'muhasabah':
        return (
          start: _at(date, 21, 30),
          end: _at(date.add(const Duration(days: 1)), 0, 0),
        );
    }

    switch (amal.prayerName) {
      case 'tahajjud':
        return (
          start: times.fajr.subtract(const Duration(minutes: 90)),
          end: times.fajr.subtract(const Duration(minutes: 10)),
        );

      case 'fajr':
        return (start: times.fajr, end: times.sunrise);

      case 'post_fajr':
        return (start: times.fajr, end: _at(date, 9, 0));

      case 'ishraq':
        return (
          start: times.sunrise.add(const Duration(minutes: 15)),
          end: _at(date, 11, 0),
        );

      case 'dhuhr':
        return (start: times.dhuhr, end: times.asr);

      case 'asr':
        return (start: times.asr, end: times.maghrib);

      case 'maghrib':
        return (start: times.maghrib, end: times.isha);

      case 'isha':
        return (start: times.isha, end: _at(date.add(const Duration(days: 1)), 0, 0));

      case 'bedtime':
        return (start: _at(date, 20, 0), end: _at(date.add(const Duration(days: 1)), 0, 0));

      case 'muhasabah':
        return (
          start: _at(date, 21, 30),
          end: _at(date.add(const Duration(days: 1)), 0, 0),
        );

      default:
        return null;
    }
  }

  Future<void> scheduleAmalReminders({
    required Coordinates coords,
    required String madhab,
  }) async {
    await initialize();

    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('app_lang') ?? 'bn';
    final amals = await AmalService.getAllAmals();

    await _cancelAllAmalReminders();

    final params = CalculationMethod.karachi.getParameters();
    params.madhab =
        madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

    final now = DateTime.now();

    final reminders = <
        ({DateTime dateTime, int id, String title, String payload})
    >[];

    for (var dayOffset = 0; dayOffset < 2; dayOffset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day + dayOffset,
      );

      final tomorrow = date.add(const Duration(days: 1));

      final times = PrayerTimes(
        coords,
        DateComponents.from(date),
        params,
      );

      final tomorrowTimes = PrayerTimes(
        coords,
        DateComponents.from(tomorrow),
        params,
      );

      for (var amalIndex = 0;
          amalIndex < amals.length;
          amalIndex++) {
        final amal = amals[amalIndex];

        const prayerAmalsWithoutReminders = <String>{
          'fajr_sunnah',
          'dhuhr_sunnah_pre',
          'dhuhr_sunnah_post',
          'maghrib_sunnah',
          'awwabin',
          'isha_sunnah',
          'isha_witr',
        };

        if (prayerAmalsWithoutReminders.contains(amal.id) ||
            amal.isFard ||
            (prefs.getBool('enabled_${amal.id}') ?? true) == false ||
            (prefs.getBool('${_dateKey(date)}_${amal.id}') ?? false)) {
          continue;
        }

        final settingKey = _notificationSettingKey(amal.id);

        if (settingKey != null &&
            (prefs.getBool(settingKey) ?? true) == false) {
          continue;
        }

        final window = _reminderWindow(
          amal,
          date,
          times,
          tomorrowTimes,
        );

        if (window == null ||
            !window.end.isAfter(window.start)) {
          continue;
        }

        var reminderTime = window.start;
        var index = 0;

        while (reminderTime.isBefore(window.end) && index < 100) {
          if (reminderTime.isAfter(now)) {
            reminders.add((
              dateTime: reminderTime,
              id: _amalNotificationId(
                amalIndex,
                dayOffset,
                index,
              ),
              title: language == 'ar'
                  ? (amal.titleAr.isNotEmpty
                      ? amal.titleAr
                      : (amal.titleEn.isNotEmpty ? amal.titleEn : amal.titleBn))
                  : (language == 'en'
                      ? (amal.titleEn.isNotEmpty ? amal.titleEn : amal.titleBn)
                      : amal.titleBn),
              payload: 'amal:${amal.id}:${_dateKey(date)}',
            ));
          }

          reminderTime =
              reminderTime.add(const Duration(minutes: 10));
          index++;
        }
      }
    }

    reminders.sort(
      (a, b) => a.dateTime.compareTo(b.dateTime),
    );

    const maxScheduledAmalReminders = 400;

    var scheduledCount = 0;
    var failedCount = 0;

    for (final reminder
        in reminders.take(maxScheduledAmalReminders)) {
      try {
        await scheduleAlarm(
          id: reminder.id,
          title: reminder.title,
          body: language == 'ar'
              ? 'حان وقت أداء هذا العمل. ضع علامة عليه في القائمة بعد الانتهاء.'
              : (language == 'en'
                  ? 'It is time to complete this amal. Tick it in the list when finished.'
                  : 'এখন আমলটি সম্পন্ন করার সময়। আমল শেষ হলে তালিকায় টিক দিন।'),
          dateTime: reminder.dateTime,
          payload: reminder.payload,
        );
        scheduledCount++;
      } catch (e, st) {
        failedCount++;
        debugPrint(
          'AMAL_REMINDER_FAILED id=${reminder.id} '
          'time=${reminder.dateTime} error=$e\\n$st',
        );
      }
    }

    debugPrint(
      'AMAL_REMINDER_SUMMARY total=${reminders.length} '
      'attempted=${reminders.take(maxScheduledAmalReminders).length} '
      'scheduled=$scheduledCount failed=$failedCount',
    );

    try {
      final pending = await _plugin.pendingNotificationRequests();
      final amalPending = pending.where(
        (n) => n.id >= _amalIdStart && n.id < _amalIdEnd,
      ).length;
      debugPrint('AMAL_REMINDER_PENDING count=$amalPending');
    } catch (e) {
      debugPrint('AMAL_REMINDER_PENDING_CHECK_FAILED error=$e');
    }
  }

  Future<void> cancelAlarm(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
