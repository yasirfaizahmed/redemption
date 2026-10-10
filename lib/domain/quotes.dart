import 'app_settings.dart';

class Quote {
  const Quote(this.text, this.source);
  final String text;
  final String source;
}

/// Curated reminders. Translations of the Qur'an follow Sahih International
/// wording; hadith are from the two Sahih collections unless noted.
abstract final class Quotes {
  static const faith = <Quote>[
    Quote(
      'Indeed, Allah will not change the condition of a people until they '
          'change what is in themselves.',
      'Qur’an 13:11',
    ),
    Quote(
      'And those who strive for Us — We will surely guide them to Our ways.',
      'Qur’an 29:69',
    ),
    Quote(
      'For indeed, with hardship will be ease. Indeed, with hardship will be '
          'ease.',
      'Qur’an 94:5–6',
    ),
    Quote(
      'He has succeeded who purifies it, and he has failed who instills it '
          'with corruption.',
      'Qur’an 91:9–10',
    ),
    Quote(
      'Allah does not charge a soul except with that within its capacity.',
      'Qur’an 2:286',
    ),
    Quote('And seek help through patience and prayer.', 'Qur’an 2:45'),
    Quote(
      'Indeed, prayer prohibits immorality and wrongdoing.',
      'Qur’an 29:45',
    ),
    Quote(
      'The most beloved of deeds to Allah are those that are most consistent, '
          'even if they are small.',
      'Bukhari & Muslim',
    ),
    Quote(
      'The strong one is not the one who overcomes people by his strength, '
          'but the strong one is he who controls himself when angry.',
      'Bukhari & Muslim',
    ),
    Quote(
      'The strong believer is better and more beloved to Allah than the weak '
          'believer, while there is good in both.',
      'Sahih Muslim',
    ),
  ];

  static const discipline = <Quote>[
    Quote(
      'Neurons that fire together, wire together.',
      'Hebbian principle, neuroscience',
    ),
    Quote(
      'You do not rise to the level of your goals. You fall to the level of '
          'your systems.',
      'James Clear',
    ),
    Quote(
      'We are what we repeatedly do. Excellence, then, is not an act, but a '
          'habit.',
      'Will Durant',
    ),
    Quote(
      'The chains of habit are too weak to be felt until they are too strong '
          'to be broken.',
      'Samuel Johnson',
    ),
    Quote(
      'Waste no more time arguing about what a good man should be. Be one.',
      'Marcus Aurelius',
    ),
    Quote(
      'Missing once is an accident. Missing twice is the start of a new '
          'habit. Never miss twice.',
      'James Clear',
    ),
  ];

  static List<Quote> forPack(QuotePack pack) => switch (pack) {
    QuotePack.faith => faith,
    QuotePack.discipline => discipline,
    QuotePack.both => [...faith, ...discipline],
  };

  /// Deterministic quote for a day so it stays stable across app launches.
  static Quote ofTheDay(QuotePack pack, int dayNumber) {
    final list = forPack(pack);
    return list[(dayNumber.abs()) % list.length];
  }
}
