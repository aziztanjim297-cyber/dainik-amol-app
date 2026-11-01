import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasbihScreen extends StatefulWidget {
  final bool isBn;
  const TasbihScreen({super.key, required this.isBn});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  int _counter = 0;
  String _selectedZikr = 'সুবহানাল্লাহ';
  final Map<String, int> _zikrTotals = {};

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  Future<void> _loadTotals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = prefs.getInt('tasbih_current') ?? 0;
      _zikrTotals['সুবহানাল্লাহ'] = prefs.getInt('total_subhanallah') ?? 0;
      _zikrTotals['আলহামদুলিল্লাহ'] = prefs.getInt('total_alhamdulillah') ?? 0;
      _zikrTotals['আল্লাহু আকবার'] = prefs.getInt('total_allahuakbar') ?? 0;
      _zikrTotals['আস্তাগফিরুল্লাহ'] = prefs.getInt('total_astaghfirullah') ?? 0;
      _zikrTotals['দরুদ শরিফ'] = prefs.getInt('total_durood') ?? 0;
    });
  }

  Future<void> _increment() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter++;
      _zikrTotals[_selectedZikr] = (_zikrTotals[_selectedZikr] ?? 0) + 1;
    });
    await prefs.setInt('tasbih_current', _counter);
    if (_selectedZikr == 'সুবহানাল্লাহ') await prefs.setInt('total_subhanallah', _zikrTotals['সুবহানাল্লাহ']!);
    if (_selectedZikr == 'আলহামদুলিল্লাহ') await prefs.setInt('total_alhamdulillah', _zikrTotals['আলহামদুলিল্লাহ']!);
    if (_selectedZikr == 'আল্লাহু আকবার') await prefs.setInt('total_allahuakbar', _zikrTotals['আল্লাহু আকবার']!);
    if (_selectedZikr == 'আস্তাগফিরুল্লাহ') await prefs.setInt('total_astaghfirullah', _zikrTotals['আস্তাগফিরুল্লাহ']!);
    if (_selectedZikr == 'দরুদ শরিফ') await prefs.setInt('total_durood', _zikrTotals['দরুদ শরিফ']!);
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _counter = 0);
    await prefs.setInt('tasbih_current', 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'ডিজিটাল জিকির কাউন্টার' : 'Tasbih Counter', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButton<String>(
              value: _selectedZikr,
              items: ['সুবহানাল্লাহ', 'আলহামদুলিল্লাহ', 'আল্লাহু আকবার', 'আস্তাগফিরুল্লাহ', 'দরুদ শরিফ']
                  .map((z) => DropdownMenuItem(value: z, child: Text(z, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedZikr = val);
              },
            ),
            const SizedBox(height: 25),
            GestureDetector(
              onTap: _increment,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D5C3A),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.35), blurRadius: 25, spreadRadius: 6)],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_counter', style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(widget.isBn ? 'চাপ দিন' : 'Tap', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, color: Colors.red),
              label: Text(widget.isBn ? 'কাউন্টার রিসেট' : 'Reset', style: const TextStyle(color: Colors.red, fontSize: 16)),
            ),
            const Divider(height: 30),
            Text(widget.isBn ? 'সংরক্ষিত মোট জিকিরের হিসাব:' : 'Saved Total Counts:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _zikrTotals.entries.map((e) => Chip(label: Text('${e.key}: ${e.value}'))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
