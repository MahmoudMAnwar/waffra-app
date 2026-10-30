/// Country dialing-code selection for Google profiles. Independent of GPS,
/// financial currency, display preference and source bank SMS currency.
class WaffraPhoneCountry {
  const WaffraPhoneCountry(this.iso, this.flag, this.dial, this.ar, this.en);
  final String iso, flag, dial, ar, en;
  String label(bool english) => english ? en : ar;
}
const waffraPhoneCountries = <WaffraPhoneCountry>[
  WaffraPhoneCountry('SA','🇸🇦','+966','السعودية','Saudi Arabia'),
  WaffraPhoneCountry('EG','🇪🇬','+20','مصر','Egypt'),
  WaffraPhoneCountry('AE','🇦🇪','+971','الإمارات','UAE'),
  WaffraPhoneCountry('KW','🇰🇼','+965','الكويت','Kuwait'),
  WaffraPhoneCountry('BH','🇧🇭','+973','البحرين','Bahrain'),
  WaffraPhoneCountry('QA','🇶🇦','+974','قطر','Qatar'),
  WaffraPhoneCountry('OM','🇴🇲','+968','عمان','Oman'),
  WaffraPhoneCountry('JO','🇯🇴','+962','الأردن','Jordan'),
  WaffraPhoneCountry('IQ','🇮🇶','+964','العراق','Iraq'),
  WaffraPhoneCountry('LB','🇱🇧','+961','لبنان','Lebanon'),
  WaffraPhoneCountry('MA','🇲🇦','+212','المغرب','Morocco'),
  WaffraPhoneCountry('DZ','🇩🇿','+213','الجزائر','Algeria'),
  WaffraPhoneCountry('TN','🇹🇳','+216','تونس','Tunisia'),
  WaffraPhoneCountry('US','🇺🇸','+1','الولايات المتحدة','United States'),
  WaffraPhoneCountry('CA','🇨🇦','+1','كندا','Canada'),
  WaffraPhoneCountry('GB','🇬🇧','+44','المملكة المتحدة','United Kingdom'),
  WaffraPhoneCountry('FR','🇫🇷','+33','فرنسا','France'),
  WaffraPhoneCountry('DE','🇩🇪','+49','ألمانيا','Germany'),
  WaffraPhoneCountry('IT','🇮🇹','+39','إيطاليا','Italy'),
  WaffraPhoneCountry('ES','🇪🇸','+34','إسبانيا','Spain'),
  WaffraPhoneCountry('NL','🇳🇱','+31','هولندا','Netherlands'),
  WaffraPhoneCountry('TR','🇹🇷','+90','تركيا','Türkiye'),
  WaffraPhoneCountry('IN','🇮🇳','+91','الهند','India'),
  WaffraPhoneCountry('PK','🇵🇰','+92','باكستان','Pakistan'),
  WaffraPhoneCountry('BD','🇧🇩','+880','بنغلاديش','Bangladesh'),
  WaffraPhoneCountry('JP','🇯🇵','+81','اليابان','Japan'),
  WaffraPhoneCountry('CN','🇨🇳','+86','الصين','China'),
  WaffraPhoneCountry('AU','🇦🇺','+61','أستراليا','Australia'),
  WaffraPhoneCountry('CH','🇨🇭','+41','سويسرا','Switzerland'),
  WaffraPhoneCountry('SE','🇸🇪','+46','السويد','Sweden'),
  WaffraPhoneCountry('NO','🇳🇴','+47','النرويج','Norway'),
  WaffraPhoneCountry('DK','🇩🇰','+45','الدنمارك','Denmark'),
  WaffraPhoneCountry('ZA','🇿🇦','+27','جنوب أفريقيا','South Africa'),
  WaffraPhoneCountry('SG','🇸🇬','+65','سنغافورة','Singapore'),
  WaffraPhoneCountry('HK','🇭🇰','+852','هونغ كونغ','Hong Kong'),
  WaffraPhoneCountry('MY','🇲🇾','+60','ماليزيا','Malaysia'),
  WaffraPhoneCountry('ID','🇮🇩','+62','إندونيسيا','Indonesia'),
  WaffraPhoneCountry('KR','🇰🇷','+82','كوريا الجنوبية','South Korea'),
  WaffraPhoneCountry('TH','🇹🇭','+66','تايلاند','Thailand'),
  WaffraPhoneCountry('PH','🇵🇭','+63','الفلبين','Philippines'),
];

class WaffraPhoneSelection {
  const WaffraPhoneSelection({required this.country, required this.local});
  final WaffraPhoneCountry country;
  final String local;
}

abstract final class WaffraInternationalPhone {
  // Match Arabic spellings with/without hamza, diacritics, tatweel and
  // common ya/ta marbuta variants. This is ONLY search normalization:
  // it never modifies the selected phone code or app display currency.
  static String _searchable(String value) => value.toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool matchesQuery(WaffraPhoneCountry country, String query) {
    final key = _searchable(query);
    if (key.isEmpty) return true;
    return _searchable(country.ar).contains(key) ||
        _searchable(country.en).contains(key) ||
        country.dial.contains(key) ||
        country.iso.toLowerCase().contains(key);
  }

  static WaffraPhoneCountry byIso(String iso) =>
      waffraPhoneCountries.firstWhere((c) => c.iso == iso,
        orElse: () => waffraPhoneCountries.first);

  static WaffraPhoneSelection fromStored(String? stored) {
    final value = (stored ?? '').replaceAll(RegExp(r'[\s()\-]'), '');
    if (value.startsWith('+')) {
      final sorted = [...waffraPhoneCountries]
          ..sort((a,b) => b.dial.length.compareTo(a.dial.length));
      for (final country in sorted) {
        if (value.startsWith(country.dial)) {
          return WaffraPhoneSelection(country: country,
            local: value.substring(country.dial.length));
        }
      }
    }
    return WaffraPhoneSelection(country: byIso('SA'), local: value);
  }

  static String? e164(WaffraPhoneCountry country, String local) {
    var digits = local.trim().replaceAll(RegExp(r'[\s()\-]'), '');
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return null;
    // This field accepts a NATIONAL number, not 00 international prefix.
    // Remove the domestic trunk 0 only for countries where it is not part
    // of the E.164 subscriber number (e.g. +962 79..., not +962 079...).
    // Italy is intentionally excluded: fixed-line 0 remains significant.
    if (digits.startsWith('00')) return null;
    const nationalTrunkZero = <String>{
      'SA','EG','AE','JO','LB','MA','DZ','TN','GB','FR','DE','ES',
      'NL','TR','IN','PK','BD','JP','CN','AU','CH','SE','NO',
      'DK','ZA','MY','ID','KR','TH',
    };
    if (nationalTrunkZero.contains(country.iso) && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (country.iso == 'SA' && !RegExp(r'^5[0-9]{8}$').hasMatch(digits)) {
      return null;
    }
    if (country.iso == 'EG' && !RegExp(r'^1[0-9]{9}$').hasMatch(digits)) {
      return null;
    }
    if (country.iso != 'SA' && country.iso != 'EG' &&
        (digits.length < 7 || digits.length > 14)) return null;
    final full = country.dial + digits;
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(full) ? full : null;
  }

  static String? error(WaffraPhoneCountry country, String local,
      {required bool english}) {
    if (local.trim().isEmpty) {
      return english ? 'This field is required' : 'هذا الحقل مطلوب';
    }
    if (e164(country, local) != null) return null;
    return english
        ? 'Enter a valid number for '+country.en+' ('+country.dial+').'
        : 'أدخل رقمًا صحيحًا لدولة '+country.ar+' ('+country.dial+').';
  }
}
