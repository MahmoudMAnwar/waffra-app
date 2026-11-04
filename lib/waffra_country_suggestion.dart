import 'dart:io';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Location is requested *only* after the user taps the onboarding action.
/// Approximate, foreground-only position is reverse geocoded to ISO-3166.
/// Latitude/longitude, address and GPS history are not persisted by Waffra.
abstract final class WaffraCountrySuggestion {
  static const Map<String, String> byIsoCountry = <String, String>{
    'SA': 'SAR', 'EG': 'EGP', 'AE': 'AED',
    'KW': 'KWD', 'BH': 'BHD', 'QA': 'QAR', 'OM': 'OMR',
    'JO': 'JOD', 'IQ': 'IQD', 'LB': 'LBP',
    'MA': 'MAD', 'DZ': 'DZD', 'TN': 'TND',
    'US': 'USD', 'GB': 'GBP', 'TR': 'TRY',
    'IN': 'INR', 'PK': 'PKR', 'BD': 'BDT',
    'JP': 'JPY', 'CN': 'CNY', 'CA': 'CAD',
    'AU': 'AUD', 'CH': 'CHF', 'SE': 'SEK',
    'NO': 'NOK', 'DK': 'DKK', 'ZA': 'ZAR',
    'SG': 'SGD', 'HK': 'HKD', 'MY': 'MYR',
    'ID': 'IDR', 'KR': 'KRW', 'TH': 'THB', 'PH': 'PHP',
    'FR': 'EUR', 'DE': 'EUR', 'IT': 'EUR',
    'ES': 'EUR', 'NL': 'EUR', 'PT': 'EUR',
    'BE': 'EUR', 'AT': 'EUR', 'FI': 'EUR',
    'IE': 'EUR', 'GR': 'EUR',
  };

  static String? currencyForIsoCountry(String? raw) =>
      byIsoCountry[raw?.trim().toUpperCase() ?? ''];

  static Future<String?> detectCountry() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      // This may use the mobile OS geocoding provider. No custom upload, no
      // cloud profile field and no coordinate storage are performed here.
      final places = await placemarkFromCoordinates(
        position.latitude, position.longitude);
      if (places.isEmpty) return null;
      final code = places.first.isoCountryCode?.toUpperCase();
      return code != null && RegExp(r'^[A-Z]{2}$').hasMatch(code)
          ? code : null;
    } catch (_) {
      // Denial, disabled GPS, geocoder outage and OS timeout are handled by
      // an explicit, completely functional manual-currency fallback.
      return null;
    }
  }
}
