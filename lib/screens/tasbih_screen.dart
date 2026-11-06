import 'dart:ui' show TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_service.dart';

class TasbihScreen extends StatefulWidget {
  final bool isBn;
  final String language;
  const TasbihScreen({
    super.key,
    required this.isBn,
    String? language,
  }) : language = language ?? (isBn ? 'bn' : 'en');

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  String _t(String bn, String en, String ar) =>
      widget.language == 'ar' ? ar : (widget.isBn ? bn : en);

  int _sessionCounter = 0;
  int _targetGoal = 33;
  String _selectedZikr = 'সুবহানাল্লাহ — سُبْحَانَ اللَّهِ';
  final Map<String, int> _todayTotals = {};
  String _todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _loading = true;
  bool _saving = false;

  final List<String> zikrPresets = [
    'সুবহানাল্লাহ — سُبْحَانَ اللَّهِ',
    'আলহামদুলিল্লাহ — الْحَمْدُ لِلَّهِ',
    'আল্লাহু আকবার — اللَّهُ أَكْبَرُ',
    'আস্তাগফিরুল্লাহ — أَسْتَغْفِرُ اللَّهَ',
    'দরুদ শরিফ — الصَّلَاةُ عَلَى النَّبِيِّ',
  ];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  String _sessionKey(String zikr) => 'session_counter_${_todayKey}_$zikr';

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _todayKey = today;
    _selectedZikr =
        prefs.getString('current_zikr_name') ?? zikrPresets.first;

    if (!zikrPresets.contains(_selectedZikr)) {
      _selectedZikr = zikrPresets.first;
    }

    _targetGoal = prefs.getInt('current_zikr_goal') ?? 33;

    for (final zikr in zikrPresets) {
      _todayTotals[zikr] =
          prefs.getInt('${_todayKey}_total_$zikr') ?? 0;
    }

