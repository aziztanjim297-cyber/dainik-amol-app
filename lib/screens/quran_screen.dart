import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranScreen extends StatefulWidget {
  final bool isBn;
  const QuranScreen({super.key, required this.isBn});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  int _currentPage = 1;
  final int _totalPages = 604;

  @override
  void initState() {
    super.initState();
    _loadBookmark();
  }

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currentPage = prefs.getInt('quran_bookmark') ?? 1);
  }

  Future<void> _saveBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_bookmark', page);
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'পবিত্র কুরআন (১৫ লাইনের মুসহাফ)' : 'Holy Quran (15 Lines)', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(widget.isBn ? 'পৃষ্ঠা $_currentPage বুকমার্ক করা হয়েছে' : 'Page $_currentPage Bookmarked')),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentPage > 1 ? () => _saveBookmark(_currentPage - 1) : null,
                  child: Text(widget.isBn ? 'আগের পৃষ্ঠা' : 'Prev'),
                ),
                Text('পৃষ্ঠা: $_currentPage / $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton(
                  onPressed: _currentPage < _totalPages ? () => _saveBookmark(_currentPage + 1) : null,
                  child: Text(widget.isBn ? 'পরের পৃষ্ঠা' : 'Next'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: const Color(0xFFFFFDF5),
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book, size: 70, color: Color(0xFF0D5C3A)),
                    const SizedBox(height: 16),
                    Text(
                      '১৫ লাইনের মাদানি মুসহাফ (পৃষ্ঠা $_currentPage)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nالْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ\nالرَّحْمَٰنِ الرَّحِيمِ\nمَالِكِ يَوْمِ الدِّينِ\nإِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, height: 2.0, fontFamily: 'serif', fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isBn ? 'প্রতিদিন ২ পৃষ্ঠা তিলাওয়াত পূর্ণ করুন' : 'Complete 2 pages daily recitation',
                      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
