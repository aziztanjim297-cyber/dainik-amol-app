
import 'dart:ui';

import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

const String _refreshTask = 'refreshAmalReminders';
const String _refreshUniqueName = 'amal-reminder-refresh';

@pragma('vm:entry-point')
void amalBackgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _refreshTask) return true;

    try {
      DartPluginRegistrant.ensureInitialized();

      await NotificationService.instance.initialize(requestPermissions: false);

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final lat = prefs.getDouble('location_lat');
      final lon = prefs.getDouble('location_lon');

      if (lat == null || lon == null) return true;

      final madhab = prefs.getString('madhab') ?? 'hanafi';

      await NotificationService.instance.scheduleAmalReminders(
        coords: Coordinates(lat, lon),
        madhab: madhab,
      );

      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> initializeBackgroundReminderRefresh() async {
  await Workmanager().initialize(amalBackgroundCallbackDispatcher);

  await Workmanager().registerPeriodicTask(
    _refreshUniqueName,
    _refreshTask,
    frequency: const Duration(hours: 12),
  );
}
