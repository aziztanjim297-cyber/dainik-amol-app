import 'dart:convert';
import 'package:hijri/hijri_calendar.dart';
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
  static String getHijriDate(DateTime dt, [bool isBn = true]) {
    final h = HijriCalendar.fromDate(dt);
    final bnMonths = ['মহররম', 'সফর', 'রবিউল আউয়াল', 'রবিউস সানি', 'জমাদিউল আউয়াল', 'জমাদিউস সানি', 'রজব', 'শাবান', 'রমাদান', 'শাওয়াল', 'জিলকদ', 'জিলহজ'];
    final enMonths = ['Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Thani", "Jumada al-Ula", "Jumada al-Akhirah", "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"];
    int mIdx = (h.hMonth - 1).clamp(0, 11);

    if (isBn) {
      return '${BanglaDateHelper.toBanglaNum(h.hDay)} ${bnMonths[mIdx]}, ${BanglaDateHelper.toBanglaNum(h.hYear)} হিজরি';
    } else {
      return '${h.hDay} ${enMonths[mIdx]}, ${h.hYear} AH';
    }
  }

  static String getHijriNote([bool isBn = true]) {
    return isBn ? 'চাঁদ দেখার উপর নির্ভরশীল' : 'Subject to moon sighting';
  }
}

class AmalItem {
  final String id;
  final String titleBn;
  final String titleEn;
  final String categoryBn;
  final String categoryEn;
  final bool isFard;
  final String prayerName;
  final bool isCustom;

  AmalItem({
    required this.id,
    required this.titleBn,
    required this.titleEn,
    String? categoryBn,
    String? categoryEn,
    String? category,
    required this.isFard,
    required this.prayerName,
    this.isCustom = false,
  })  : categoryBn = categoryBn ?? category ?? '',
        categoryEn = categoryEn ?? category ?? '';

  String get category => categoryBn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleBn': titleBn,
    'titleEn': titleEn,
    'categoryBn': categoryBn,
    'categoryEn': categoryEn,
    'isFard': isFard,
    'prayerName': prayerName,
    'isCustom': isCustom,
  };

  factory AmalItem.fromJson(Map<String, dynamic> json) => AmalItem(
    id: json['id'],
    titleBn: json['titleBn'],
    titleEn: json['titleEn'],
    categoryBn: json['categoryBn'],
    categoryEn: json['categoryEn'],
    isFard: json['isFard'] ?? false,
    prayerName: json['prayerName'],
    isCustom: json['isCustom'] ?? false,
  );
}

