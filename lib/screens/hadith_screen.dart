import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith_service.dart';
import '../models/hadith_arabic_data.dart';
import '../models/hadith_english_data.dart';

class HadithScreen extends StatefulWidget {
  final bool isBn;
  final String language;
  const HadithScreen({
    super.key,
    required this.isBn,
    String? language,
  }) : language = language ?? (isBn ? 'bn' : 'en');

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  String _t(String bn, String en, String ar) =>
      widget.language == 'ar' ? ar : (widget.isBn ? bn : en);

  String _number(Map<String, String> h) =>
      h['no']!.replaceAllMapped(RegExp(r'[০-৯]'), (m) =>
          '${'০১২৩৪৫৬৭৮৯'.indexOf(m[0]!)}');

  Map<String, String>? _arabicData(Map<String, String> h) =>
      hadithArabicData[_number(h)];

  Map<String, String>? _englishData(Map<String, String> h) =>
      hadithEnglishData[_number(h)];

  String _hadithTitle(Map<String, String> h) {
    if (widget.language == 'ar') {
      return _arabicData(h)?['title'] ?? 'الحديث ${_number(h)}';
    }
    if (!widget.isBn) return 'Hadith ${_number(h)}';
    return h['title']!;
  }

  String _hadithText(Map<String, String> h) {
    if (widget.language == 'ar') return h['arabic']!;
    if (!widget.isBn) {
      return _englishData(h)?['englishText'] ??
          'English translation unavailable';
    }
    return h['bangla']!;
  }

  String _hadithMeaning(Map<String, String> h) {
    if (widget.language == 'ar') {
      return _arabicData(h)?['meaning'] ?? '';
    }
    if (!widget.isBn) {
      return _englishData(h)?['englishText'] ??
          'English translation unavailable';
    }
    return h['bangla']!;
  }

  String _hadithNarrator(Map<String, String> h) {
    if (widget.language == 'ar') {
      return _arabicData(h)?['narrator'] ?? '';
    }
    if (!widget.isBn) {
      return _englishData(h)?['englishNarrator'] ?? '';
    }
    return h['narrator']!;
  }

  String _hadithSource(Map<String, String> h) =>
      widget.isBn ? h['source']! : (_arabicData(h)?['source'] ?? '');

String _hadithGrade(Map<String, String> h) =>
      widget.isBn ? h['grade']! : (_arabicData(h)?['grade'] ?? '');

String _hadithLesson(Map<String, String> h) =>
      widget.isBn ? h['lesson']! : (_arabicData(h)?['lesson'] ?? '');

