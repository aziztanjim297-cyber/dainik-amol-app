import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final bool isBn;
  final ThemeMode themeMode;
  final int hijriAdj;
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onLanguageChanged;
  final Function(int) onHijriChanged;

  const SettingsScreen({
    super.key,
    required this.isBn,
    required this.themeMode,
    required this.hijriAdj,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onHijriChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isBn ? 'ব্যবহারকারীর সেটিংস' : 'Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF0D5C3A)),
            title: Text(isBn ? 'ভাষা নির্বাচন (Language)' : 'App Language'),
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
          ListTile(
            leading: const Icon(Icons.brightness_6, color: Color(0xFF0D5C3A)),
            title: Text(isBn ? 'থিম মোড' : 'Theme Mode'),
            subtitle: Text(themeMode == ThemeMode.system ? (isBn ? 'সিস্টেম ডিফল্ট' : 'System Default') : (themeMode == ThemeMode.dark ? 'ডার্ক মোড' : 'লাইট মোড')),
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
          ListTile(
            leading: const Icon(Icons.calendar_month, color: Color(0xFF0D5C3A)),
            title: Text(isBn ? 'হিজরি তারিখ সমন্বয় (±১ দিন)' : 'Hijri Adjustment'),
            subtitle: Text('${isBn ? "বর্তমান সমন্বয়: " : "Current offset: "}$hijriAdj ${isBn ? "দিন" : "days"}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.remove), onPressed: () => onHijriChanged(hijriAdj - 1)),
                IconButton(icon: const Icon(Icons.add), onPressed: () => onHijriChanged(hijriAdj + 1)),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.mosque, color: Color(0xFF0D5C3A)),
            title: Text(isBn ? 'নামাজের মাজহাব' : 'Asr Madhab Calculation'),
            subtitle: Text(isBn ? 'হানাফি মাজহাব (নির্ধারিত)' : 'Hanafi Madhab (Locked)'),
          ),
        ],
      ),
    );
  }
}
