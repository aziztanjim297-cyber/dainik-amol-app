import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BanglaDateHelper {
  static final List<String> _bnMonths = ['বৈশাখ', 'জ্যৈষ্ঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন', 'কার্তিক', 'অগ্রহায়ণ', 'পৌষ', 'মাঘ', 'ফাল্গুন', 'চৈত্র'];
  static final List<String> _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  static String toBanglaNum(int n) {
    return n.toString().split('').map((d) => int.tryParse(d) != null ? _bnDigits[int.parse(d)] : d).join('');
  }

  static String format(DateTime dt) {
    int gYear = dt.year;
    int gMonth = dt.month;
    int gDay = dt.day;
    bool isLeapYear = (gYear % 4 == 0 && gYear % 100 != 0) || (gYear % 400 == 0);
    int bnYear = (gMonth < 4 || (gMonth == 4 && gDay < 14)) ? gYear - 594 : gYear - 593;
    DateTime bNewYear = DateTime(gYear, 4, 14);
    int diff = dt.difference(bNewYear).inDays;
    if (diff < 0) {
      bNewYear = DateTime(gYear - 1, 4, 14);
      diff = dt.difference(bNewYear).inDays;
    }
    int bMonthIdx = 0;
    int bDay = diff + 1;
    List<int> bDaysInMonths = [31, 31, 31, 31, 31, 30, 30, 30, 30, 30, isLeapYear ? 30 : 29, 30];
    for (int i = 0; i < 12; i++) {
      if (bDay <= bDaysInMonths[i]) {
        bMonthIdx = i;
        break;
      }
      bDay -= bDaysInMonths[i];
    }
    return '${toBanglaNum(bDay)} ${_bnMonths[bMonthIdx]}, ${toBanglaNum(bnYear)} বঙ্গাব্দ';
  }
}

class HijriService {
  static Future<String> getHijriDate(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    String cacheKey = 'hijri_${dt.year}_${dt.month}_${dt.day}';
    String? cached = prefs.getString(cacheKey);
    if (cached != null) return cached;

    try {
      final formatted = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
      final url = Uri.parse("https://api.aladhan.com/v1/gToH/$formatted");
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final h = data['data']['hijri'];
        String result = "${h['day']} ${h['month']['en']}, ${h['year']} হিজরি";
        await prefs.setString(cacheKey, result);
        return result;
      }
    } catch (_) {}
    return "${dt.day} রমাদান, ${dt.year - 579} হিজরি (আনুমানিক)";
  }
}

class AmalItem {
  final String id;
  final String titleBn;
  final String titleEn;
  final String category;
  final bool isFard;
  final String prayerName;

  AmalItem({
    required this.id,
    required this.titleBn,
    required this.titleEn,
    required this.category,
    required this.isFard,
    required this.prayerName,
  });
}