    _sessionCounter = prefs.getInt(_sessionKey(_selectedZikr)) ??
        prefs.getInt('session_counter_$_selectedZikr') ??
        0;

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshIfNewDay() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (today == _todayKey) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _todayKey = today;
      _sessionCounter = 0;
      for (final zikr in zikrPresets) {
        _todayTotals[zikr] = 0;
      }
    });

    await prefs.setInt(_sessionKey(_selectedZikr), 0);
    await _loadState();
  }

  Future<void> _increment() async {
    if (_saving || _loading) return;
    _saving = true;

    try {
      await _refreshIfNewDay();
      HapticFeedback.lightImpact();

      final prefs = await SharedPreferences.getInstance();
      final newSession = _sessionCounter + 1;
      final newTotal = (_todayTotals[_selectedZikr] ?? 0) + 1;

      setState(() {
        _sessionCounter = newSession;
        _todayTotals[_selectedZikr] = newTotal;
      });

      await prefs.setInt(_sessionKey(_selectedZikr), newSession);
      await prefs.setInt(
        '${_todayKey}_total_$_selectedZikr',
        newTotal,
      );

      await HistoryService.saveZikrCounts(
        Map<String, int>.from(_todayTotals),
      );

      if (_targetGoal > 0 && newSession == _targetGoal) {
        HapticFeedback.vibrate();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0D5C3A),
              content: Text(
                _t(
                  'মাশাআল্লাহ! $_targetGoal বার পাঠ পূর্ণ হয়েছে।',
                  'Alhamdulillah! $_targetGoal counts completed.',
                  'ما شاء الله! اكتمل العدد $_targetGoal مرة.',
                ),
                textDirection: widget.language == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _resetSession() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() => _sessionCounter = 0);
    await prefs.setInt(_sessionKey(_selectedZikr), 0);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('বর্তমান রাউন্ড রিসেট হয়েছে। আজকের মোট হিসাব সুরক্ষিত আছে।',
            'Round reset. Today\'s total is preserved.',
            'تم تصفير الجولة الحالية، مع الحفاظ على إجمالي عدد اليوم.'),
            textDirection: widget.language == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _selectGoal(int goal) async {
    setState(() => _targetGoal = goal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_zikr_goal', goal);
  }

  void _showSetGoalDialog() {
    final controller = TextEditingController(
      text: _targetGoal > 0 ? '$_targetGoal' : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _t('লক্ষ্যমাত্রা নির্ধারণ করুন', 'Set Target Goal', 'تحديد الهدف'),
          textDirection: widget.language == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
        ),
        content: TextField(
          textDirection: widget.language == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: _t(
              'যেমন: ৩৩, ৩৪, ১০০ বা ৫০০',
              'e.g. 33, 34, 100 or 500',
              'مثال: ٣٣، ٣٤، ١٠٠ أو ٥٠٠',
            ),
            hintTextDirection: widget.language == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _selectGoal(0);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(_t('সীমাহীন', 'Unlimited', 'بلا حد')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D5C3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final goal = int.tryParse(controller.text);
              if (goal != null && goal > 0) {
                await _selectGoal(goal);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(_t('সেভ', 'Save', 'حفظ')),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _changeZikr(String? value) async {
    if (value == null) return;

    await _refreshIfNewDay();
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _selectedZikr = value;
      _sessionCounter = prefs.getInt(_sessionKey(value)) ??
          prefs.getInt('session_counter_$value') ??
          0;
    });

    await prefs.setString('current_zikr_name', value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalCompleted =
        _targetGoal > 0 && _sessionCounter >= _targetGoal;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('ডিজিটাল জিকির কাউন্টার', 'Tasbih Counter', 'عداد التسبيح الرقمي'),
          textDirection: widget.language == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark
            ? const Color(0xFF18221D)
            : const Color(0xFF0D5C3A),
        foregroundColor: isDark
            ? const Color(0xFF80D6A8)
            : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: isDark ? const Color(0xFF1E2923) : null,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedZikr,
                  items: zikrPresets
                      .map(
                        (z) => DropdownMenuItem(
                          value: z,
                          child: Text(
                            (widget.language == 'ar' ? z.split('—').last.trim() : z),
                            textDirection: widget.language == 'ar'
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _changeZikr,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _t('লক্ষ্যমাত্রা: ', 'Goal: ', 'الهدف: '),
                textDirection: widget.language == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ActionChip(
                label: Text('৩৩', style: TextStyle(
                  color: isDark ? Colors.white : null,
                )),
                backgroundColor:
                    _targetGoal == 33
                        ? (isDark ? const Color(0xFF28533C) : Colors.green.shade100)
                        : null,
                onPressed: () => _selectGoal(33),
              ),
              const SizedBox(width: 6),
              ActionChip(
                label: Text('৩৪', style: TextStyle(
                  color: isDark ? Colors.white : null,
                )),
                backgroundColor:
                    _targetGoal == 34
                        ? (isDark ? const Color(0xFF28533C) : Colors.green.shade100)
                        : null,
                onPressed: () => _selectGoal(34),
              ),
              const SizedBox(width: 6),
              ActionChip(
                label: Text('১০০', style: TextStyle(
                  color: isDark ? Colors.white : null,
                )),
                backgroundColor:
                    _targetGoal == 100
                        ? (isDark ? const Color(0xFF28533C) : Colors.green.shade100)
                        : null,
                onPressed: () => _selectGoal(100),
              ),
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.edit, size: 14),
                label: Text(
                  _targetGoal > 0
                      ? '$_targetGoal'
                      : _t('সীমাহীন', 'Free', 'بلا حد'),
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
                onPressed: _showSetGoalDialog,
              ),
            ],
          ),
          const SizedBox(height: 40),
          Center(
            child: GestureDetector(
              onTap: _increment,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goalCompleted
                      ? Colors.red
                      : (isDark
                          ? const Color(0xFF1B8E5B)
                          : const Color(0xFF0D5C3A)),
                  boxShadow: [
                    BoxShadow(
                      color: (goalCompleted ? Colors.red : Colors.green)
                          .withOpacity(0.35),
                      blurRadius: 25,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_sessionCounter',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _targetGoal > 0
                            ? '${_t("লক্ষ্য", "Goal", "الهدف")}: $_targetGoal'
                            : _t('চাপ দিন', 'Tap', 'اضغط'),
                        textDirection: widget.language == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: _resetSession,
              icon: const Icon(Icons.refresh, color: Colors.red),
              label: Text(
                _t('রিসেট', 'Reset', 'إعادة ضبط'),
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Divider(
            height: 30,
            color: isDark ? Colors.white24 : null,
          ),
          Text(
            _t('আজকের মোট জিকির (সংরক্ষিত হিসাব):',
                'Today\'s Total Zikr Counts:',
                'إجمالي أذكار اليوم (السجل المحفوظ):'),
            textDirection: widget.language == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...zikrPresets.map((z) {
            final totalToday = _todayTotals[z] ?? 0;
            return Card(
              color: isDark ? const Color(0xFF1E2923) : null,
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                title: Text(
                  (widget.language == 'ar' ? z.split('—').last.trim() : z),
                  textDirection: widget.language == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                trailing: Text(
                  '$totalToday ${_t("বার", "times", "مرة")}',
                  textDirection: widget.language == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF80D6A8) : const Color(0xFF0D5C3A),
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
