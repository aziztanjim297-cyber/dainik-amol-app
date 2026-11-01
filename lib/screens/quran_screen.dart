import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class QuranScreen extends StatefulWidget {
  final bool isBn;
  const QuranScreen({super.key, required this.isBn});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late PdfViewerController _pdfViewerController;
  int _currentPage = 1;
  int _pageCount = 604;
  Set<int> _bookmarks = {};
  int _pagesReadToday = 0;
  final String _todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // প্রধান সূরার ইনডেক্স
  final List<Map<String, dynamic>> surahIndex = [
    {'no': 1, 'nameBn': 'আল-ফাতিহা', 'nameEn': 'Al-Fatiha', 'page': 1},
    {'no': 2, 'nameBn': 'আল-বাকারা', 'nameEn': 'Al-Baqarah', 'page': 2},
    {'no': 3, 'nameBn': 'আলে ইমরান', 'nameEn': 'Ali \'Imran', 'page': 50},
    {'no': 4, 'nameBn': 'আন-নিসা', 'nameEn': 'An-Nisa', 'page': 77},
    {'no': 5, 'nameBn': 'আল-মায়িদাহ', 'nameEn': 'Al-Ma\'idah', 'page': 106},
    {'no': 6, 'nameBn': 'আল-আনআম', 'nameEn': 'Al-An\'am', 'page': 128},
    {'no': 7, 'nameBn': 'আল-আরাফ', 'nameEn': 'Al-A\'raf', 'page': 151},
    {'no': 8, 'nameBn': 'আল-আনফাল', 'nameEn': 'Al-Anfal', 'page': 177},
    {'no': 9, 'nameBn': 'আত-তাওবাহ', 'nameEn': 'At-Tawbah', 'page': 187},
    {'no': 10, 'nameBn': 'ইউনুস', 'nameEn': 'Yunus', 'page': 208},
    {'no': 12, 'nameBn': 'ইউসুফ', 'nameEn': 'Yusuf', 'page': 235},
    {'no': 18, 'nameBn': 'আল-কাহফ', 'nameEn': 'Al-Kahf', 'page': 293},
    {'no': 19, 'nameBn': 'মারইয়াম', 'nameEn': 'Maryam', 'page': 305},
    {'no': 20, 'nameBn': 'ত্বাহা', 'nameEn': 'Ta-Ha', 'page': 312},
    {'no': 36, 'nameBn': 'সূরা ইয়াসিন', 'nameEn': 'Surah Ya-Sin', 'page': 440},
    {'no': 55, 'nameBn': 'আর-রাহমান', 'nameEn': 'Ar-Rahman', 'page': 531},
    {'no': 56, 'nameBn': 'সূরা ওয়াকিয়াহ', 'nameEn': 'Surah Al-Waqi\'ah', 'page': 534},
    {'no': 67, 'nameBn': 'সূরা মুলক', 'nameEn': 'Surah Al-Mulk', 'page': 562},
    {'no': 78, 'nameBn': 'আন-নাবা (৩০ পারা)', 'nameEn': 'An-Naba (Juz 30)', 'page': 582},
    {'no': 112, 'nameBn': 'আল-ইখলাস', 'nameEn': 'Al-Ikhlas', 'page': 604},
    {'no': 113, 'nameBn': 'আল-ফালাক', 'nameEn': 'Al-Falaq', 'page': 604},
    {'no': 114, 'nameBn': 'আন-নাস', 'nameEn': 'An-Nas', 'page': 604},
  ];

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    int lastPage = prefs.getInt('quran_last_read_page') ?? 1;
    List<String> bMarks = prefs.getStringList('quran_bookmarks_list') ?? [];
    int readToday = prefs.getInt('quran_read_count_$_todayKey') ?? 0;

    setState(() {
      _currentPage = lastPage;
      _bookmarks = bMarks.map((e) => int.parse(e)).toSet();
      _pagesReadToday = readToday;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pdfViewerController.jumpToPage(_currentPage);
    });
  }

  Future<void> _onPageChanged(PdfPageChangedDetails details) async {
    int pageNum = details.newPageNumber;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_read_page', pageNum);

    if (pageNum != _currentPage) {
      int updated = (_pagesReadToday + 1).clamp(0, 2);
      await prefs.setInt('quran_read_count_$_todayKey', updated);
      setState(() {
        _pagesReadToday = updated;
        _currentPage = pageNum;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
      }
    });
    await prefs.setStringList('quran_bookmarks_list', _bookmarks.map((e) => e.toString()).toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_bookmarks.contains(_currentPage)
              ? (widget.isBn ? 'পৃষ্ঠা $_currentPage বুকমার্ক করা হয়েছে' : 'Page $_currentPage Bookmarked')
              : (widget.isBn ? 'পৃষ্ঠা $_currentPage বুকমার্ক সরানো হয়েছে' : 'Page $_currentPage Unbookmarked')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _jumpToPage(int page) {
    if (page < 1 || page > _pageCount) return;
    _pdfViewerController.jumpToPage(page);
  }

  void _showJumpDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isBn ? 'পৃষ্ঠা নম্বরে যান' : 'Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: widget.isBn ? 'পৃষ্ঠা নম্বর লিখুন' : 'Enter page number',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(widget.isBn ? 'বাতিল' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
            onPressed: () {
              int? p = int.tryParse(controller.text);
              if (p != null) _jumpToPage(p);
              Navigator.pop(ctx);
            },
            child: Text(widget.isBn ? 'যান' : 'Go'),
          ),
        ],
      ),
    );
  }

  void _showIndexSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.isBn ? 'পবিত্র কুরআনের সূচিপত্র' : 'Quran Index', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: surahIndex.length,
                itemBuilder: (context, idx) {
                  final s = surahIndex[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0D5C3A),
                      foregroundColor: Colors.white,
                      child: Text('${s['no']}', style: const TextStyle(fontSize: 12)),
                    ),
                    title: Text(widget.isBn ? s['nameBn'] : s['nameEn'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('${widget.isBn ? "পৃষ্ঠা" : "Page"} ${s['page']}', style: const TextStyle(color: Colors.grey)),
                    onTap: () {
                      _jumpToPage(s['page']);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isBn ? 'সংরক্ষিত বুকমার্কসমূহ' : 'Saved Bookmarks', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
            const Divider(),
            if (_bookmarks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text(widget.isBn ? 'কোনো পৃষ্ঠা বুকমার্ক করা নেই' : 'No bookmarks saved')),
              )
            else
              Expanded(
                child: ListView(
                  children: _bookmarks.map((p) {
                    return ListTile(
                      leading: const Icon(Icons.bookmark, color: Color(0xFF0D5C3A)),
                      title: Text(widget.isBn ? 'পৃষ্ঠা নম্বর $p' : 'Page Number $p', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() => _bookmarks.remove(p));
                          Navigator.pop(ctx);
                          _toggleBookmark();
                        },
                      ),
                      onTap: () {
                        _jumpToPage(p);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isBookmarked = _bookmarks.contains(_currentPage);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'পবিত্র কুরআন (পিডিএফ)' : 'Holy Quran (PDF)', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.list_alt), tooltip: widget.isBn ? 'সূচিপত্র' : 'Index', onPressed: _showIndexSheet),
          IconButton(icon: const Icon(Icons.pin_invoke), tooltip: widget.isBn ? 'পৃষ্ঠায় যান' : 'Jump Page', onPressed: _showJumpDialog),
          IconButton(icon: const Icon(Icons.bookmarks), tooltip: widget.isBn ? 'বুকমার্ক তালিকা' : 'Bookmarks', onPressed: _showBookmarksSheet),
          IconButton(
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: isBookmarked ? Colors.amberAccent : Colors.white),
            tooltip: widget.isBn ? 'বুকমার্ক' : 'Bookmark',
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: Column(
        children: [
          // দৈনিক পড়ার হিসাব
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: isDark ? const Color(0xFF1E2621) : const Color(0xFFE8F5E9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book, color: Color(0xFF0D5C3A), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.isBn ? "দৈনিক লক্ষ্য" : "Daily Goal"}: $_pagesReadToday/২ ${widget.isBn ? "পৃষ্ঠা" : "Pages"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D5C3A)),
                    ),
                  ],
                ),
                Text(
                  '${widget.isBn ? "পৃষ্ঠা" : "Page"}: $_currentPage / $_pageCount',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ডানে-বামে সোয়াইপ হওয়া আসল PDF ভিউয়ার
          Expanded(
            child: SfPdfViewer.asset(
              'assets/quran.pdf',
              controller: _pdfViewerController,
              scrollDirection: PdfScrollDirection.horizontal,
              pageLayoutMode: PdfPageLayoutMode.single,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                setState(() {
                  _pageCount = details.document.pages.count;
                });
              },
              onPageChanged: _onPageChanged,
            ),
          ),

          // নিচে পৃষ্ঠা পরিবর্তনের সহজ কন্ট্রোল বার
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isDark ? const Color(0xFF1E2621) : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _currentPage > 1 ? () => _jumpToPage(_currentPage - 1) : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: Text(widget.isBn ? 'আগের পৃষ্ঠা' : 'Previous'),
                ),
                TextButton.icon(
                  onPressed: _showJumpDialog,
                  icon: const Icon(Icons.format_list_numbered, size: 16),
                  label: Text(widget.isBn ? 'পৃষ্ঠা পরিবর্তন' : 'Go to Page'),
                ),
                TextButton.icon(
                  onPressed: _currentPage < _pageCount ? () => _jumpToPage(_currentPage + 1) : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: Text(widget.isBn ? 'পরের পৃষ্ঠা' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
