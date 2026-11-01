import 'package:flutter/material.dart';

class HadithScreen extends StatelessWidget {
  final bool isBn;
  const HadithScreen({super.key, required this.isBn});

  final List<Map<String, String>> hadithList = const [
    {
      'no': '১',
      'arabic': 'عَنْ أَمِيرِ الْمُؤْمِنِينَ أَبِي حَفْصٍ عُمَرَ بْنِ الْخَطَابِ رَضِيَ اللهُ عَنْهُ قَالَ: سَمِعْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّم يَقُولُ: "إِنَّمَا الْأَعْمَالُ بِالنَّيَّاتِ..."',
      'bangla': 'সমস্ত কাজের ফলাফল নির্ভর করে নিয়্যতের উপর, আর প্রত্যেক ব্যক্তি যা নিয়্যত করেছে তাই পাবে...',
      'english': 'Actions are according to intentions, and everyone will get what was intended...',
      'source': 'সহীহ বুখারী (১) ও সহীহ মুসলিম (১৯০৭)',
      'lesson': 'শিক্ষা: প্রতিটি নেক আমল আল্লাহর সন্তুষ্টির জন্য ইখলাসের সাথে করতে হবে।'
    },
    {
      'no': '২',
      'arabic': 'عَنْ عُمَرَ رَضِيَ اللَّهُ عَنْهُ أَيْضًا قَالَ: بَيْنَمَا نَحْنُ جُلُوسٌ عِنْدَ رَسُولِ اللهِ... يَا مُحَمَّدُ أَخْبِرْنِي عَنْ الْإِسْلَامِ...',
      'bangla': 'জিবরীল (আঃ)-এর আগমন এবং ইসলাম, ঈমান ও ইহসান সম্পর্কে শিক্ষা দান...',
      'english': 'The coming of angel Jibril (AS) teaching Islam, Iman and Ihsan...',
      'source': 'সহীহ মুসলিম (৮)',
      'lesson': 'শিক্ষা: দ্বীনের মৌলিক ভিত্তি ও আদব শিক্ষা দেওয়ার জন্য এই হাদিসটি অত্যন্ত গুরুত্বপূর্ণ।'
    },
    {
      'no': '৩',
      'arabic': 'بُنِيَ الْإِسْلَامُ عَلَى خَمْسٍ: شَهَادَةِ أَنْ لَا إِلَهَ إِلَّا اللهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ...',
      'bangla': 'পাঁচটি বিষয়ের উপর ইসলামের বুনিয়াদ রাখা হয়েছে—ঈমান, সালাত, যাকাত, হজ ও সওম।',
      'english': 'Islam is built upon five pillars: Shahadah, Salah, Zakah, Hajj, and Sawm.',
      'source': 'সহীহ বুখারী (৮) ও সহীহ মুসলিম (১৬)',
      'lesson': 'শিক্ষা: একজন মুসলিমের জীবনের পাঁচটি প্রধান স্তম্ভ সবসময় মজবুত রাখতে হবে।'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isBn ? '৪০ হাদিস বিভাগ' : '40 Hadiths', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: hadithList.length,
        itemBuilder: (context, index) {
          final h = hadithList[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0D5C3A),
                foregroundColor: Colors.white,
                child: Text(h['no']!),
              ),
              title: Text(isBn ? 'হাদিস - ${h['no']}' : 'Hadith ${h['no']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isBn ? h['bangla']! : h['english']!, maxLines: 1, overflow: TextOverflow.ellipsis),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(h['arabic']!, textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, height: 1.6, fontWeight: FontWeight.bold)),
                      const Divider(height: 20),
                      Text(isBn ? h['bangla']! : h['english']!, style: const TextStyle(fontSize: 15, height: 1.5)),
                      const SizedBox(height: 8),
                      Text(h['source']!, style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                        child: Text(h['lesson']!, style: const TextStyle(fontSize: 13, color: Color(0xFF0D5C3A), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
