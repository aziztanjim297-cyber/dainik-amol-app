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
        title: Text(isBn ? 'সেটিংস ও পরিচিতি' : 'Settings & About', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ১. ভাষা নির্বাচন (Language Toggle)
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF0D5C3A)),
            title: Text(isBn ? 'অ্যাপের ভাষা (Language)' : 'App Language'),
            subtitle: Text(isBn ? 'বর্তমান: বাংলা' : 'Current: English'),
            trailing: DropdownButton<String>(
              value: isBn ? 'bn' : 'en',
              items: const [
                DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (val) {
                if (val != null) onLanguageChanged(val);
              },
            ),
          ),
          const Divider(),

          // ২. নামাজের মাজহাব নির্বাচন
          ListTile(
            leading: const Icon(Icons.mosque, color: Color(0xFF0D5C3A)),
            title: Text(isBn ? 'নামাজের মাজহাব (আসরের সময়)' : 'Prayer Madhab (Asr)'),
            subtitle: Text(madhab == 'hanafi' ? (isBn ? 'হানাফি মাজহাব' : 'Hanafi') : (isBn ? 'শাফেয়ী / অন্যান্য' : 'Shafi / Others')),
            trailing: DropdownButton<String>(
              value: madhab,
              items: [
                DropdownMenuItem(value: 'hanafi', child: Text(isBn ? 'হানাফি' : 'Hanafi')),
                DropdownMenuItem(value: 'shafi', child: Text(isBn ? 'শাফেয়ী' : 'Shafi')),
              ],
              onChanged: (val) {
                if (val != null) onMadhabChanged(val);
              },
            ),
          ),
          const Divider(),

          // ৩. থিম নির্বাচন
          ListTile(
            leading: const Icon(Icons.brightness_6, color: Color(0xFF0D5C3A)),
            title: Text(isBn ? 'থিম নির্বাচন' : 'Theme Mode'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(isBn ? 'সিস্টেম' : 'System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text(isBn ? 'লাইট' : 'Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(isBn ? 'ডার্ক' : 'Dark')),
              ],
              onChanged: (val) {
                if (val != null) onThemeChanged(val);
              },
            ),
          ),
          const Divider(),

          // ৪. অ্যাপ পরিচিতি (About App)
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF0D5C3A)),
            title: Text(isBn ? 'অ্যাপ পরিচিতি (About App)' : 'About App'),
            subtitle: const Text('দৈনন্দিন আমল v1.1.1'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'দৈনন্দিন আমল',
                applicationVersion: '1.1.1',
                applicationIcon: const Icon(Icons.menu_book, color: Color(0xFF0D5C3A), size: 40),
                children: [
                  Text(isBn
                      ? 'উদ্দেশ্য: একজন মুসলিমের পাঁচ ওয়াক্ত নামাজ কেন্দ্রিক ব্যক্তিগত আমল পরিচালনা ও সংরক্ষণের নির্ভরযোগ্য সহযোগী।'
                      : 'Purpose: A dedicated companion for managing and preserving a Muslim\'s daily prayers and righteous deeds.'),
                  const SizedBox(height: 8),
                  Text(isBn
                      ? 'বৈশিষ্ট্য: হানাফি ও শাফেয়ী ওয়াক্ত, সময়ভিত্তিক আমল লক, কুরআন ও হাদিস রিডার এবং ডিজিটাল তাসবিহ।'
                      : 'Features: Accurate prayer times, time-locked amals, Quran & Hadith readers, and digital tasbih.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
