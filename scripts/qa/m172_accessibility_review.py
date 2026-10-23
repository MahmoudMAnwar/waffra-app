#!/usr/bin/env python3
"""M172 readonly RTL/dark/contrast/performance acceptance snapshot.
Does not claim all controls are screen-reader or large-text compliant."""
from pathlib import Path
import json

def linear(rgb):
    x = rgb / 255.0
    return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4

def luminance(hex_color):
    raw = hex_color.removeprefix("#")
    r, g, b = (int(raw[i:i+2], 16) for i in (0,2,4))
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)

def contrast(a, b):
    light, dark = sorted((luminance(a), luminance(b)), reverse=True)
    return (light + .05) / (dark + .05)

def inspect(root: Path):
    source = (root / "lib/main.dart").read_text(encoding="utf-8")
    i18n = (root / "lib/waffra_i18n.dart").read_text(encoding="utf-8")
    ratios = {
        "dark_primary_on_surface": round(contrast("#FFFFFF", "#191D1B"), 2),
        "light_primary_on_scaffold": round(contrast("#183B33", "#F4FAF7"), 2),
        "dark_primary_on_scaffold": round(contrast("#FFFFFF", "#080A09"), 2),
    }
    checks = {
        "supported_ar_and_en": "supportedLocales:const [Locale('ar','SA'),Locale('en','US')]" in source,
        "rtl_and_ltr_directionality": "textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr" in source,
        "theme_system_light_dark": "appearance=='system'?ThemeMode.system" in source,
        "black_dark_scaffold": "scaffoldBackgroundColor:const Color(0xFF080A09)" in source,
        "consistent_tajawal": "fontFamily:'Tajawal'" in source and "fontFamily:'Tajawal'" in i18n,
        "system_reduce_motion_honored": "accessibilityFeatures.disableAnimations" in source,
        "user_animation_off_supported": "'off'=>0.0" in source,
        "contrast_for_primary_text_at_least_4_5": all(x >= 4.5 for x in ratios.values()),
    }
    issues = []
    if "minimumSize:const Size(36,36)" in source:
        issues.append("theme_icon_buttons_allow_36dp_visual_size_check_48dp_hit_target_on_device")
    issues += [
        "talkback_semantics_and_keyboard_navigation_unverified",
        "large_text_overflow_200_percent_on_full_screens_unverified",
        "profile_goal_recurring_pdf_dark_theme_phone_qa_unverified",
        "animation_performance_and_60fps_real_phone_tracing_unverified",
    ]
    return {
        "milestone": "M172",
        "auditOnly": True,
        "sourceConsistencyPassed": all(checks.values()),
        "checks": checks,
        "contrastRatios": ratios,
        "physicalAccessibilityValidated": False,
        "knownReviewItems": issues,
    }

if __name__ == "__main__":
    result = inspect(Path(__file__).resolve().parents[2])
    print(json.dumps(result, indent=2))
    if not result["sourceConsistencyPassed"]:
        raise SystemExit("M172: basic locale/theme/a11y regression gate blocked")