class AmalService {
  static final List<AmalItem> defaultAmals = [
    AmalItem(id: 'tahajjud_4', titleBn: 'তাহাজ্জুদ নামাজ (৪ রাকাত)', titleEn: 'Tahajjud (4 Rak\'ah)', categoryBn: 'তাহাজ্জুদ', categoryEn: 'Tahajjud', isFard: false, prayerName: 'tahajjud'),
    AmalItem(id: 'fajr_sunnah', titleBn: 'ফজর ২ রাকাত সুন্নত', titleEn: 'Fajr 2 Sunnah', categoryBn: 'ফজর', categoryEn: 'Fajr', isFard: false, prayerName: 'fajr'),
    AmalItem(id: 'fajr_fard', titleBn: 'ফজর ২ রাকাত ফরজ (জামাতে)', titleEn: 'Fajr 2 Fard (Jama\'ah)', categoryBn: 'ফজর', categoryEn: 'Fajr', isFard: true, prayerName: 'fajr'),
    AmalItem(id: 'surah_yasin', titleBn: 'সূরা ইয়াসিন তিলাওয়াত', titleEn: 'Surah Yasin', categoryBn: 'ফজর পরবর্তী', categoryEn: 'Post-Fajr', isFard: false, prayerName: 'post_fajr'),
    AmalItem(id: 'ishraq', titleBn: 'ইশরাক নামাজ (৪ রাকাত)', titleEn: 'Ishraq Prayer', categoryBn: 'ইশরাক', categoryEn: 'Ishraq', isFard: false, prayerName: 'ishraq'),
    AmalItem(id: 'dhuhr_sunnah_pre', titleBn: 'যোহরের পূর্ববর্তী ৪ সুন্নত', titleEn: 'Dhuhr 4 Pre-Sunnah', categoryBn: 'যোহর', categoryEn: 'Dhuhr', isFard: false, prayerName: 'dhuhr'),
    AmalItem(id: 'dhuhr_fard', titleBn: 'যোহরের ৪ রাকাত ফরজ', titleEn: 'Dhuhr 4 Fard', categoryBn: 'যোহর', categoryEn: 'Dhuhr', isFard: true, prayerName: 'dhuhr'),
    AmalItem(id: 'dhuhr_sunnah_post', titleBn: 'যোহরের পরবর্তী ২ সুন্নত', titleEn: 'Dhuhr 2 Post-Sunnah', categoryBn: 'যোহর', categoryEn: 'Dhuhr', isFard: false, prayerName: 'dhuhr'),
    AmalItem(id: 'asr_fard', titleBn: 'আসরের ৪ রাকাত ফরজ', titleEn: 'Asr 4 Fard', categoryBn: 'আসর', categoryEn: 'Asr', isFard: true, prayerName: 'asr'),
    AmalItem(id: 'evening_dhikr', titleBn: 'বিকেলের জিকির ও আজকার', titleEn: 'Evening Adhkar', categoryBn: 'আসর পরবর্তী', categoryEn: 'Post-Asr', isFard: false, prayerName: 'asr'),
    AmalItem(id: 'maghrib_fard', titleBn: 'মাগরিবের ৩ রাকাত ফরজ', titleEn: 'Maghrib 3 Fard', categoryBn: 'মাগরিব', categoryEn: 'Maghrib', isFard: true, prayerName: 'maghrib'),
    AmalItem(id: 'maghrib_sunnah', titleBn: 'মাগরিবের ২ রাকাত সুন্নত', titleEn: 'Maghrib 2 Sunnah', categoryBn: 'মাগরিব', categoryEn: 'Maghrib', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'awwabin', titleBn: 'আওয়াবিন নামাজ', titleEn: 'Awwabin Prayer', categoryBn: 'মাগরিব', categoryEn: 'Maghrib', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'surah_waqiah', titleBn: 'সূরা ওয়াকিয়াহ তিলাওয়াত', titleEn: 'Surah Waqiah', categoryBn: 'মাগরিব পরবর্তী', categoryEn: 'Post-Maghrib', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'isha_fard', titleBn: 'ইশার ৪ রাকাত ফরজ', titleEn: 'Isha 4 Fard', categoryBn: 'ইশা', categoryEn: 'Isha', isFard: true, prayerName: 'isha'),
    AmalItem(id: 'isha_sunnah', titleBn: 'ইশার ২ রাকাত সুন্নত', titleEn: 'Isha 2 Sunnah', categoryBn: 'ইশা', categoryEn: 'Isha', isFard: false, prayerName: 'isha'),
    AmalItem(id: 'isha_witr', titleBn: '৩ রাকাত বিতর', titleEn: '3 Rak\'ah Witr', categoryBn: 'ইশা', categoryEn: 'Isha', isFard: true, prayerName: 'isha'),
    AmalItem(id: 'surah_mulk', titleBn: 'সূরা মুলক তিলাওয়াত', titleEn: 'Surah Mulk', categoryBn: 'ঘুমানোর পূর্বে', categoryEn: 'Bedtime', isFard: false, prayerName: 'bedtime'),
  ];

  static Future<List<AmalItem>> getAllAmals() async {
    final prefs = await SharedPreferences.getInstance();
    final customList = prefs.getStringList('custom_amals_json') ?? [];
    List<AmalItem> list = List.from(defaultAmals);
    for (String s in customList) {
      try {
        list.add(AmalItem.fromJson(jsonDecode(s)));
      } catch (_) {}
    }
    return list;
  }

  static Future<void> addCustomAmal(String titleBn, String prayerName, String categoryBn) async {
    final prefs = await SharedPreferences.getInstance();
    final customList = prefs.getStringList('custom_amals_json') ?? [];
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = AmalItem(
      id: id,
      titleBn: titleBn,
      titleEn: titleBn,
      categoryBn: categoryBn,
      categoryEn: categoryBn,
      isFard: false,
      prayerName: prayerName,
      isCustom: true,
    );
    customList.add(jsonEncode(newItem.toJson()));
    await prefs.setStringList('custom_amals_json', customList);
    await prefs.setBool('enabled_$id', true);
  }

  static Future<void> deleteCustomAmal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final customList = prefs.getStringList('custom_amals_json') ?? [];
    customList.removeWhere((s) {
      try {
        return jsonDecode(s)['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList('custom_amals_json', customList);
  }
}
