import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:country_picker/country_picker.dart';

class LocationSettingsScreen extends StatefulWidget {
  final bool isBn;
  final String language;
  final VoidCallback onLocationChanged;

  const LocationSettingsScreen({
    super.key,
    required this.isBn,
    String? language,
    required this.onLocationChanged,
  }) : language = language ?? (isBn ? 'bn' : 'en');

  @override
  State<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState
    extends State<LocationSettingsScreen> {
  static const _districtUrl =
      'https://raw.githubusercontent.com/open-admin-data/bangladesh-administrative-divisions/main/data/all-district.json';
  static const _upazilaUrl =
      'https://raw.githubusercontent.com/open-admin-data/bangladesh-administrative-divisions/main/data/all-upazila.json';

  List<dynamic> _districts = [];
  List<dynamic> _upazilas = [];
  String? _districtId, _upazilaId, _countryCode, _countryName;
  bool _loading = false;
  String _message = '';

  bool get isBn => widget.isBn;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    final p = await SharedPreferences.getInstance();
    _countryCode = p.getString('location_country_code');
    _countryName = p.getString('location_country_name');
    _districtId = p.getString('location_district_id');
    _upazilaId = p.getString('location_upazila_id');
    if (_countryCode == 'BD') await _loadAdministrativeData();
    if (mounted) setState(() {});
  }

