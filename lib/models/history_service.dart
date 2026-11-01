import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyAmolRecord {
  final String date; // YYYY-MM-DD
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

  factory DailyAmolRecord.fromJson(Map<String, dynamic> json) => DailyAmolRecord(
    date: json['date'] ?? '',
    totalAmols: json['totalAmols'] ?? 0,
    completedAmols: json['completedAmols'] ?? 0,
    zikrCounts: Map<String, int>.from(json['zikrCounts'] ?? {}),
    amolStatus: Map<String, bool>.from(json['amolStatus'] ?? {}),
  );
}

class HistoryService {
  static const String _historyKey = 'amol_history_records_90days';
  static const String _lastActiveDateKey = 'last_recorded_active_date';

  // রাত ১২টায় স্বয়ংক্রিয়ভাবে বিগত দিনের ডেটা স্থায়ীভাবে সংরক্ষণ
  static Future<void> checkAndAutoArchive() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastActive = prefs.getString(_lastActiveDateKey);

    if (lastActive != null && lastActive != today) {
      // বিগত দিনের জিকির ও আমল সংগ্রহ করে স্থায়ী ডাটাবেজে আর্কাইভ করা
      Map<String, int> pastZikrs = {};
      final zikrPresets = [
        'সুবহানাল্লাহ — سُبْحَانَ اللَّهِ',
        'আলহামদুলিল্লাহ — الْحَمْدُ لِلَّهِ',
        'আল্লাহু আকবার — اللَّهُ أَكْبَرُ',
        'আস্তাগফিরুল্লাহ — أَسْتَغْفِرُ اللَّهَ',
        'দরুদ শরিফ — الصَّلَاةُ عَلَى النَّبِيِّ',
      ];
      for (var z in zikrPresets) {
        pastZikrs[z] = prefs.getInt('${lastActive}_total_$z') ?? 0;
      }

      int doneCount = prefs.getInt('completed_amols_$lastActive') ?? 0;
      int totalCount = prefs.getInt('total_amols_$lastActive') ?? 18;

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

  // প্রতিদিনের আমল ও জিকির রিয়েল-টাইম সংরক্ষণ
  static Future<void> saveTodayRecord({
    required int totalAmols,
    required int completedAmols,
    required Map<String, int> zikrCounts,
    required Map<String, bool> amolStatus,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

  static Future<void> _saveToHistoryMap({
    required String dateStr,
    required int total,
    required int done,
    required Map<String, int> zikrs,
    required Map<String, bool> amols,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> history = await _getRawHistory();

    final record = DailyAmolRecord(
      date: dateStr,
      totalAmols: total,
      completedAmols: done,
      zikrCounts: zikrs,
      amolStatus: amols,
    );

    history[dateStr] = record.toJson();

    // ৯০ দিনের বেশি পুরনো ডেটা স্বয়ংক্রিয়ভাবে মুছে ফেলা
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    history.removeWhere((key, value) {
      try {
        DateTime recordDate = DateTime.parse(key);
        return recordDate.isBefore(cutoffDate);
      } catch (_) {
        return false;
      }
    });

    await prefs.setString(_historyKey, jsonEncode(history));
  }

  static Future<Map<String, dynamic>> _getRawHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  // নির্দিষ্ট কোনো দিনের সংরক্ষিত রিপোর্ট পাওয়া (ছবি/PDF এর জন্য)
  static Future<DailyAmolRecord?> getRecordForDate(String dateStr) async {
    final history = await _getRawHistory();
    if (history.containsKey(dateStr)) {
      return DailyAmolRecord.fromJson(history[dateStr]);
    }
    return null;
  }

  // বিগত ৭ দিনের সামগ্রিক পরিসংখ্যান
  static Future<Map<String, dynamic>> getWeeklyStats() async {
    final history = await _getRawHistory();
    int totalAmols = 0;
    int completedAmols = 0;
    int totalZikr = 0;

    for (int i = 0; i < 7; i++) {
      String d = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: i)));
      if (history.containsKey(d)) {
        final rec = DailyAmolRecord.fromJson(history[d]);
        totalAmols += rec.totalAmols;
        completedAmols += rec.completedAmols;
        rec.zikrCounts.forEach((_, count) => totalZikr += count);
      }
    }

    double percent = totalAmols == 0 ? 0 : (completedAmols / totalAmols) * 100;
    return {
      'totalAmols': totalAmols,
      'completedAmols': completedAmols,
      'percent': percent.toInt(),
      'totalZikr': totalZikr,
    };
  }

  // বিগত ৩০ দিনের সামগ্রিক পরিসংখ্যান
  static Future<Map<String, dynamic>> getMonthlyStats() async {
    final history = await _getRawHistory();
    int totalAmols = 0;
    int completedAmols = 0;
    int totalZikr = 0;

    for (int i = 0; i < 30; i++) {
      String d = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: i)));
      if (history.containsKey(d)) {
        final rec = DailyAmolRecord.fromJson(history[d]);
        totalAmols += rec.totalAmols;
        completedAmols += rec.completedAmols;
        rec.zikrCounts.forEach((_, count) => totalZikr += count);
      }
    }

    double percent = totalAmols == 0 ? 0 : (completedAmols / totalAmols) * 100;
    return {
      'totalAmols': totalAmols,
      'completedAmols': completedAmols,
      'percent': percent.toInt(),
      'totalZikr': totalZikr,
    };
  }
}
