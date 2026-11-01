import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HadithScreen extends StatefulWidget {
  final bool isBn;
  const HadithScreen({super.key, required this.isBn});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  String _searchQuery = '';
  Set<String> _bookmarkedHadiths = {};

  final List<Map<String, String>> hadithList = const [
    {
      'no': '১',
      'arabic': 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى...',
      'bangla': 'সমস্ত কাজের ফলাফল নির্ভর করে নিয়্যতের উপর, আর প্রত্যেক ব্যক্তি যা নিয়্যত করেছে তাই পাবে...',
      'narrator': 'উমার ইবন আল-খাত্তাব (রাঃ)',
      'source': 'সহীহ বুখারী (১), সহীহ মুসলিম (১৯০৭)',
      'grade': 'মুতাওয়াতির (সর্বোচ্চ বিশুদ্ধ)',
      'lesson': 'শিক্ষা: প্রতিটি নেক আমলের পূর্বে নিয়ত বিশুদ্ধ ও একমাত্র আল্লাহর সন্তুষ্টির উদ্দেশ্যে হতে হবে।'
    },
    {
      'no': '২',
      'arabic': 'بَيْنَمَا نَحْنُ جُلُوسٌ عِنْدَ رَسُولِ اللهِ... يَا مُحَمَّدُ أَخْبِرْنِي عَنْ الإِسْلاَمِ...',
      'bangla': 'একদিন আমরা রাসূলুল্লাহর নিকট বসেছিলাম, হঠাৎ ধবধবে সাদা কাপড়ে এক ব্যক্তি এসে ইসলাম ও ঈমান সম্পর্কে জিজ্ঞাসা করলেন...',
      'narrator': 'উমার ইবন আল-খাত্তাব (রাঃ)',
      'source': 'সহীহ মুসলিম (৮)',
      'grade': 'সহীহ',
      'lesson': 'শিক্ষা: ইসলাম, ঈমান ও ইহসানের পরিপূর্ণ সংজ্ঞা এবং দ্বীনি মজলিসের আদব শিক্ষা।'
    },
    {
      'no': '৩',
      'arabic': 'بُنِيَ الإِسْلاَمُ عَلَى خَمْسٍ: شَهَادَةِ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ...',
      'bangla': 'পাঁচটি বিষয়ের উপর ইসলামের বুনিয়াদ রাখা হয়েছে—তাওহীদ ও রিসালাতের সাক্ষ্য, সালাত, যাকাত, হজ ও রমাদানের সওম।',
      'narrator': 'আব্দুল্লাহ ইবন উমার (রাঃ)',
      'source': 'সহীহ বুখারী (৮), সহীহ মুসলিম (১৬)',
      'grade': 'সহীহ',
      'lesson': 'শিক্ষা: একজন মুসলিমের জীবনের ৫টি বুনিয়াদি ভিত্তি সর্বদা মজবুত রাখতে হবে।'
    },
    {
      'no': '৪',
      'arabic': 'إِنَّ أَحَدَكُمْ يُجْمَعُ خَلْقُهُ فِي بَطْنِ أُمِّهِ أَرْبَعِينَ يَوْمًا نُطْفَةً...',
      'bangla': 'তোমাদের প্রত্যেকের সৃষ্টি মাতৃগর্ভে চল্লিশ দিন শুক্রবিন্দু, চল্লিশ দিন রক্তপিণ্ড ও চল্লিশ দিন মাংসপিণ্ডরূপে গঠিত হয়...',
      'narrator': 'আব্দুল্লাহ ইবন মাসউদ (রাঃ)',
      'source': 'সহীহ বুখারী (৩২০৮), সহীহ মুসলিম (২৬৪৩)',
      'grade': 'সহীহ',
      'lesson': 'শিক্ষা: তাকদীরের উপর পূর্ণ বিশ্বাস এবং মানব সৃষ্টির অলৌকিকত্ব স্মরণ রাখা।'
    },
    {
      'no': '৫',
      'arabic': 'مَنْ أَحْدَثَ فِي أَمْرِنَا هَذَا مَا لَيْسَ مِنْهُ فَهُوَ رَدٌّ',
      'bangla': 'যে ব্যক্তি আমাদের এই দ্বীনের মাঝে এমন নতুন কিছুর উদ্ভাবন করবে যা তার অংশ নয়, তা প্রত্যাখ্যাত হবে।',
      'narrator': 'উম্মুল মুমিনীন আয়েশা (রাঃ)',
      'source': 'সহীহ বুখারী (২৬৯৭), সহীহ মুসলিম (১৭১৮)',
      'grade': 'সহীহ',
      'lesson': 'শিক্ষা: দ্বীনের মধ্যে সকল প্রকার বিদআত বর্জনীয় এবং সুন্নাহ অনুযায়ী আমল বাধ্যতামূলক।'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _bookmarkedHadiths = (prefs.getStringList('hadith_bookmarks') ?? []).toSet());
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
    await prefs.setStringList('hadith_bookmarks', _bookmarkedHadiths.toList());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = hadithList.where((h) {
      String q = _searchQuery.toLowerCase();
      return h['no']!.contains(q) || h['bangla']!.toLowerCase().contains(q) || h['arabic']!.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('৪০ হাদিস বিভাগ', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'হাদিস নম্বর, শব্দ বা অনুবাদ দিয়ে অনুসন্ধান...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final h = filtered[idx];
                bool isBookmarked = _bookmarkedHadiths.contains(h['no']);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0D5C3A),
                      foregroundColor: Colors.white,
                      child: Text(h['no']!),
                    ),
                    title: Text('হাদিস - ${h['no']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(h['bangla']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: const Color(0xFF0D5C3A)),
                      onPressed: () => _toggleBookmark(h['no']!),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(h['arabic']!, textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, height: 1.6, fontWeight: FontWeight.bold)),
                            const Divider(height: 20),
                            Text(h['bangla']!, style: const TextStyle(fontSize: 15, height: 1.5)),
                            const SizedBox(height: 8),
                            Text('বর্ণনাকারী: ${h['narrator']} | মান: ${h['grade']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            Text('সূত্র: ${h['source']}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                              child: Text(h['lesson']!, style: const TextStyle(fontSize: 13, color: Color(0xFF0D5C3A), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      )
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
