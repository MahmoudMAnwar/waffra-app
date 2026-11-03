/// Central release policy. Disable capabilities without deleting Global-edition
/// source code or migrating any user's stored preferences/finance records.
/// Reactivation requires a separately reviewed Global release.
abstract final class WaffraSaudiRelease {
 static const bool enabled=true;
 static const bool locationCountryOnboarding=false;
 static const bool receiptImageTransactionImport=false;
 static const bool qwenForBankSms=false;
 static const bool qwenForAskWaffra=false;
 static const bool freeTextAskWaffra=false;
 static const bool userCountryChoice=false;
 static const bool userCurrencyChoice=false;
 static const bool globalCurrencyConverter=true;
 /// Only bank-SMS foreign-FX previews remain deferred; Tools FX works normally.
 static const bool bankSmsForeignCurrencyPreview=false;
 static const String countryIso='SA';
 static const String ledgerCurrency='SAR';
}