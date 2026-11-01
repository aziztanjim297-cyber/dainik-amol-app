import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith_service.dart';

class HadithScreen extends StatefulWidget {
  final bool isBn;
  const HadithScreen({super.key, required this.isBn});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  final List<Map<String, String>> _allHadiths = HadithService.getAllHadiths();
  String _searchQuery = '';
  Set<String> _bookmarkedHadiths = {};
  bool _showOnlyBookmarks = false;
  double _arabicFontSize = 21.0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _allHadiths.where((h) {
      if (_showOnlyBookmarks && !_bookmarkedHadiths.contains(h['no'])) return false;
      String q = _searchQuery.toLowerCase();
      return h['no']!.contains(q) ||
          h['title']!.toLowerCase().contains(q) ||
          h['bangla']!.toLowerCase().contains(q) ||
          h['arabic']!.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? '৪০ হাদিস (শিক্ষা সহ)' : '40 Hadiths (Lessons)', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          // ফন্ট সাইজ ছোট/বড় করার বাটন
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            tooltip: 'ফন্ট ছোট করুন',
            onPressed: () => _updateFontSize(-1.5),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 22),
            tooltip: 'ফন্ট বড় করুন',
            onPressed: () => _updateFontSize(1.5),
          ),
          IconButton(
            icon: Icon(_showOnlyBookmarks ? Icons.bookmarks : Icons.bookmarks_outlined),
            tooltip: widget.isBn ? 'সংরক্ষিত হাদিস' : 'Bookmarks',
            onPressed: () => setState(() => _showOnlyBookmarks = !_showOnlyBookmarks),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: widget.isBn ? 'হাদিস নম্বর বা বিষয় দিয়ে খুঁজুন...' : 'Search hadith...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0D5C3A)),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (_showOnlyBookmarks)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.amber.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.isBn ? 'কেবল বুকমার্ক করা হাদিস প্রদর্শিত হচ্ছে' : 'Showing bookmarks', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown)),
                  TextButton(onPressed: () => setState(() => _showOnlyBookmarks = false), child: Text(widget.isBn ? 'সব দেখুন' : 'Show All')),
                ],
              ),
            ),

          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(widget.isBn ? 'কোনো হাদিস পাওয়া যায়নি' : 'No hadith found'))
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
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0D5C3A),
                            foregroundColor: Colors.white,
                            child: Text(h['no']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text('হাদিস ${h['no']}: ${h['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text(h['bangla']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                                      textDirection: TextDirection.rtl,
                                      child: Text(
                                        h['arabic']!,
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

                                  // বাংলা অর্থ
                                  Text(h['bangla']!, style: const TextStyle(fontSize: 14.5, height: 1.6)),
                                  const Divider(height: 22),

                                  // রাবি ও সূত্র
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text('বর্ণনাকারী: ${h['narrator']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                        child: Text(h['grade']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('সূত্র: ${h['source']}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 12),

                                  // এআই শিক্ষা ও তাদাব্বুর
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
                                            Text(widget.isBn ? 'প্রাপ্ত শিক্ষা ও তাদাব্বুর:' : 'Lesson & Reflection:', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A), fontSize: 13)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(h['lesson']!, style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
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
