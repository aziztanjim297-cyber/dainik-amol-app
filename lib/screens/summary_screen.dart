import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';
import '../models/history_service.dart';
import '../models/helpers.dart';

class SummaryScreen extends StatefulWidget {
  final bool isBn;
  const SummaryScreen({super.key, required this.isBn});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _reportCardKey = GlobalKey();
  final GlobalKey _weeklyCardKey = GlobalKey();
  final GlobalKey _monthlyCardKey = GlobalKey();
  DateTime _selectedDate = DateTime.now();

  DailyAmolRecord? _dailyRecord;
  Map<String, dynamic> _weeklyStats = {};
  Map<String, dynamic> _monthlyStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final daily = await HistoryService.getRecordForDate(dateStr);
    final weekly = await HistoryService.getWeeklyStats();
    final monthly = await HistoryService.getMonthlyStats();

    setState(() {
      _dailyRecord = daily;
      _weeklyStats = weekly;
      _monthlyStats = monthly;
      _isLoading = false;
    });
  }

  String get _reportType {
    if (_tabController.index == 1) return 'Weekly';
    if (_tabController.index == 2) return 'Monthly';
    return 'Daily';
  }

  GlobalKey get _activeReportKey =>
      _tabController.index == 0
          ? _reportCardKey
          : (_tabController.index == 1 ? _weeklyCardKey : _monthlyCardKey);

  Future<Uint8List?> _captureReport() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _activeReportKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<String> _saveFolder() async {
    final dir = Directory('/sdcard/Download');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  String _fileTimestamp() =>
      DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  Future<void> _saveAsImage() async {
    try {
      final bytes = await _captureReport();
      if (bytes == null) throw Exception('Report not found');

      final folder = await _saveFolder();
      final timestamp = _fileTimestamp();
      final file = File('$folder/Amal_${_reportType}_Report_$timestamp.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D5C3A),
            content: Text(widget.isBn
                ? 'ছবি Download ফোল্ডারে সেভ হয়েছে!'
                : 'Image saved to Download folder!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ছবি সেভ করতে ব্যর্থ: $e')),
        );
      }
    }
  }

  Future<void> _saveAsPdf() async {
    try {
      final bytes = await _captureReport();
      if (bytes == null) throw Exception('Report not found');

      final document = PdfDocument();
      final page = document.pages.add();
      final bitmap = PdfBitmap(bytes);
      final pageSize = page.getClientSize();

      final scale = (pageSize.width / bitmap.width)
          .clamp(0.01, pageSize.height / bitmap.height);
      final width = bitmap.width * scale;
      final height = bitmap.height * scale;

      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH((pageSize.width - width) / 2, 0, width, height),
      );

      final pdfBytes = await document.save();
      document.dispose();

      final folder = await _saveFolder();
      final timestamp = _fileTimestamp();
      final file = File('$folder/Amal_${_reportType}_Report_$timestamp.pdf');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D5C3A),
            content: Text(widget.isBn
                ? 'PDF Download ফোল্ডারে সেভ হয়েছে!'
                : 'PDF saved to Download folder!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF সেভ করতে ব্যর্থ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'আমল ও জিকির সামারি' : 'Amal & Zikr Summary', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          tabs: [
            Tab(text: widget.isBn ? 'দৈনিক' : 'Daily'),
            Tab(text: widget.isBn ? 'সাপ্তাহিক' : 'Weekly'),
            Tab(text: widget.isBn ? 'মাসিক' : 'Monthly'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D5C3A)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDailyTab(isDark),
                _buildStatsTab(_weeklyStats, widget.isBn ? 'বিগত ৭ দিনের সার্বিক অগ্রগতি' : 'Past 7 Days Summary', isDark),
                _buildStatsTab(_monthlyStats, widget.isBn ? 'বিগত ৩০ দিনের সার্বিক অগ্রগতি' : 'Past 30 Days Summary', isDark),
              ],
            ),
    );
  }

  Widget _buildDailyTab(bool isDark) {
    int total = _dailyRecord?.totalAmols ?? 18;
    int done = _dailyRecord?.completedAmols ?? 0;
    int percent = total == 0 ? 0 : ((done / total) * 100).toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // তারিখ পরিবর্তন বাটন
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.isBn ? "তারিখ" : "Date"}: ${DateFormat('d MMMM yyyy').format(_selectedDate)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
              icon: const Icon(Icons.calendar_month, size: 16),
              label: Text(widget.isBn ? 'তারিখ বাছুন' : 'Pick Date'),
              onPressed: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadAllStats();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // রিপোজিটরি স্ক্রিনশট / ইমেজ কার্ড
        RepaintBoundary(
          key: _reportCardKey,
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? const Color(0xFF1E2621) : const Color(0xFFF9FCFA),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF0D5C3A), size: 24),
                      const SizedBox(width: 8),
                      Text(widget.isBn ? 'দৈনন্দিন আমল ও জিকির রিপোর্ট' : 'Amal & Zikr Report', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat('EEEE, d MMMM yyyy').format(_selectedDate), style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  const Divider(height: 20),

                  // আমলের অগ্রগতি
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricBox(widget.isBn ? 'মোট আমল' : 'Total', '$total', Colors.blue),
                      _metricBox(widget.isBn ? 'সম্পন্ন' : 'Done', '$done', Colors.green),
                      _metricBox(widget.isBn ? 'অগ্রগতি' : 'Rate', '$percent%', Colors.deepOrange),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // জিকিরের সারসংক্ষেপ
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(widget.isBn ? 'জিকিরের পরিসংখ্যান:' : 'Zikr Statistics:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  const SizedBox(height: 8),
                  if (_dailyRecord?.zikrCounts == null || _dailyRecord!.zikrCounts.isEmpty)
                    Text(widget.isBn ? 'এই তারিখে কোনো জিকিরের হিসাব নেই।' : 'No zikr record on this day.', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                  else
                    ..._dailyRecord!.zikrCounts.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key.split('—')[0].trim(), style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text('${e.value} বার', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ছবি ও PDF সেভ বাটন
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.image, size: 18),
                label: Text(widget.isBn ? 'ছবি সেভ করুন' : 'Save Image'),
                onPressed: _saveAsImage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D5C3A), padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(widget.isBn ? 'PDF সেভ করুন' : 'Save PDF'),
                onPressed: _saveAsPdf,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsTab(Map<String, dynamic> stats, String title, bool isDark) {
    int total = stats['totalAmols'] ?? 0;
    int done = stats['completedAmols'] ?? 0;
    int percent = stats['percent'] ?? 0;
    int totalZikr = stats['totalZikr'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RepaintBoundary(
          key: title.contains('৭ দিনের') || title.contains('7 Days')
              ? _weeklyCardKey
              : _monthlyCardKey,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0D5C3A),
                    ),
                  ),
                  const Divider(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    title: Text(widget.isBn
                        ? 'গড় আমল সম্পন্ন'
                        : 'Average Completed'),
                    trailing: Text(
                      '$done / $total ($percent%)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.touch_app_outlined,
                      color: Colors.teal,
                    ),
                    title: Text(widget.isBn
                        ? 'মোট পঠিত জিকির'
                        : 'Total Zikr Counts'),
                    trailing: Text(
                      '$totalZikr বার',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0D5C3A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D5C3A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.image, size: 18),
                label: Text(widget.isBn ? 'ছবি সেভ করুন' : 'Save Image'),
                onPressed: _saveAsImage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D5C3A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(widget.isBn ? 'PDF সেভ করুন' : 'Save PDF'),
                onPressed: _saveAsPdf,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