  Future<void> _loadAdministrativeData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final r = await Future.wait([
        http.get(Uri.parse(_districtUrl)),
        http.get(Uri.parse(_upazilaUrl)),
      ]);
      if (r.any((e) => e.statusCode != 200)) {
        throw Exception();
      }
      _districts = jsonDecode(r[0].body);
      _upazilas = jsonDecode(r[1].body);
    } catch (_) {
      _message = _t(
          'তালিকা আনতে সমস্যা হয়েছে। ইন্টারনেট পরীক্ষা করুন。',
          'Could not load the lists. Check internet.',
          'تعذر تحميل القوائم. تحقق من اتصال الإنترنت.',
        );
    }
    if (mounted) setState(() => _loading = false);
  }

  String _localName(dynamic item) {
    final n = item['name'];
    if (n is Map) {
      return (isBn ? n['local'] ?? n['en'] : n['en'] ?? n['local'])
          .toString();
    }
    return '';
  }

  List<dynamic> get _filteredUpazilas => _upazilas.where((u) {
    return u['parent']?['id'] == _districtId;
  }).toList();

  Future<void> _saveLocation({
    required String mode,
    required String label,
    double? latitude,
    double? longitude,
    String? countryCode,
    String? countryName,
    String? districtId,
    String? upazilaId,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('location_mode', mode);
    await p.setString('location_label', label);

    if (latitude != null && longitude != null) {
      await p.setDouble('location_lat', latitude);
      await p.setDouble('location_lon', longitude);
    } else {
      await p.remove('location_lat');
      await p.remove('location_lon');
    }

    if (countryCode != null) {
      await p.setString('location_country_code', countryCode);
      await p.setString('location_country_name', countryName ?? '');
    }
    if (districtId != null) {
      await p.setString('location_district_id', districtId);
      await p.setString('location_upazila_id', upazilaId ?? '');
    }

    widget.onLocationChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('অবস্থান সংরক্ষিত হয়েছে', 'Location saved', 'تم حفظ الموقع'))),
    );
    Navigator.pop(context);
  }

  Future<void> _useGps() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(_t(
          'ফোনের Location/GPS চালু করুন।',
          'Turn on your phone\'s Location/GPS.',
          'يرجى تشغيل خدمة الموقع أو GPS في الهاتف.',
        ));
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(_t(
          'লোকেশন অনুমতি দেওয়া হয়নি।',
          'Location permission was denied.',
          'لم يتم السماح بإذن الوصول إلى الموقع.',
        ));
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(_t(
          'লোকেশন অনুমতি স্থায়ীভাবে বন্ধ। ফোনের App Settings থেকে অনুমতি দিন।',
          'Location permission is permanently denied. Allow it in your phone\'s app settings.',
          'تم إيقاف إذن الموقع نهائيًا. اسمح به من إعدادات التطبيق في هاتفك.',
        ));
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      await _saveLocation(
        mode: 'gps',
        label: 'GPS',
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = e.toString().replaceFirst('Exception: ', '');
          if (_message.contains('TimeoutException')) {
            _message = _t(
              '৩০ সেকেন্ডেও GPS অবস্থান পাওয়া যায়নি। আবার চেষ্টা করুন।',
              'GPS location was not found within 30 seconds. Please try again.',
              'لم يتم العثور على موقع GPS خلال ٣٠ ثانية. حاول مرة أخرى.',
            );
          }
        });
      }
    }
  }

  Future<void> _selectCountry() async {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (country) async {
        setState(() {
          _countryCode = country.countryCode;
          _countryName = country.name;
          _districtId = null;
          _upazilaId = null;
        });
        if (country.countryCode == 'BD') {
          await _loadAdministrativeData();
        } else {
          await _saveLocation(
            mode: 'country',
            label: country.name,
            countryCode: country.countryCode,
            countryName: country.name,
          );
        }
      },
    );
  }

  Future<void> _saveBangladeshLocation() async {
    if (_districtId == null || _upazilaId == null) {
      setState(() => _message = _t('জেলা ও উপজেলা নির্বাচন করুন।', 'Select a district and upazila.', 'يرجى اختيار المنطقة والناحية.'));
      return;
    }

    final u = _upazilas.firstWhere((x) => x['id'] == _upazilaId);
    final d = _districts.firstWhere((x) => x['id'] == _districtId);
    final geo = u['geo'];

    if (geo is! Map ||
        double.tryParse('${geo['lat']}') == null ||
        double.tryParse('${geo['lon']}') == null) {
      setState(() => _message = _t('অবস্থানের তথ্য পাওয়া যায়নি.', 'Location information could not be found.', 'تعذر العثور على معلومات الموقع.'));
      return;
    }

    await _saveLocation(
      mode: 'bangladesh',
      label: '${_localName(d)}, ${_localName(u)}',
      latitude: double.parse('${geo['lat']}'),
      longitude: double.parse('${geo['lon']}'),
      countryCode: 'BD',
      countryName: 'Bangladesh',
      districtId: _districtId,
      upazilaId: _upazilaId,
    );
  }

  String _t(String bn, String en, String ar) =>
      widget.language == 'ar' ? ar : (widget.isBn ? bn : en);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(
        title: Text(_t('নামাজের সময়ের অবস্থান', 'Prayer Location', 'موقع الصلاة')),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.gps_fixed),
            title: Text(_t('বর্তমান অবস্থান (GPS)', 'Current GPS location', 'الموقع الحالي (GPS)')),
            subtitle: Text(_t(
              'আপনার প্রকৃত অবস্থান ব্যবহার করুন',
              'Use your actual location',
              'استخدم موقعك الفعلي',
            )),
            onTap: _loading ? null : _useGps,
          ),
          const Divider(),
          OutlinedButton.icon(
            onPressed: _selectCountry,
            icon: const Icon(Icons.public),
            label: Text(_countryName ??
                _t('দেশ নির্বাচন করুন', 'Select country', 'اختر الدولة')),
          ),
          if (_countryCode == 'BD') ...[
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_districts.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _districts.any((d) => d['id'] == _districtId)
                    ? _districtId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('জেলা নির্বাচন করুন', 'Select district', 'اختر المنطقة'),
                  border: const OutlineInputBorder(),
                ),
                items: _districts.map((d) {
                  return DropdownMenuItem<String>(
                    value: d['id'].toString(),
                    child: Text(_localName(d)),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _districtId = v;
                  _upazilaId = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _filteredUpazilas.any((u) => u['id'] == _upazilaId)
                    ? _upazilaId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('উপজেলা নির্বাচন করুন', 'Select upazila', 'اختر الناحية'),
                  border: const OutlineInputBorder(),
                ),
                items: _filteredUpazilas.map((u) {
                  return DropdownMenuItem<String>(
                    value: u['id'].toString(),
                    child: Text(_localName(u)),
                  );
                }).toList(),
                onChanged: _districtId == null
                    ? null
                    : (v) => setState(() => _upazilaId = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saveBangladeshLocation,
                child: Text(_t('অবস্থান সংরক্ষণ করুন', 'Save location', 'حفظ الموقع')),
              ),
            ],
          ],
          if (_countryCode != null && _countryCode != 'BD')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_t(
                'শুধু দেশের নাম দিয়ে নির্ভুল নামাজের সময় নির্ণয় সম্ভব নয়। GPS ব্যবহার করুন।',
                'A country name alone cannot determine accurate prayer times. Use GPS.',
                'لا يمكن تحديد أوقات الصلاة بدقة باسم الدولة فقط. استخدم GPS.',
              )),
            ),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message, style: const TextStyle(color: Colors.red)),
            ),
          if (_message.isNotEmpty && !_loading && _countryCode == 'BD')
            TextButton(
              onPressed: _loadAdministrativeData,
              child: Text(_t('আবার চেষ্টা করুন', 'Try again', 'حاول مرة أخرى')),
            ),
          const SizedBox(height: 16),
          Text(
            _t('জেলা ও উপজেলা তথ্য: Open Admin Data (CC BY 4.0)', 'District and upazila data: Open Admin Data (CC BY 4.0)', 'بيانات المناطق والنواحي: Open Admin Data (CC BY 4.0)'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      ),
    );
  }
}
