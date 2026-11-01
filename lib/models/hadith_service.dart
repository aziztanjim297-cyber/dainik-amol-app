import 'hadith_data_1.dart';
import 'hadith_data_2.dart';
import 'hadith_data_3.dart';
import 'hadith_data_4.dart';

class HadithService {
  static List<Map<String, String>> getAllHadiths() {
    return [
      ...hadithsPart1,
      ...hadithsPart2,
      ...hadithsPart3,
      ...hadithsPart4,
    ];
  }
}
