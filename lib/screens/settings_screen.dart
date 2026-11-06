import 'package:flutter/material.dart';
import 'alarm_screen.dart';
import 'summary_screen.dart';
import 'location_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool isBn;
  final String language;
  final ThemeMode themeMode;
  final String madhab;
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onLanguageChanged;
  final Function(String) onMadhabChanged;
  final VoidCallback onLocationChanged;

  const SettingsScreen({
    super.key,
    required this.isBn,
    required this.language,
    required this.themeMode,
    required this.madhab,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onMadhabChanged,
    required this.onLocationChanged,
  });

  String _t(String bn, String en, String ar) =>
      language == 'ar' ? ar : (isBn ? bn : en);

  TextDirection get _textDirection =>
      language == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('সেটিংস ও পরিচিতি', 'Settings & About', 'الإعدادات وحول التطبيق'), textDirection: _textDirection, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ১. আমল ও জিকির সামারি রিপোর্ট (ছবি ও PDF)
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Color(0xFF0D5C3A)),
            title: Text(_t('আমল ও জিকির সামারি রিপোর্ট', 'Amal & Zikr Summary', 'ملخص الأعمال والأذكار'), textDirection: _textDirection),
            subtitle: Text(_t('দৈনিক, সাপ্তাহিক ও মাসিক রিপোর্ট (ছবি ও PDF সেভ)', 'Daily, weekly & monthly reports (Save Image/PDF)', 'التقارير اليومية والأسبوعية والشهرية (حفظ صورة أو PDF)'), textDirection: _textDirection),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(isBn: isBn, language: language))),
          ),
          const Divider(),

          // ২. অ্যালার্ম ও নোটিফিকেশন সেটিংস
          ListTile(
            leading: const Icon(Icons.alarm, color: Color(0xFF0D5C3A)),
            title: Text(_t('অ্যালার্ম ও নোটিফিকেশন নিয়ন্ত্রণ', 'Alarms & Notifications', 'التحكم في المنبهات والإشعارات'), textDirection: _textDirection),
            subtitle: Text(_t('৫ ওয়াক্ত নামাজ, তাহাজ্জুদ ও আমলের অ্যালার্ম', 'Manage prayer adhan & reminders', 'منبهات الصلوات الخمس والتهجد والأعمال'), textDirection: _textDirection),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmScreen(isBn: isBn, language: language))),
          ),
          const Divider(),

          // নামাজের সময়ের জন্য অবস্থান নির্বাচন
          ListTile(
            leading: const Icon(Icons.location_on, color: Color(0xFF0D5C3A)),
            title: Text(_t('নামাজের সময়ের অবস্থান', 'Prayer Time Location', 'موقع مواقيت الصلاة'), textDirection: _textDirection),
            subtitle: Text(_t('জিপিএস অথবা দেশ, জেলা ও উপজেলা নির্বাচন', 'Choose GPS or country, district and upazila', 'اختر الموقع عبر GPS أو الدولة والمنطقة والناحية'), textDirection: _textDirection),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LocationSettingsScreen(
                  isBn: isBn,
                  language: language,
                  onLocationChanged: onLocationChanged,
                ),
              ),
            ),
          ),
          const Divider(),

          // ৩. ভাষা নির্বাচন
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF0D5C3A)),
            title: Text(_t('অ্যাপের ভাষা', 'App Language', 'لغة التطبيق'), textDirection: _textDirection),
            subtitle: Text(_t('বর্তমান: বাংলা', 'Current: English', 'اللغة الحالية: العربية'), textDirection: _textDirection),
            trailing: DropdownButton<String>(
              value: language,
              items: const [
                DropdownMenuItem(value: 'bn', child: Text(_t('বাংলা', 'Bengali', 'البنغالية'))),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ar', child: Directionality(textDirection: TextDirection.rtl, child: Text('العربية'))),
              ],
              onChanged: (val) {
                if (val != null) onLanguageChanged(val);
              },
            ),
          ),
          const Divider(),

          // ৪. নামাজের মাজহাব নির্বাচন
          ListTile(
            leading: const Icon(Icons.mosque, color: Color(0xFF0D5C3A)),
            title: Text(_t('নামাজের মাজহাব (আসরের সময়)', 'Prayer Madhab (Asr)', 'المذهب الفقهي (وقت العصر)'), textDirection: _textDirection),
            subtitle: Text(madhab == 'hanafi' ? _t('হানাফি মাজহাব', 'Hanafi', 'المذهب الحنفي') : _t('শাফেয়ী / অন্যান্য', 'Shafi / Others', 'المذهب الشافعي / غيره'), textDirection: _textDirection),
            trailing: DropdownButton<String>(
              value: madhab,
              items: [
                DropdownMenuItem(value: 'hanafi', child: Text(_t('হানাফি', 'Hanafi', 'حنفي'), textDirection: _textDirection)),
                DropdownMenuItem(value: 'shafi', child: Text(_t('শাফেয়ী', 'Shafi', 'شافعي'), textDirection: _textDirection)),
              ],
              onChanged: (val) {
                if (val != null) onMadhabChanged(val);
              },
            ),
          ),
          const Divider(),

          // ৫. থিম নির্বাচন
          ListTile(
            leading: const Icon(Icons.brightness_6, color: Color(0xFF0D5C3A)),
            title: Text(_t('থিম নির্বাচন', 'Theme Mode', 'اختيار المظهر'), textDirection: _textDirection),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(_t('সিস্টেম', 'System', 'حسب النظام'), textDirection: _textDirection)),
                DropdownMenuItem(value: ThemeMode.light, child: Text(_t('লাইট', 'Light', 'فاتح'), textDirection: _textDirection)),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(_t('ডার্ক', 'Dark', 'داكن'), textDirection: _textDirection)),
              ],
              onChanged: (val) {
                if (val != null) onThemeChanged(val);
              },
            ),
          ),
          const Divider(),

          // ৬. অ্যাপ পরিচিতি
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF0D5C3A)),
            title: Text(_t('অ্যাপ পরিচিতি', 'About App', 'حول التطبيق'), textDirection: _textDirection),
            subtitle: Text(_t('দৈনন্দিন আমল v1.2.0', 'Dainik Amal v1.2.0', 'الأعمال اليومية v1.2.0'), textDirection: _textDirection),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: _t('দৈনন্দিন আমল', 'Dainik Amal', 'الأعمال اليومية'),
                applicationVersion: '1.2.0',
                applicationIcon: const Icon(Icons.menu_book, color: Color(0xFF0D5C3A), size: 40),
                children: [
                  Text(_t(
                    'উদ্দেশ্য: একজন মুসলিমের পাঁচ ওয়াক্ত নামাজ কেন্দ্রিক ব্যক্তিগত আমল পরিচালনা ও সংরক্ষণের নির্ভরযোগ্য সহযোগী।',
                    'Purpose: A dedicated companion for managing and preserving a Muslim\'s daily prayers and righteous deeds.',
                    'الهدف: رفيق موثوق لإدارة العبادات الشخصية وحفظها، المرتبطة بالصلوات الخمس اليومية للمسلم.',
                  ), textDirection: _textDirection),
                  const SizedBox(height: 8),
                  Text(_t('বৈশিষ্ট্য: হানাফি ওয়াক্ত, ৩ মাসের আমল হিস্ট্রি, ছবি ও PDF রিপোর্ট সেভ, কুরআন ও হাদিস রিডার এবং জিকির কাউন্টার।', 'Features: Accurate prayer times, 3-month history, Image/PDF reports, Quran & Hadith readers, and tasbih counter.', 'الميزات: مواقيت الصلاة وفق المذهب الحنفي، سجل العبادات لمدة ثلاثة أشهر، حفظ التقارير كصور وملفات PDF، قارئ القرآن والحديث، وعداد الأذكار.'), textDirection: _textDirection),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
