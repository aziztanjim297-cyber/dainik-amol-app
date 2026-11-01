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
  final TextEditingController _pageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookmark();
  }

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currentPage = prefs.getInt('quran_page') ?? 1);
  }

  Future<void> _setPage(int p) async {
    if (p < 1 || p > _totalPages) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_page', p);
    setState(() => _currentPage = p);
  }

  void _showJumpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('সরাসরি পৃষ্ঠায় যান (১ - ৬০৪)'),
        content: TextField(
          controller: _pageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'পৃষ্ঠা নম্বর লিখুন'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              int? p = int.tryParse(_pageController.text);
              if (p != null) _setPage(p);
              Navigator.pop(ctx);
            },
            child: const Text('যান'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String pageImg = _currentPage.toString().padLeft(3, '0');
    // কিং ফাহাদ ও মদিনা মুসহাফের হাই-রেজ্যুলেশন আসল পৃষ্ঠা
    String imageUrl = "https://raw.githubusercontent.com/Govar/quran-images/master/images/page$pageImg.png";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'পবিত্র কুরআন (১৫ লাইন মুসহাফ)' : 'Quran 15-Lines', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.pin_invoke), onPressed: _showJumpDialog),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('পৃষ্ঠা $_currentPage সংরক্ষণ করা হয়েছে')));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentPage > 1 ? () => _setPage(_currentPage - 1) : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('পূর্ববর্তী'),
                ),
                Text('পৃষ্ঠা: $_currentPage / $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: _currentPage < _totalPages ? () => _setPage(_currentPage + 1) : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('পরবর্তী'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: const Color(0xFFFFFDF7),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0D5C3A)));
                },
                errorBuilder: (ctx, err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 50, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text('পৃষ্ঠা $_currentPage লোড হতে ইন্টারনেট সংযোগ প্রয়োজন।'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
