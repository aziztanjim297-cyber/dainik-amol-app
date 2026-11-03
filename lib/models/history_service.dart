import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyAmolRecord {
  final String date;
  final int totalAmols;
  final int completedAmols;
  final Map<String, int> zikrCounts;
  final Map<String, bool> amolStatus;

  DailyAmolRecord({
    required this.date,
    required this.totalAmols,
    required this.completedAmols,
    required this.zikrCounts,
    required this.amolStatus,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'totalAmols': totalAmols,
        'completedAmols': completedAmols,
        'zikrCounts': zikrCounts,
        'amolStatus': amolStatus,
      };

  factory DailyAmolRecord.fromJson(Map<String, dynamic> json) {
    final rawZikr = json['zikrCounts'];
    final rawAmol = json['amolStatus'];

    return DailyAmolRecord(
      date: json['date']?.toString() ?? '',
      totalAmols: (json['totalAmols'] as num?)?.toInt() ?? 0,
      completedAmols: (json['completedAmols'] as num?)?.toInt() ?? 0,
      zikrCounts: rawZikr is Map
          ? rawZikr.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num?)?.toInt() ?? 0,
              ),
            )
          : <String, int>{},
      amolStatus: rawAmol is Map
          ? rawAmol.map(
              (key, value) => MapEntry(key.toString(), value == true),
            )
          : <String, bool>{},
    );
  }
}

class HistoryService {
  static const String _historyKey = 'amol_history_records_90days';
  static const String _lastActiveDateKey = 'last_recorded_active_date';

  static String _today() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  static Future<Map<String, dynamic>> _getRawHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);

    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return {};
  }

  static Map<String, int> _readZikrCounts(dynamic value) {
    if (value is! Map) return {};

    return value.map(
      (key, count) => MapEntry(
        key.toString(),
        (count as num?)?.toInt() ?? 0,
      ),
    );
  }

  static Map<String, bool> _readAmolStatus(dynamic value) {
    if (value is! Map) return {};

    return value.map(
      (key, status) => MapEntry(key.toString(), status == true),
    );
  }

  static Future<void> checkAndAutoArchive() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final lastActive = prefs.getString(_lastActiveDateKey);

    if (lastActive != null && lastActive != today) {
      final zikrPresets = [
        'সুবহানাল্লাহ — سُبْحَانَ اللَّهِ',
        'আলহামদুলিল্লাহ — الْحَمْدُ لِلَّهِ',
        'আল্লাহু আকবার — اللَّهُ أَكْبَرُ',
        'আস্তাগফিরুল্লাহ — أَسْتَغْفِرُ اللَّهَ',
        'দরুদ শরিফ — الصَّلَاةُ عَلَى النَّبِيِّ',
      ];

      final pastZikrs = <String, int>{};

      for (final zikr in zikrPresets) {
        pastZikrs[zikr] =
            prefs.getInt('${lastActive}_total_$zikr') ?? 0;
      }

      final doneCount =
          prefs.getInt('completed_amols_$lastActive') ?? 0;
      final totalCount =
          prefs.getInt('total_amols_$lastActive') ?? 18;

      await _saveToHistoryMap(
        dateStr: lastActive,
        total: totalCount,
        done: doneCount,
        zikrs: pastZikrs,
        amols: {},
      );
    }

    await prefs.setString(_lastActiveDateKey, today);
  }

  static Future<void> saveTodayRecord({
    required int totalAmols,
    required int completedAmols,
    required Map<String, int> zikrCounts,
    required Map<String, bool> amolStatus,
  }) async {
    final today = _today();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_lastActiveDateKey, today);
    await prefs.setInt('completed_amols_$today', completedAmols);
    await prefs.setInt('total_amols_$today', totalAmols);

    await _saveToHistoryMap(
      dateStr: today,
      total: totalAmols,
      done: completedAmols,
      zikrs: zikrCounts,
      amols: amolStatus,
    );
  }

  // শুধু জিকিরের সংখ্যা সংরক্ষণ করবে; আমলের হিসাব পরিবর্তন করবে না।
  static Future<void> saveZikrCounts(
    Map<String, int> zikrCounts,
  ) async {
    final today = _today();
    final history = await _getRawHistory();
    final oldData = history[today];

    final oldRecord = oldData is Map
        ? DailyAmolRecord.fromJson(
            Map<String, dynamic>.from(oldData),
          )
        : null;

    final mergedZikrs = <String, int>{
      ...?oldRecord?.zikrCounts,
      ...zikrCounts,
    };

    await _saveToHistoryMap(
      dateStr: today,
      total: oldRecord?.totalAmols ?? 18,
      done: oldRecord?.completedAmols ?? 0,
      zikrs: mergedZikrs,
      amols: oldRecord?.amolStatus ?? {},
    );
  }

  static Future<void> _saveToHistoryMap({
    required String dateStr,
    required int total,
    required int done,
    required Map<String, int> zikrs,
    required Map<String, bool> amols,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await _getRawHistory();

    final oldData = history[dateStr];
    final oldRecord = oldData is Map
        ? DailyAmolRecord.fromJson(
            Map<String, dynamic>.from(oldData),
          )
        : null;

    final mergedZikrs = <String, int>{
      ...?oldRecord?.zikrCounts,
      ...zikrs,
    };

    final mergedAmols = <String, bool>{
      ...?oldRecord?.amolStatus,
      ...amols,
    };

    final record = DailyAmolRecord(
      date: dateStr,
      totalAmols: total,
      completedAmols: done,
      zikrCounts: mergedZikrs,
      amolStatus: mergedAmols,
    );

    history[dateStr] = record.toJson();

    final cutoffDate =
        DateTime.now().subtract(const Duration(days: 90));

    history.removeWhere((key, value) {
      try {
        return DateTime.parse(key).isBefore(cutoffDate);
      } catch (_) {
        return false;
      }
    });

    await prefs.setString(_historyKey, jsonEncode(history));
  }

  static Future<DailyAmolRecord?> getRecordForDate(
    String dateStr,
  ) async {
    final history = await _getRawHistory();
    final data = history[dateStr];

    if (data is Map) {
      return DailyAmolRecord.fromJson(
        Map<String, dynamic>.from(data),
      );
    }

    return null;
  }

  static Future<Map<String, dynamic>> getWeeklyStats() async {
    return _getStats(7);
  }

  static Future<Map<String, dynamic>> getMonthlyStats() async {
    return _getStats(30);
  }

  static Future<Map<String, dynamic>> _getStats(int days) async {
    final history = await _getRawHistory();

    int totalAmols = 0;
    int completedAmols = 0;
    int totalZikr = 0;
    final zikrCounts = <String, int>{};

    for (int i = 0; i < days; i++) {
      final date = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(Duration(days: i)),
      );

      final data = history[date];

      if (data is Map) {
        final record = DailyAmolRecord.fromJson(
          Map<String, dynamic>.from(data),
        );

        totalAmols += record.totalAmols;
        completedAmols += record.completedAmols;

        for (final entry in record.zikrCounts.entries) {
          zikrCounts[entry.key] =
              (zikrCounts[entry.key] ?? 0) + entry.value;
          totalZikr += entry.value;
        }
      }
    }

    final percent = totalAmols == 0
        ? 0
        : (completedAmols / totalAmols * 100).toInt();

    return {
      'totalAmols': totalAmols,
      'completedAmols': completedAmols,
      'percent': percent,
      'totalZikr': totalZikr,
      'zikrCounts': zikrCounts,
    };
  }
}
