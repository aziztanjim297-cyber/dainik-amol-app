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
