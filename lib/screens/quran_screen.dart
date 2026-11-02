import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/quran_data.dart';

class QuranScreen extends StatefulWidget {
  final bool isBn;

  const QuranScreen({super.key, required this.isBn});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late PdfViewerController _pdfController;
  int _currentPage = 2;
  int _pageCount = 611;
  Set<int> _bookmarks = {};
  String _searchQuery = '';

  final List<Map<String, dynamic>> _surahs = QuranData.getSurahs();

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    final last = prefs.getInt('quran_last_page') ?? 2;
    final bMarks = prefs.getStringList('quran_bmarks') ?? [];
    final oldMarks = prefs.getStringList('quran_bookmarks_list') ?? [];
    final allMarks = {
      ...bMarks.map((e) => int.tryParse(e)).whereType<int>(),
      ...oldMarks.map((e) => int.tryParse(e)).whereType<int>(),
    };

    await prefs.setStringList(
      'quran_bmarks',
      allMarks.map((e) => e.toString()).toList(),
    );

    if (!mounted) return;

    setState(() {
      _currentPage = last;
      _bookmarks = allMarks;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_currentPage >= 1 && _currentPage <= _pageCount) {
        _pdfController.jumpToPage(_currentPage);
      }
    });
  }

  Future<void> _onPageChanged(PdfPageChangedDetails details) async {
    final p = details.newPageNumber;

    if (mounted) {
      setState(() {
        _currentPage = p;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_page', p);
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

    await prefs.setStringList(
      'quran_bmarks',
      _bookmarks.map((e) => e.toString()).toList(),
    );
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final pages = _bookmarks.toList()..sort();

          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'সংরক্ষিত বুকমার্কসমূহ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D5C3A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                if (pages.isEmpty)
                  const Expanded(
                    child: Center(child: Text('কোনো পৃষ্ঠা বুকমার্ক করা নেই')),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: pages.length,
                      itemBuilder: (ctx, index) {
                        final page = pages[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.bookmark,
                            color: Color(0xFF0D5C3A),
                          ),
                          title: Text(
                            'পৃষ্ঠা নম্বর $page',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              setState(() => _bookmarks.remove(page));
                              setModalState(() {});
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setStringList(
                                'quran_bmarks',
                                _bookmarks.map((e) => e.toString()).toList(),
                              );
                            },
                          ),
                          onTap: () {
                            _jump(page);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _jump(int page) {
    if (page < 1 || page > _pageCount) return;
    _pdfController.jumpToPage(page);
  }

  void _showJumpDialog() {
    final c = TextEditingController(text: '$_currentPage');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('পৃষ্ঠা নম্বরে যান'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'পৃষ্ঠা নম্বর লিখুন',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D5C3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final p = int.tryParse(c.text);
              if (p != null) _jump(p);
              Navigator.pop(ctx);
            },
            child: const Text('যান'),
          ),
        ],
      ),
    ).then((_) => c.dispose());
  }

  void _showIndexSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final list = _surahs.where((s) {
            return s['name'].toString().contains(_searchQuery) ||
                s['no'].toString() == _searchQuery;
          }).toList();

          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '১১৪টি সূরার সূচিপত্র',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D5C3A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                TextField(
                  onChanged: (val) {
                    setModalState(() => _searchQuery = val);
                  },
                  decoration: InputDecoration(
                    hintText: 'সূরার নাম দিয়ে খুঁজুন...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (ctx, idx) {
                      final s = list[idx];

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 13,
                          backgroundColor: const Color(0xFF0D5C3A),
                          child: Text(
                            '${s['no']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        title: Text(
                          '${s['name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          'পৃষ্ঠা ${s['page']}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          _jump(s['page']);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBookmarked = _bookmarks.contains(_currentPage);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'পবিত্র কুরআন',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'সূচিপত্র',
            onPressed: _showIndexSheet,
          ),
          IconButton(
            icon: const Icon(Icons.pin_invoke),
            tooltip: 'পৃষ্ঠায় যান',
            onPressed: _showJumpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks),
            tooltip: 'বুকমার্ক তালিকা',
            onPressed: _showBookmarksSheet,
          ),
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? Colors.amberAccent : Colors.white,
            ),
            tooltip: 'বুকমার্ক',
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            color: isDark
                ? const Color(0xFF1E2621)
                : const Color(0xFFE8F5E9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'পৃষ্ঠা: $_currentPage / $_pageCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SfPdfViewer.asset(
              'assets/quran.pdf',
              controller: _pdfController,
              scrollDirection: PdfScrollDirection.horizontal,
              pageLayoutMode: PdfPageLayoutMode.single,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              canShowPaginationDialog: false,
              enableTextSelection: false,
              pageSpacing: 0,
              onDocumentLoaded: (d) {
                if (mounted) {
                  setState(() {
                    _pageCount = d.document.pages.count;
                  });
                }
              },
              onPageChanged: _onPageChanged,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            color: isDark ? const Color(0xFF1E2621) : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _currentPage > 1
                      ? () => _jump(_currentPage - 1)
                      : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text('আগের পৃষ্ঠা'),
                ),
                TextButton.icon(
                  onPressed: _showJumpDialog,
                  icon: const Icon(
                    Icons.format_list_numbered,
                    size: 16,
                  ),
                  label: const Text('পৃষ্ঠা পরিবর্তন'),
                ),
                TextButton.icon(
                  onPressed: _currentPage < _pageCount
                      ? () => _jump(_currentPage + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: const Text('পরের পৃষ্ঠা'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
