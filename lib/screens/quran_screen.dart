import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
  String _t(String bn, String en) => widget.isBn ? bn : en;
  late PdfViewerController _pdfController;
  int _currentPage = 2;
  int _pageCount = 611;
  Set<int> _bookmarks = {};
  String _searchQuery = '';
  String? _pdfPath;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadError;
  bool _pdfLoaded = false;
  bool _restoredPage = false;

  static const String _pdfUrl =
      'https://github.com/aziztanjim297-cyber/dainik-amol-app/releases/download/v1.0.0/quran.pdf';

  final List<Map<String, dynamic>> _surahs = QuranData.getSurahs();

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _loadState();
    _preparePdf();
  }


  Future<void> _preparePdf() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/quran.pdf');

      if (await file.exists() && await file.length() > 1000) {
        if (mounted) setState(() => _pdfPath = file.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadError = _t('ফাইল প্রস্তুত করা যায়নি: $e', 'Could not prepare file: $e'));
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadError = null;
    });

    final client = http.Client();
    File? target;
    IOSink? sink;

    try {
      final dir = await getApplicationSupportDirectory();
      target = File('${dir.path}/quran.pdf');

      final response = await client.send(
        http.Request('GET', Uri.parse(_pdfUrl)),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      sink = target.openWrite();
      var received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;

        if (mounted && total > 0) {
          setState(() => _downloadProgress = received / total);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (received < 1000) {
        throw Exception(_t('ডাউনলোড অসম্পূর্ণ', 'Download incomplete'));
      }

      final header = await target.openRead(0, 5).fold<List<int>>(
        <int>[],
        (a, b) => a..addAll(b),
      );

      if (String.fromCharCodes(header) != '%PDF-') {
        throw Exception(_t('বৈধ PDF পাওয়া যায়নি', 'Invalid PDF file'));
      }

      if (mounted) {
        setState(() {
          _pdfPath = target!.path;
          _isDownloading = false;
          _downloadProgress = 1;
        });
      }
    } catch (e) {
      if (sink != null) await sink.close();
      if (target != null && await target.exists()) {
        await target.delete();
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadError = _t('ডাউনলোড ব্যর্থ: $e', 'Download failed: $e');
        });
      }
    } finally {
      client.close();
    }
  }

  Widget _buildDownloadPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book,
              size: 64,
              color: Color(0xFF0D5C3A),
            ),
            const SizedBox(height: 16),
            Text(
              _t('কুরআন শরীফ পড়তে প্রথমে ডাউনলোড করুন', 'Download the Quran to start reading'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(_t('ফাইলের আকার প্রায় ৪২ MB। একবার ডাউনলোড হলে অফলাইনে পড়তে পারবেন।', 'File size is about 42 MB. Once downloaded, you can read it offline.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _downloadProgress > 0
                    ? _downloadProgress
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                _downloadProgress > 0
                    ? '${(_downloadProgress * 100).toStringAsFixed(0)}% ${_t('ডাউনলোড হয়েছে', 'downloaded')}'
                    : _t('ডাউনলোড হচ্ছে...', 'Downloading...'),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.download),
                label: Text(_t('কুরআন শরীফ ডাউনলোড করুন', 'Download Quran')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D5C3A),
                  foregroundColor: Colors.white,
                ),
              ),
            if (_downloadError != null) ...[
              const SizedBox(height: 12),
              Text(
                _downloadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
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
                    Text(_t('সংরক্ষিত বুকমার্কসমূহ', 'Saved Bookmarks'),
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
                  Expanded(
                    child: Center(child: Text(_t('কোনো পৃষ্ঠা বুকমার্ক করা নেই', 'No bookmarked pages'))),
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
                            _t('পৃষ্ঠা নম্বর $page', 'Page $page'),
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
        title: Text(_t('পৃষ্ঠা নম্বরে যান', 'Go to Page')),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: _t('পৃষ্ঠা নম্বর লিখুন', 'Enter page number'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('বাতিল', 'Cancel')),
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
            child: Text(_t('যান', 'Go')),
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
            return (widget.isBn ? s['name'] : s['nameEn'])
                    .toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
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
                    Text(_t('১১৪টি সূরার সূচিপত্র', '114 Surah Index'),
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
                    hintText: _t('সূরার নাম দিয়ে খুঁজুন...', 'Search Surah name...'),
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
                          widget.isBn ? '${s['name']}' : '${s['nameEn']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          _t('পৃষ্ঠা ${s['page']}', 'Page ${s['page']}'),
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
        title: Text(
          _t('পবিত্র কুরআন', 'The Holy Quran'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: _t('সূচিপত্র', 'Surah Index'),
            onPressed: _showIndexSheet,
          ),
          IconButton(
            icon: const Icon(Icons.pin_invoke),
            tooltip: _t('পৃষ্ঠায় যান', 'Go to Page'),
            onPressed: _showJumpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks),
            tooltip: _t('বুকমার্ক তালিকা', 'Bookmarks'),
            onPressed: _showBookmarksSheet,
          ),
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? Colors.amberAccent : Colors.white,
            ),
            tooltip: _t('বুকমার্ক', 'Bookmark'),
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
                  _t('পৃষ্ঠা: $_currentPage / $_pageCount', 'Page: $_currentPage / $_pageCount'),
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
            child: _pdfPath == null
                ? _buildDownloadPanel()
                : SfPdfViewer.file(
              File(_pdfPath!),
              controller: _pdfController,
              scrollDirection: PdfScrollDirection.horizontal,
              pageLayoutMode: PdfPageLayoutMode.single,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              canShowPaginationDialog: false,
              enableTextSelection: false,
              pageSpacing: 0,
              onDocumentLoaded: (d) async {
                if (!mounted) return;

                final prefs = await SharedPreferences.getInstance();
                if (!mounted) return;

                final savedPage = prefs.getInt('quran_last_page') ?? 2;
                final page = savedPage.clamp(1, d.document.pages.count);

                setState(() {
                  _pageCount = d.document.pages.count;
                  _pdfLoaded = true;
                  _restoredPage = true;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && page > 1) {
                    _pdfController.jumpToPage(page);
                  }
                });
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
                  label: Text(_t('আগের পৃষ্ঠা', 'Previous Page')),
                ),
                TextButton.icon(
                  onPressed: _showJumpDialog,
                  icon: const Icon(
                    Icons.format_list_numbered,
                    size: 16,
                  ),
                  label: Text(_t('পৃষ্ঠা পরিবর্তন', 'Go to Page')),
                ),
                TextButton.icon(
                  onPressed: _currentPage < _pageCount
                      ? () => _jump(_currentPage + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: Text(_t('পরের পৃষ্ঠা', 'Next Page')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
