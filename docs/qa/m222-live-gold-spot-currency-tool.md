# M222 — Global gold spot widget inside the existing currency converter

## Scope and approved visual direction

Keep the currency converter above unchanged. In the **same scrollable Currency Converter screen**, introduce a full-width new card titled `أسعار الذهب العالمية` with actual metallic gold illustration, a real quote snapshot and source timestamp, five karat spot-estimates, bullion sizes and a gold weight calculator. Support the existing Arabic RTL/Tajawal and English modes and dark/light themes.

## Source and units

- Endpoint: `GET https://api.gold-api.com/price/XAU` (HTTPS, no API key), `Gold-API` official public XAU spot route.
- Explicitly require `symbol == XAU`, `currency == USD`, a finite positive `price` and time-zone-qualified `updatedAt`. Quote is **USD per troy ounce**, never USD per everyday 28.35 g ounce.
- Convert using exactly **31.1034768 grams per troy ounce**. All karat costs and bullion costs are derived from the same exact quote, with no fabricated fallback.
- Calculated 24K uses commercially typical 99.9% fineness; 22K = 22/24; 21K = 87.5%; 18K = 75%; 14K = 14/24. These are raw metal price estimates, not jewellery shop offers, bank prices or retail bullion ask.
- Bullion examples: 1 g, 5 g, 10 g, 20 g, 50 g, 100 g and 1 **troy** ounce of 24K gold. No manufacture premium, tax, shipping, bid/ask spread or local regulation is applied.
- User can choose any listed karat and enter a positive gram weight for a computed metal-value estimate.
- A live spot price response must contain the provider's UTC timestamp; show local date/time and warn if aged >72 hours. Reject invalid/future and excessively stale (>7-day) quotes. No asynchronous periodic polling, maximum one refresh per 30 seconds when a quote already exists.
- On HTTP errors, malformed responses or timeouts, show an **honest source-unavailable error**, never numbers from image mocks. A verified quote already on-screen can remain visible with an error label while retrying.

## Safety and release

- Read-only external data. No Waffra financial transactions, SQLCipher database, SMS, SMS permissions, Android widget, personal identity or credential are transmitted to the gold provider.
- No increase to SQLCipher production authority and **no SQLCipher auto activation**. User-account/financial encrypted cutover is still strictly NO-GO pending on-device principal enrollment, 24 real route certification, attachment byte parity, verified interruption recovery, encrypted device-to-device restore and physical Android evidence.
- A GitHub PR check is not a signed release. Full exact-head 16+ CI reviews, then safe main merge, then post-main full finance regression + signed APK verification and Android handset visual/haptic check must succeed before user installation can be claimed.

## Regression contract

13 Flutter tests verify official XAU/USD shape, troy ounces, price unit conversion, karat fineness and bullion estimates, reject old/future/malformed quotes, never send API keys, fail closed for HTTP/size errors, Arabic/English UI and absence of fake quotes. The release review gate checks the exact seven-file change scope and forbids cutover changes.
