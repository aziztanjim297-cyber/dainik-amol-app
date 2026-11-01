import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasbihScreen extends StatefulWidget {
  final bool isBn;
  const TasbihScreen({super.key, required this.isBn});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  int _counter = 0;
  String _selectedZikr = 'সুবহানাল্লাহ — سُبْحَانَ اللَّهِ';
  final Map<String, int> _todayCounts = {};

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
    _loadDailyZikr();
  }

  Future<void> _loadDailyZikr() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      _counter = prefs.getInt('${today}_$_selectedZikr') ?? 0;
      for (var z in zikrPresets) {
        _todayCounts[z] = prefs.getInt('${today}_$z') ?? 0;
      }
    });
  }

  Future<void> _increment() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      _counter++;
      _todayCounts[_selectedZikr] = (_todayCounts[_selectedZikr] ?? 0) + 1;
    });
    await prefs.setInt('${today}_$_selectedZikr', _counter);
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      _counter = 0;
      _todayCounts[_selectedZikr] = 0;
    });
    await prefs.setInt('${today}_$_selectedZikr', 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ডিজিটাল জিকির কাউন্টার', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ১২. বাংলা ও আরবি নাম একসাথে
            DropdownButton<String>(
              value: _selectedZikr,
              items: zikrPresets.map((z) => DropdownMenuItem(value: z, child: Text(z, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedZikr = val);
                  _loadDailyZikr();
                }
              },
            ),
            const SizedBox(height: 25),
            GestureDetector(
              onTap: _increment,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D5C3A),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, spreadRadius: 6)],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_counter', style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text('চাপুন', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, color: Colors.red),
              label: const Text('রিসেট', style: TextStyle(color: Colors.red, fontSize: 16)),
            ),
            const Divider(height: 30),
            const Text('আজকের মোট জিকির:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _todayCounts.entries.map((e) => Chip(label: Text('${e.key.split("—")[0].trim()}: ${e.value}'))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
