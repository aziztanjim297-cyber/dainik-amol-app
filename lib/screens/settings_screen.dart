import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final bool isBn;
  final ThemeMode themeMode;
  final String madhab;
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onLanguageChanged;
  final Function(String) onMadhabChanged;

  const SettingsScreen({
    super.key,
    required this.isBn,
    required this.themeMode,
    required this.madhab,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onMadhabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সেটিংস ও পরিচিতি', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ৩ & ১৫. মাজহাব নির্বাচন
          ListTile(
            leading: const Icon(Icons.mosque, color: Color(0xFF0D5C3A)),
            title: const Text('নামাজের মাজহাব (আসরের ওয়াক্ত গণনা)'),
            subtitle: Text(madhab == 'hanafi' ? 'হানাফি মাজহাব (বর্তমানে সক্রিয়)' : 'শাফেয়ী / অন্যান্য'),
            trailing: DropdownButton<String>(
              value: madhab,
              items: const [
                DropdownMenuItem(value: 'hanafi', child: Text('হানাফি')),
                DropdownMenuItem(value: 'shafi', child: Text('শাফেয়ী / অন্যান্য')),
              ],
              onChanged: (val) {
                if (val != null) onMadhabChanged(val);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6, color: Color(0xFF0D5C3A)),
            title: const Text('থিম নির্বাচন'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('সিস্টেম')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('লাইট')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('ডার্ক')),
              ],
              onChanged: (val) {
                if (val != null) onThemeChanged(val);
              },
            ),
          ),
          const Divider(),
          // ১৩. About App / অ্যাপ পরিচিতি
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF0D5C3A)),
            title: const Text('অ্যাপ পরিচিতি (About App)'),
            subtitle: const Text('দৈনন্দিন আমল v1.1.0 • গোপনীয়তা ও তথ্য'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'দৈনন্দিন আমল',
                applicationVersion: '1.1.0+2',
                applicationIcon: const Icon(Icons.menu_book, color: Color(0xFF0D5C3A), size: 40),
                children: const [
                  Text('উদ্দেশ্য: একজন মুসলিমের পাঁচ ওয়াক্ত নামাজ কেন্দ্রিক ব্যক্তিগত আমল পরিচালনা ও সংরক্ষণের নির্ভরযোগ্য সহযোগী।'),
                  SizedBox(height: 8),
                  Text('ডেভেলপমেন্ট: সম্পূর্ণ অফলাইন ডাটাবেজ সমর্থিত এবং গোপনীয়তা সম্পূর্ণ সুরক্ষিত।'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
