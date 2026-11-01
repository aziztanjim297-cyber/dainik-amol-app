import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_service.dart';

class TasbihScreen extends StatefulWidget {
  final bool isBn;
  const TasbihScreen({super.key, required this.isBn});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  int _sessionCounter = 0; // বর্তমান রাউন্ডের গণনা (যা রিসেট হবে)
  int _targetGoal = 33;    // লক্ষ্যমাত্রা (৩৩, ৩৪, ১০০)
  String _selectedZikr = 'সুবহানাল্লাহ — سُبْحَانَ اللَّهِ';
  final Map<String, int> _todayTotals = {}; // আজকের মোট স্থায়ী হিসাব
  final String _todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

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

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedZikr = prefs.getString('current_zikr_name') ?? zikrPresets[0];
      _targetGoal = prefs.getInt('current_zikr_goal') ?? 33;
      _sessionCounter = prefs.getInt('session_counter_$_selectedZikr') ?? 0;

      for (var z in zikrPresets) {
        _todayTotals[z] = prefs.getInt('${_todayKey}_total_$z') ?? 0;
      }
    });
  }

  Future<void> _increment() async {
    HapticFeedback.lightImpact(); // তাসবিহ দানার ক্লিক অনুভূতি
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _sessionCounter++;
      _todayTotals[_selectedZikr] = (_todayTotals[_selectedZikr] ?? 0) + 1;
    });

    await prefs.setInt('session_counter_$_selectedZikr', _sessionCounter);
    await prefs.setInt('${_todayKey}_total_$_selectedZikr', _todayTotals[_selectedZikr]!);

    // লক্ষ্য পূরণ হলে ভাইব্রেশন
    if (_targetGoal > 0 && _sessionCounter == _targetGoal) {
      HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D5C3A),
            content: Text(
              widget.isBn ? 'মাশাআল্লাহ! $_targetGoal বার পাঠ পূর্ণ হয়েছে।' : 'Alhamdulillah! $_targetGoal count completed.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // ৩ মাসের হিস্ট্রি ডাটাবেজে আজকের মোট সংখ্যা সিঙ্ক
    HistoryService.saveTodayRecord(
      totalAmols: 18,
      completedAmols: 0,
      zikrCounts: _todayTotals,
      amolStatus: {},
    );
  }

  // ফিক্স: রিসেট চাপলে শুধু বর্তমান রাউন্ড ০ হবে, আজকের মোট হিসাব অক্ষুণ্ণ থাকবে
  Future<void> _resetSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sessionCounter = 0;
    });
    await prefs.setInt('session_counter_$_selectedZikr', 0);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isBn ? 'বর্তমান রাউন্ড রিসেট হয়েছে। আজকের মোট হিসাব সুরক্ষিত আছে।' : 'Round reset. Today\'s total preserved.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showSetGoalDialog() {
    final controller = TextEditingController(text: _targetGoal > 0 ? '$_targetGoal' : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isBn ? 'লক্ষ্যমাত্রা নির্ধারণ করুন' : 'Set Target Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: widget.isBn ? 'যেমন: ৩৩, ৩৪, ১০০ বা ৫০০' : 'e.g. 33, 34, 100',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _targetGoal = 0);
              SharedPreferences.getInstance().then((p) => p.setInt('current_zikr_goal', 0));
              Navigator.pop(ctx);
            },
            child: Text(widget.isBn ? 'সীমাহীন' : 'Unlimited'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
            onPressed: () async {
              int? g = int.tryParse(controller.text);
              if (g != null && g > 0) {
                setState(() => _targetGoal = g);
                final p = await SharedPreferences.getInstance();
                await p.setInt('current_zikr_goal', g);
              }
              Navigator.pop(ctx);
            },
            child: Text(widget.isBn ? 'সেভ' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'ডিজিটাল জিকির কাউন্টার' : 'Tasbih Counter', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // জিকির নির্বাচন ড্রপডাউন
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedZikr,
                  items: zikrPresets.map((z) => DropdownMenuItem(
                    value: z,
                    child: Text(z, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  )).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      final p = await SharedPreferences.getInstance();
                      setState(() {
                        _selectedZikr = val;
                        _sessionCounter = p.getInt('session_counter_$val') ?? 0;
                      });
                      await p.setString('current_zikr_name', val);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // লক্ষ্যমাত্রা নির্বাচন বার
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.isBn ? 'লক্ষ্যমাত্রা: ' : 'Goal: ', style: const TextStyle(fontWeight: FontWeight.bold)),
              ActionChip(
                label: const Text('৩৩'),
                backgroundColor: _targetGoal == 33 ? Colors.green.shade100 : null,
                onPressed: () => setState(() => _targetGoal = 33),
              ),
              const SizedBox(width: 6),
              ActionChip(
                label: const Text('৩৪'),
                backgroundColor: _targetGoal == 34 ? Colors.green.shade100 : null,
                onPressed: () => setState(() => _targetGoal = 34),
              ),
              const SizedBox(width: 6),
              ActionChip(
                label: const Text('১০০'),
                backgroundColor: _targetGoal == 100 ? Colors.green.shade100 : null,
                onPressed: () => setState(() => _targetGoal = 100),
              ),
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.edit, size: 14),
                label: Text(_targetGoal > 0 ? '$_targetGoal' : (widget.isBn ? 'সীমাহীন' : 'Free')),
                onPressed: _showSetGoalDialog,
              ),
            ],
          ),
          const SizedBox(height: 25),

          // তাসবিহ দানার বড় বাটন (বর্তমান রাউন্ড গণনা)
          Center(
            child: GestureDetector(
              onTap: _increment,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1B8E5B) : const Color(0xFF0D5C3A),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.35),
                      blurRadius: 25,
                      spreadRadius: 8,
                    )
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_sessionCounter',
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _targetGoal > 0 ? '${widget.isBn ? "লক্ষ্য" : "Goal"}: $_targetGoal' : (widget.isBn ? 'চাপ দিন' : 'Tap'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // রাউন্ড রিসেট বাটন
          Center(
            child: TextButton.icon(
              onPressed: _resetSession,
              icon: const Icon(Icons.refresh, color: Colors.red),
              label: Text(widget.isBn ? 'রাউন্ড রিসেট (বৃত্ত ০ করুন)' : 'Reset Round', style: const TextStyle(color: Colors.red, fontSize: 15)),
            ),
          ),
          const Divider(height: 30),

          // আজকের মোট জিকিরের অপরিবর্তনীয় হিসাব
          Text(
            widget.isBn ? 'আজকের মোট জিকির (সংরক্ষিত হিসাব):' : 'Today\'s Total Zikr Counts:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ...zikrPresets.map((z) {
            int totalToday = _todayTotals[z] ?? 0;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                title: Text(z, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                trailing: Text('$totalToday বার', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A), fontSize: 14)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
