import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/quran_data.dart';

class QuranScreen extends StatefulWidget {
  final bool isBn;
  final String language;

  const QuranScreen({
    super.key,
    required this.isBn,
    String? language,
  }) : language = language ?? (isBn ? 'bn' : 'en');

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  String _t(String bn, String en, [String? ar]) =>
      widget.language == 'ar' ? (ar ?? en) : (widget.isBn ? bn : en);

  String _localizeDigits(String value) {
    if (widget.language != 'ar') return value;
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return value.split('').map((char) {
      final index = western.indexOf(char);
      return index == -1 ? char : arabic[index];
    }).join();
  }
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


  Future<bool> _isValidPdf(File file) async {
    try {
      if (!await file.exists() || await file.length() < 1000) return false;
      final header = await file.openRead(0, 5).fold<List<int>>(
        <int>[],
        (a, b) => a..addAll(b),
      );
      return String.fromCharCodes(header) == '%PDF-';
    } catch (_) {
      return false;
    }
  }

  Future<void> _preparePdf() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/quran.pdf');
      final part = File('${dir.path}/quran.pdf.part');

      if (await part.exists()) await part.delete();

      if (await _isValidPdf(file)) {
        if (mounted) setState(() => _pdfPath = file.path);
      } else if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadError = _t(
          'ফাইল প্রস্তুত করা যায়নি: $e',
          'Could not prepare file: $e',
          'تعذّر تجهيز الملف: $e',
        ));
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
    IOSink? sink;
    File? partFile;

    try {
      final dir = await getApplicationSupportDirectory();
      final target = File('${dir.path}/quran.pdf');
      partFile = File('${dir.path}/quran.pdf.part');

      if (await partFile.exists()) await partFile.delete();

      final response = await client
          .send(http.Request('GET', Uri.parse(_pdfUrl)))
          .timeout(const Duration(minutes: 2));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      sink = partFile.openWrite();
      var received = 0;

      await for (final chunk in response.stream.timeout(
        const Duration(minutes: 2),
      )) {
        sink.add(chunk);
        received += chunk.length;

        if (mounted && total > 0) {
          setState(() => _downloadProgress = received / total);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (received < 1000 || (total > 0 && received != total)) {
        throw Exception(_t(
          'ডাউনলোড অসম্পূর্ণ',
          'Download incomplete',
          'التنزيل غير مكتمل',
        ));
      }

      if (!await _isValidPdf(partFile)) {
        throw Exception(_t(
          'বৈধ PDF পাওয়া যায়নি',
          'Invalid PDF file',
          'ملف PDF غير صالح',
        ));
      }

      // যাচাইকৃত অস্থায়ী ফাইলটি মূল PDF হিসেবে সংরক্ষণ।
      final savedFile = await partFile.rename(target.path);

      if (mounted) {
        setState(() {
          _pdfPath = savedFile.path;
          _isDownloading = false;
          _downloadProgress = 1;
        });
      }
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }

      if (partFile != null && await partFile.exists()) {
        await partFile.delete();
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadError = _t(
            'ডাউনলোড ব্যর্থ: $e',
            'Download failed: $e',
            'فشل التنزيل: $e',
          );
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
              _t('কুরআন শরীফ পড়তে প্রথমে ডাউনলোড করুন', 'Download the Quran to start reading', 'حمّل القرآن الكريم لبدء القراءة'),
              textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(_t('ফাইলের আকার প্রায় ৪২ MB। একবার ডাউনলোড হলে অফলাইনে পড়তে পারবেন।', 'File size is about 42 MB. Once downloaded, you can read it offline.', 'حجم الملف حوالي ٤٢ ميغابايت. يمكنك قراءته دون اتصال بعد تنزيله.'),
              textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
                    ? '${(_downloadProgress * 100).toStringAsFixed(0)}% ${_t('ডাউনলোড হয়েছে', 'downloaded', 'تم التنزيل')}'
                    : _t('ডাউনলোড হচ্ছে...', 'Downloading...', 'جارٍ التنزيل...'),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.download),
                label: Text(_t('কুরআন শরীফ ডাউনলোড করুন', 'Download Quran', 'تنزيل القرآن الكريم')),
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

    final last = (prefs.getInt('quran_last_page') ?? 2)
        .clamp(1, _pageCount).toInt();
    final bMarks = prefs.getStringList('quran_bmarks') ?? [];
    final oldMarks = prefs.getStringList('quran_bookmarks_list') ?? [];

    final allMarks = {
      ...bMarks.map((e) => int.tryParse(e)).whereType<int>(),
      ...oldMarks.map((e) => int.tryParse(e)).whereType<int>(),
    }.where((page) => page >= 1 && page <= _pageCount).toSet();

    await prefs.setStringList(
      'quran_bmarks',
      (allMarks.toList()..sort()).map((e) => e.toString()).toList(),
    );

    if (!mounted) return;

    setState(() {
      _currentPage = last;
      _bookmarks = allMarks;
    });
  }

  Future<void> _onPageChanged(PdfPageChangedDetails details) async {
    final p = details.newPageNumber;
    if (p < 1 || p > _pageCount) return;

    if (mounted) {
      setState(() => _currentPage = p);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_page', p);
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
      }
    });

    final pages = _bookmarks.toList()..sort();
    await prefs.setStringList(
      'quran_bmarks',
      pages.map((e) => e.toString()).toList(),
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
                    Text(_t('সংরক্ষিত বুকমার্কসমূহ', 'Saved Bookmarks', 'العلامات المرجعية المحفوظة'), textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
                    child: Center(child: Text(_t('কোনো পৃষ্ঠা বুকমার্ক করা নেই', 'No bookmarked pages', 'لا توجد صفحات محفوظة'), textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr)),
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
                            _t('পৃষ্ঠা নম্বর $page', 'Page $page', 'الصفحة رقم $page'),
                            textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
        title: Text(_t('পৃষ্ঠা নম্বরে যান', 'Go to Page', 'الانتقال إلى صفحة')),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: _t('পৃষ্ঠা নম্বর লিখুন', 'Enter page number', 'أدخل رقم الصفحة'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('বাতিল', 'Cancel', 'إلغاء')),
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
            child: Text(_t('যান', 'Go', 'انتقال')),
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
            return (widget.language == 'ar'
                        ? s['nameAr']
                        : (widget.isBn ? s['name'] : s['nameEn']))
                    .toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s['nameAr'].toString().contains(_searchQuery) ||
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
                    Text(_t('১১৪টি সূরার সূচিপত্র', '114 Surah Index', 'فهرس السور الـ١١٤'),
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
                    textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  onChanged: (val) {
                    setModalState(() => _searchQuery = val);
                  },
                  decoration: InputDecoration(
                    hintText: _t('সূরার নাম দিয়ে খুঁজুন...', 'Search Surah name...', 'ابحث عن اسم السورة...'),
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
                            _localizeDigits('${s['no']}'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        title: Directionality(
                          textDirection: widget.language == 'ar'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            widget.language == 'ar'
                                ? '${s['nameAr']}'
                                : (widget.isBn ? '${s['name']}' : '${s['nameEn']}'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        trailing: Text(
                          _localizeDigits(_t('পৃষ্ঠা ${s['page']}', 'Page ${s['page']}', 'الصفحة ${s['page']}')),
                          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
          _t('পবিত্র কুরআন', 'The Holy Quran', 'القرآن الكريم'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: _t('সূচিপত্র', 'Surah Index', 'فهرس السور'),
            onPressed: _showIndexSheet,
          ),
          IconButton(
            icon: const Icon(Icons.pin_invoke),
            tooltip: _t('পৃষ্ঠায় যান', 'Go to Page', 'الانتقال إلى صفحة'),
            onPressed: _showJumpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks),
            tooltip: _t('বুকমার্ক তালিকা', 'Bookmarks', 'العلامات المرجعية'),
            onPressed: _showBookmarksSheet,
          ),
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? Colors.amberAccent : Colors.white,
            ),
            tooltip: _t('বুকমার্ক', 'Bookmark', 'إضافة علامة مرجعية'),
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
                  _t('পৃষ্ঠা: $_currentPage / $_pageCount', 'Page: $_currentPage / $_pageCount', 'الصفحة: $_currentPage / $_pageCount'),
          textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
                final page = savedPage.clamp(1, d.document.pages.count).toInt();

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
                  label: Text(_t('আগের পৃষ্ঠা', 'Previous Page', 'الصفحة السابقة'), textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                ),
                TextButton.icon(
                  onPressed: _showJumpDialog,
                  icon: const Icon(
                    Icons.format_list_numbered,
                    size: 16,
                  ),
                  label: Text(_t('পৃষ্ঠা পরিবর্তন', 'Go to Page', 'الانتقال إلى صفحة'), textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                ),
                TextButton.icon(
                  onPressed: _currentPage < _pageCount
                      ? () => _jump(_currentPage + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: Text(_t('পরের পৃষ্ঠা', 'Next Page', 'الصفحة التالية'), textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
