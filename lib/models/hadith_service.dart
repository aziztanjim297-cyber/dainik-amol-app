import 'hadith_data_1.dart';
import 'hadith_data_2.dart';

class HadithService {
  static List<Map<String, String>> getAllHadiths() {
    return [...hadithsPart1, ...hadithsPart2];
  }
}