  TextDirection get _textDirection =>
      widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  final List<Map<String, String>> _allHadiths = HadithService.getAllHadiths();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _expandedHadithNo;
  Set<String> _bookmarkedHadiths = {};
  double _arabicFontSize = 21.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bookmarkedHadiths = (prefs.getStringList('hadith_bookmarks_set') ?? []).toSet();
      _arabicFontSize = prefs.getDouble('hadith_arabic_font_size') ?? 21.0;
    });
  }

  Future<void> _updateFontSize(double delta) async {
    final newSize = (_arabicFontSize + delta).clamp(16.0, 32.0);
    setState(() => _arabicFontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hadith_arabic_font_size', newSize);
  }

  Future<void> _toggleBookmark(String no) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_bookmarkedHadiths.contains(no)) {
        _bookmarkedHadiths.remove(no);
      } else {
        _bookmarkedHadiths.add(no);
      }
    });
    await prefs.setStringList('hadith_bookmarks_set', _bookmarkedHadiths.toList());
  }


  void _showBookmarksSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2923) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final bookmarks = _allHadiths
              .where((h) => _bookmarkedHadiths.contains(h['no']))
              .toList()
            ..sort((a, b) =>
                int.parse(_number(a)).compareTo(int.parse(_number(b))));

          return SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.bookmarks, color: Color(0xFF0D5C3A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _t('সংরক্ষিত হাদিস', 'Bookmarked Hadiths', 'الأحاديث المحفوظة'),
                            textDirection: _textDirection,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text('${bookmarks.length}/40',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: bookmarks.isEmpty
                        ? Center(
                            child: Text(
                              _t('এখনো কোনো হাদিস বুকমার্ক করা হয়নি',
                                  'No bookmarked hadiths yet',
                                  'لا توجد أحاديث محفوظة حتى الآن'),
                              textAlign: TextAlign.center,
                                textDirection: _textDirection,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: bookmarks.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, index) {
                              final h = bookmarks[index];
                              return ListTile(
                                onTap: () {
                                  setState(() {
                                    _searchQuery = h['no']!;
                                    _searchController.text = h['no']!;
                                    _expandedHadithNo = h['no']!;
                                  });
                                  Navigator.pop(sheetContext);
                                },
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF0D5C3A),
                                  foregroundColor: Colors.white,
                                  child: Text(widget.language == 'ar' ? _number(h) : h['no']!),
                                ),
                                title: Text(
                                  '${_t('হাদিস', 'Hadith', 'الحديث')} ${widget.language == 'ar' ? _number(h) : h['no']}: ${_hadithTitle(h)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  _hadithText(h),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  tooltip: _t('বুকমার্ক সরান', 'Remove bookmark', 'إزالة من المحفوظات'),
                                  icon: const Icon(
                                    Icons.bookmark_remove_outlined,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    await _toggleBookmark(h['no']!);
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _allHadiths.where((h) {
    String q = _searchQuery.toLowerCase().trim();
    final englishNumber = q.replaceAllMapped(
      RegExp(r'[০-৯]'),
      (m) => '${'০১২৩৪৫৬৭৮৯'.indexOf(m[0]!)}',
    );
    final banglaNumber = q.replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => '০১২৩৪৫৬৭৮৯'[int.parse(m[0]!)],
    );
    return h['no']!.contains(q) ||
          h['no']!.contains(banglaNumber) ||
          _number(h).contains(englishNumber) ||
          _hadithTitle(h).toLowerCase().contains(q) ||
          _hadithText(h).toLowerCase().contains(q) ||
          _hadithNarrator(h).toLowerCase().contains(q);
  }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('৪০ হাদিস', '40 Hadith', 'الأحاديث الأربعون'), textDirection: _textDirection, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          // ফন্ট সাইজ ছোট/বড় করার বাটন
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            tooltip: _t('ফন্ট ছোট করুন', 'Decrease font size', 'تصغير الخط'),
            onPressed: () => _updateFontSize(-1.5),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 22),
            tooltip: _t('ফন্ট বড় করুন', 'Increase font size', 'تكبير الخط'),
            onPressed: () => _updateFontSize(1.5),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: _t('সংরক্ষিত হাদিস', 'Bookmarks', 'الأحاديث المحفوظة'),
            onPressed: _showBookmarksSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
                textDirection: _textDirection,
            onChanged: (val) => setState(() {
              _searchQuery = val;
              _expandedHadithNo = null;
            }),
              decoration: InputDecoration(
                hintText: _t('হাদিস নম্বর বা বিষয় দিয়ে খুঁজুন...', 'Search hadith...', 'ابحث برقم الحديث أو موضوعه...'),
                hintTextDirection: _textDirection,
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0D5C3A)),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(_t('কোনো হাদিস পাওয়া যায়নি', 'No hadith found', 'لم يتم العثور على أحاديث'), textDirection: _textDirection))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final h = filtered[idx];
                      bool isMarked = _bookmarkedHadiths.contains(h['no']);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: ExpansionTile(
                          key: PageStorageKey('hadith-${h['no']}'),
                          initiallyExpanded: _expandedHadithNo == h['no'],
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0D5C3A),
                            foregroundColor: Colors.white,
                            child: Text(h['no']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text(
                            _t(
                              'হাদিস ${h['no']}: ${_hadithTitle(h)}',
                              'Hadith ${_number(h)}: ${_hadithTitle(h)}',
                              'الحديث ${_number(h)}: ${_hadithTitle(h)}',
                            ),
                            textDirection: _textDirection,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(_hadithText(h), maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: _textDirection, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: IconButton(
                            icon: Icon(isMarked ? Icons.bookmark : Icons.bookmark_border, color: isMarked ? Colors.amber.shade700 : Colors.grey),
                            onPressed: () => _toggleBookmark(h['no']!),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // সুন্দর নাসখ আরবী ফন্ট ও ফ্রেম
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E2621) : const Color(0xFFFBFDFB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF0D5C3A).withOpacity(0.2)),
                                    ),
                                    child: Directionality(
                                      textDirection: ui.TextDirection.rtl,
                                      child: Text(
                                        h['arabic'] ?? '',
                                        textAlign: TextAlign.justify,
                                        style: TextStyle(
                                          fontSize: _arabicFontSize,
                                          height: 1.9,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0,
                                          fontFamilyFallback: const ['Noto Naskh Arabic', 'Traditional Arabic', 'Amiri', 'sans-serif'],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // ভাষাভিত্তিক অর্থ ও অনুবাদ
                                  Text(
                                    _t('বাংলা অর্থ:', 'English translation:', 'المعنى والشرح:'),
                                    textDirection: _textDirection,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _hadithMeaning(h),
                                    textDirection: _textDirection,
                                    style: const TextStyle(fontSize: 14.5, height: 1.8),
                                  ),
                                  const Divider(height: 22),

                                  // রাবি ও সূত্র
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(_t('বর্ণনাকারী: ${_hadithNarrator(h)}', 'Narrator: ${_hadithNarrator(h)}', 'الراوي: ${_hadithNarrator(h)}'), textDirection: _textDirection, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey))),
                                      if (widget.isBn || widget.language == 'ar')
                                              Container(
                                                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                        child: Text(_hadithGrade(h), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (widget.isBn || widget.language == 'ar')
                                                Text(_t('সূত্র: ${_hadithSource(h)}', 'Source: ${_hadithSource(h)}', 'المصدر: ${_hadithSource(h)}'), textDirection: _textDirection, style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 12),

                                   // এআই শিক্ষা ও তাদাব্বুর
                                  if (widget.isBn || widget.language == 'ar')
                 Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF143526) : const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFF0D5C3A)),
                                            const SizedBox(width: 6),
                                            Text(_t('প্রাপ্ত শিক্ষা ও তাদাব্বুর:', 'Lesson & Reflection:', 'الفوائد والتدبر:'), textDirection: _textDirection, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A), fontSize: 13)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(_hadithLesson(h), textDirection: _textDirection, style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
