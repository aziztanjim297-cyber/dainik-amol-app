import 'dart:convert';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class BanglaDateHelper {
  static final List<String> _bnMonths = ['বৈশাখ', 'জ্যৈষ্ঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন', 'কার্তিক', 'অগ্রহায়ণ', 'পৌষ', 'মাঘ', 'ফাল্গুন', 'চৈত্র'];
  static final List<String> _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  static String toBanglaNum(int n) {
    return n.toString().split('').map((d) => int.tryParse(d) != null ? _bnDigits[int.parse(d)] : d).join('');
  }

  // সূর্যোদয়ের সময় অনুযায়ী বাংলা তারিখ পরিবর্তন
  static String format(DateTime dt, {DateTime? sunriseTime}) {
    DateTime calcDt = dt;
    // সূর্যোদয়ের আগে হলে আগের দিনের বাংলা তারিখ থাকবে
    if (sunriseTime != null && dt.isBefore(sunriseTime)) {
      calcDt = dt.subtract(const Duration(days: 1));
    }

    int gYear = calcDt.year;
    int gMonth = calcDt.month;
    int gDay = calcDt.day;
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
  // মাগরিবের সময় অনুযায়ী হিজরি তারিখ পরিবর্তন
  static String _toArabicNum(int number) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((d) {
      final n = int.tryParse(d);
      return n == null ? d : digits[n];
    }).join();
  }

  static String getHijriDate(
    DateTime dt, [
    bool isBn = true,
    DateTime? maghribTime,
    String language = '',
  ]) {
    DateTime calcDt = dt;
    // মাগরিবের ওয়াক্ত শুরু হলে পরের দিনের হিজরি তারিখ শুরু হবে
    if (maghribTime != null && !dt.isBefore(maghribTime)) {
      calcDt = dt.add(const Duration(days: 1));
    }

    final h = HijriCalendar.fromDate(calcDt);
    final bnMonths = ['মহররম', 'সফর', 'রবিউল আউয়াল', 'রবিউস সানি', 'জমাদিউল আউয়াল', 'জমাদিউস সানি', 'রজব', 'শাবান', 'রমাদান', 'শাওয়াল', 'জিলকদ', 'জিলহজ'];
    final enMonths = ['Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Thani", "Jumada al-Ula", "Jumada al-Akhirah", "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"];
    final arMonths = ['مُحَرَّم', 'صَفَر', 'رَبِيع الأَوَّل', 'رَبِيع الثَّانِي', 'جُمَادَى الأُولَى', 'جُمَادَى الآخِرَة', 'رَجَب', 'شَعْبَان', 'رَمَضَان', 'شَوَّال', 'ذُو القَعْدَة', 'ذُو الحِجَّة'];
    final mIdx = (h.hMonth - 1).clamp(0, 11);

    if (language == 'ar') {
      return '${_toArabicNum(h.hDay)} ${arMonths[mIdx]}، ${_toArabicNum(h.hYear)} هـ';
    } else if (isBn) {
      return '${BanglaDateHelper.toBanglaNum(h.hDay)} ${bnMonths[mIdx]}, ${BanglaDateHelper.toBanglaNum(h.hYear)} হিজরি';
    } else {
      return '${h.hDay} ${enMonths[mIdx]}, ${h.hYear} AH';
    }
  }


  // বাংলাদেশ-সমন্বিত হিজরি তারিখ: অনলাইন API, দিনের ক্যাশ, তারপর স্থানীয় বিকল্প
  static Future<String> getBangladeshHijriDate(
    DateTime dt, [
    bool isBn = true,
    DateTime? maghribTime,
    String language = '',
  ]) async {
    DateTime calcDt = dt;
    if (maghribTime != null && !dt.isBefore(maghribTime)) {
      calcDt = dt.add(const Duration(days: 1));
    }

    final dateKey =
        '${calcDt.year.toString().padLeft(4, '0')}-${calcDt.month.toString().padLeft(2, '0')}-${calcDt.day.toString().padLeft(2, '0')}';
    final cacheKey = 'bd_hijri_$dateKey';
    final prefs = await SharedPreferences.getInstance();

    String formatDate(Map<String, dynamic> data) {
      final year = (data['year'] as num).toInt();
      final month = (data['month'] as num).toInt();
      final day = (data['day'] as num).toInt();
      if (month < 1 || month > 12 || day < 1 || day > 30) {
        throw const FormatException('Invalid Hijri date');
      }

      const bnMonths = [
        'মহররম', 'সফর', 'রবিউল আউয়াল', 'রবিউস সানি',
        'জমাদিউল আউয়াল', 'জমাদিউস সানি', 'রজব', 'শাবান',
        'রমাদান', 'শাওয়াল', 'জিলকদ', 'জিলহজ'
      ];
      const enMonths = [
        'Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Thani",
        'Jumada al-Ula', 'Jumada al-Akhirah', 'Rajab', "Sha'ban",
        'Ramadan', 'Shawwal', "Dhu al-Qi'dah", 'Dhu al-Hijjah'
      ];
      const arMonths = [
        'مُحَرَّم', 'صَفَر', 'رَبِيع الأَوَّل', 'رَبِيع الثَّانِي',
        'جُمَادَى الأُولَى', 'جُمَادَى الآخِرَة', 'رَجَب', 'شَعْبَان',
        'رَمَضَان', 'شَوَّال', 'ذُو القَعْدَة', 'ذُو الحِجَّة'
      ];
      final i = month - 1;
      if (language == 'ar') {
        return '${_toArabicNum(day)} ${arMonths[i]}، ${_toArabicNum(year)} هـ';
      }
      if (isBn) {
        return '${BanglaDateHelper.toBanglaNum(day)} ${bnMonths[i]}, ${BanglaDateHelper.toBanglaNum(year)} হিজরি';
      }
      return '$day ${enMonths[i]}, $year AH';
    }

    // নির্দিষ্ট দিনের ক্যাশ থাকলে সেটি আগে ব্যবহার
    final saved = prefs.getString(cacheKey);
    if (saved != null) {
      try {
        final result = formatDate(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
        // অনলাইন আপডেটের সুযোগ রাখতে নিচে API-ও চেষ্টা করা হবে
        if (result.isEmpty) throw const FormatException();
      } catch (_) {
        await prefs.remove(cacheKey);
      }
    }

    try {
      final uri = Uri.https(
        'www.bangladatetoday.com',
        '/api/convert',
        {'date': dateKey},
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final hijri = Map<String, dynamic>.from(body['hijri'] as Map);
        final resultData = <String, dynamic>{
          'year': hijri['year'],
          'month': hijri['month'],
          'day': hijri['day'],
        };
        final result = formatDate(resultData);
        await prefs.setString(cacheKey, jsonEncode(resultData));
        return result;
      }
    } catch (_) {
      // নেটওয়ার্ক বা API সমস্যা হলে ক্যাশ/স্থানীয় হিসাব ব্যবহার হবে
    }

    // অফলাইনে একই দিনের সংরক্ষিত বাংলাদেশি তারিখ
    final offlineSaved = prefs.getString(cacheKey);
    if (offlineSaved != null) {
      try {
        return formatDate(
          Map<String, dynamic>.from(jsonDecode(offlineSaved) as Map),
        );
      } catch (_) {}
    }

    // প্রথমবার অফলাইন হলে প্যাকেজের স্থানীয় হিসাব
    return getHijriDate(calcDt, isBn, null, language);
  }

  static String getHijriNote([bool isBn = true, String language = '']) {
    if (language == 'ar') return 'يخضع لرؤية الهلال';
    return isBn ? 'চাঁদ দেখার উপর নির্ভরশীল' : 'Subject to moon sighting';
  }
}

class AmalItem {
  final String id;
  final String titleBn;
  final String titleEn;
  final String titleAr;
  final String categoryAr;
  final String categoryBn;
  final String categoryEn;
  final bool isFard;
  final String prayerName;
  final bool isCustom;

  AmalItem({
    required this.id,
    required this.titleBn,
    required this.titleEn,
    this.titleAr = '',
    this.categoryAr = '',
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
    'titleAr': titleAr,
    'categoryAr': categoryAr,
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
    titleAr: json['titleAr'] ?? '',
    categoryAr: json['categoryAr'] ?? '',
    categoryBn: json['categoryBn'],
    categoryEn: json['categoryEn'],
    isFard: json['isFard'] ?? false,
    prayerName: json['prayerName'],
    isCustom: json['isCustom'] ?? false,
  );
}

class AmalService {
  static final List<AmalItem> defaultAmals = [
    AmalItem(id: 'tahajjud_4', titleBn: 'তাহাজ্জুদ নামাজ (৪ রাকাত)', titleEn: 'Tahajjud (4 Rak\'ah)', categoryBn: 'তাহাজ্জুদ', categoryEn: 'Tahajjud', titleAr: 'صلاة التهجد (٤ ركعات)', categoryAr: 'التهجد', isFard: false, prayerName: 'tahajjud'),
    AmalItem(id: 'fajr_sunnah', titleBn: 'ফজর ২ রাকাত সুন্নত', titleEn: 'Fajr 2 Sunnah', categoryBn: 'ফজর', categoryEn: 'Fajr', titleAr: 'سنة الفجر ركعتان', categoryAr: 'الفجر', isFard: false, prayerName: 'fajr'),
    AmalItem(id: 'fajr_fard', titleBn: 'ফজর ২ রাকাত ফরজ (জামাতে)', titleEn: 'Fajr 2 Fard (Jama\'ah)', categoryBn: 'ফজর', categoryEn: 'Fajr', titleAr: 'فرض الفجر ركعتان (جماعة)', categoryAr: 'الفجر', isFard: true, prayerName: 'fajr'),
    AmalItem(id: 'surah_yasin', titleBn: 'সূরা ইয়াসিন তিলাওয়াত', titleEn: 'Surah Yasin', categoryBn: 'ফজর পরবর্তী', categoryEn: 'Post-Fajr', titleAr: 'قراءة سورة يس', categoryAr: 'بعد الفجر', isFard: false, prayerName: 'post_fajr'),
    AmalItem(id: 'morning_adhkar', titleBn: 'সকালবেলার জিকির ও আজকার', titleEn: 'Morning Adhkar', categoryBn: 'সকালবেলার আমল', categoryEn: 'Morning', titleAr: 'أذكار الصباح', categoryAr: 'أذكار الصباح', isFard: false, prayerName: 'post_fajr'),
    AmalItem(id: 'quran_2_pages', titleBn: 'দৈনিক কুরআন তিলাওয়াত (২ পৃষ্ঠা)', titleEn: 'Daily Quran (2 Pages)', categoryBn: 'ইশরাক পরবর্তী', categoryEn: 'Post-Ishraq', titleAr: 'تلاوة القرآن يومياً (صفحتان)', categoryAr: 'بعد الإشراق', isFard: false, prayerName: 'ishraq'),
    AmalItem(id: 'muhasabah', titleBn: 'দিনের কাজের মুহাসাবা / হিসাব', titleEn: 'Daily Self-Evaluation', categoryBn: 'রাতের আমল', categoryEn: 'Night', titleAr: 'محاسبة النفس اليومية', categoryAr: 'أعمال الليل', isFard: false, prayerName: 'muhasabah'),
    AmalItem(id: 'ishraq', titleBn: 'ইশরাক নামাজ (৪ রাকাত)', titleEn: 'Ishraq Prayer', categoryBn: 'ইশরাক', categoryEn: 'Ishraq', titleAr: 'صلاة الإشراق (٤ ركعات)', categoryAr: 'الإشراق', isFard: false, prayerName: 'ishraq'),
    AmalItem(id: 'dhuhr_sunnah_pre', titleBn: 'যোহরের পূর্ববর্তী ৪ সুন্নত', titleEn: 'Dhuhr 4 Pre-Sunnah', categoryBn: 'যোহর', categoryEn: 'Dhuhr', titleAr: 'سنة الظهر القبلية أربع ركعات', categoryAr: 'الظهر', isFard: false, prayerName: 'dhuhr'),
    AmalItem(id: 'dhuhr_fard', titleBn: 'যোহরের ৪ রাকাত ফরজ', titleEn: 'Dhuhr 4 Fard', categoryBn: 'যোহর', categoryEn: 'Dhuhr', titleAr: 'فرض الظهر أربع ركعات', categoryAr: 'الظهر', isFard: true, prayerName: 'dhuhr'),
    AmalItem(id: 'dhuhr_sunnah_post', titleBn: 'যোহরের পরবর্তী ২ সুন্নত', titleEn: 'Dhuhr 2 Post-Sunnah', categoryBn: 'যোহর', categoryEn: 'Dhuhr', titleAr: 'سنة الظهر البعدية ركعتان', categoryAr: 'الظهر', isFard: false, prayerName: 'dhuhr'),
    AmalItem(id: 'asr_fard', titleBn: 'আসরের ৪ রাকাত ফরজ', titleEn: 'Asr 4 Fard', categoryBn: 'আসর', categoryEn: 'Asr', titleAr: 'فرض العصر أربع ركعات', categoryAr: 'العصر', isFard: true, prayerName: 'asr'),
    AmalItem(id: 'evening_dhikr', titleBn: 'বিকেলের জিকির ও আজকার', titleEn: 'Evening Adhkar', categoryBn: 'আসর পরবর্তী', categoryEn: 'Post-Asr', titleAr: 'أذكار المساء', categoryAr: 'بعد العصر', isFard: false, prayerName: 'asr'),
    AmalItem(id: 'maghrib_fard', titleBn: 'মাগরিবের ৩ রাকাত ফরজ', titleEn: 'Maghrib 3 Fard', categoryBn: 'মাগরিব', categoryEn: 'Maghrib', titleAr: 'فرض المغرب ثلاث ركعات', categoryAr: 'المغرب', isFard: true, prayerName: 'maghrib'),
    AmalItem(id: 'maghrib_sunnah', titleBn: 'মাগরিবের ২ রাকাত সুন্নত', titleEn: 'Maghrib 2 Sunnah', categoryBn: 'মাগরিব', categoryEn: 'Maghrib', titleAr: 'سنة المغرب ركعتان', categoryAr: 'المغرب', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'awwabin', titleBn: 'আওয়াবিন নামাজ', titleEn: 'Awwabin Prayer', categoryBn: 'মাগরিব', categoryEn: 'Maghrib', titleAr: 'صلاة الأوابين', categoryAr: 'المغرب', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'surah_waqiah', titleBn: 'সূরা ওয়াকিয়াহ তিলাওয়াত', titleEn: 'Surah Waqiah', categoryBn: 'মাগরিব পরবর্তী', categoryEn: 'Post-Maghrib', titleAr: 'قراءة سورة الواقعة', categoryAr: 'بعد المغرب', isFard: false, prayerName: 'maghrib'),
    AmalItem(id: 'isha_fard', titleBn: 'ইশার ৪ রাকাত ফরজ', titleEn: 'Isha 4 Fard', categoryBn: 'ইশা', categoryEn: 'Isha', titleAr: 'فرض العشاء أربع ركعات', categoryAr: 'العشاء', isFard: true, prayerName: 'isha'),
    AmalItem(id: 'isha_sunnah', titleBn: 'ইশার ২ রাকাত সুন্নত', titleEn: 'Isha 2 Sunnah', categoryBn: 'ইশা', categoryEn: 'Isha', titleAr: 'سنة العشاء ركعتان', categoryAr: 'العشاء', isFard: false, prayerName: 'isha'),
    AmalItem(id: 'isha_witr', titleBn: '৩ রাকাত বিতর', titleEn: '3 Rak\'ah Witr', categoryBn: 'ইশা', categoryEn: 'Isha', titleAr: 'صلاة الوتر ثلاث ركعات', categoryAr: 'العشاء', isFard: true, prayerName: 'isha'),
    AmalItem(id: 'surah_mulk', titleBn: 'সূরা মুলক তিলাওয়াত', titleEn: 'Surah Mulk', categoryBn: 'ঘুমানোর পূর্বে', categoryEn: 'Bedtime', titleAr: 'قراءة سورة الملك', categoryAr: 'قبل النوم', isFard: false, prayerName: 'bedtime'),
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
