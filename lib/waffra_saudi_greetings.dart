/// Saudi Arabic greetings rotate on each verified cold app launch.
/// Gender is used only when explicit, otherwise neutral language is used.
abstract final class WaffraSaudiGreetings {
  static const masculine = <String>[
    'يا مرحبا ونوّرت', 'حيّاك الله', 'هلا ومرحبا بك',
    'أبرك الساعات بوجودك', 'نورت الدار',
  ];
  static const feminine = <String>[
    'يا مرحبا ونوّرتي', 'حيّاكِ الله', 'هلا ومرحبا بكِ',
    'أبرك الساعات بوجودكِ', 'نورتي الدار',
  ];
  static const neutral = <String>[
    'يا مرحبا', 'حيّاك الله', 'أهلًا وسهلًا', 'مرحبا بك', 'يا مرحبتين',
  ];
  static const egyptianGreetings = <String>[
    'يا أهلاً', 'نورت وفرة', 'أهلاً وسهلاً',
    'منوّر من تاني', 'أهلاً برجوعك',
  ];
  static const standardGreetings = <String>[
    'مرحبًا بك', 'أهلًا وسهلًا', 'سعداء بعودتك',
    'أهلًا من جديد', 'نتمنى لك يومًا سعيدًا',
  ];
  static const englishGreetings = <String>[
    'Welcome back', 'Great to see you', 'A warm welcome',
    'Good to have you back', 'Hello again',
  ];

  static int nextIndex(int? previous) =>
      ((previous ?? -1) + 1) % neutral.length;

  static String compose({
    required String name,
    required String gender,
    required bool english,
    required int greetingIndex,
    String countryIso='SA',
  }) {
    final cleanName = name.trim() == 'يا غالي' ? '' : name.trim();
    final slot = greetingIndex % neutral.length;
    if (english) {
      final welcome = englishGreetings[slot];
      return cleanName.isEmpty ? '$welcome 👋' : '$welcome, $cleanName 👋';
    }
    final g = gender.trim().toLowerCase();
    final greetings = countryIso=='SA'
      ?(g == 'أنثى' || g == 'female' ? feminine :
        g == 'ذكر' || g == 'male' ? masculine : neutral)
      :countryIso=='EG'?egyptianGreetings:standardGreetings;
    return cleanName.isEmpty
      ? '${greetings[slot]} 👋'
      : '${greetings[slot]} يا $cleanName 👋';
  }
}
