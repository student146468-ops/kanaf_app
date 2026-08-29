import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KanafLocalizations {
  const KanafLocalizations(this.locale, this._values);

  final Locale locale;
  final Map<String, String> _values;

  static const LocalizationsDelegate<KanafLocalizations> delegate =
      _KanafLocalizationsDelegate();

  static KanafLocalizations of(BuildContext context) =>
      Localizations.of<KanafLocalizations>(context, KanafLocalizations)!;

  bool get isArabic => locale.languageCode == 'ar';

  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  String tr(String key, {Map<String, Object?> args = const {}}) {
    var value = _values[key] ?? key;
    for (final entry in args.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return value;
  }

  static Future<KanafLocalizations> load(Locale locale) async {
    final languageCode = locale.languageCode == 'en' ? 'en' : 'ar';
    final raw = await rootBundle.loadString('assets/l10n/$languageCode.arb');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return KanafLocalizations(
      Locale(languageCode),
      {
        for (final entry in data.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            entry.key: entry.value as String,
      },
    );
  }
}

class _KanafLocalizationsDelegate
    extends LocalizationsDelegate<KanafLocalizations> {
  const _KanafLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const {'ar', 'en'}.contains(locale.languageCode);

  @override
  Future<KanafLocalizations> load(Locale locale) =>
      KanafLocalizations.load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<KanafLocalizations> old) =>
      false;
}

extension KanafLocalizationsX on BuildContext {
  KanafLocalizations get l10n => KanafLocalizations.of(this);

  String tr(String key, {Map<String, Object?> args = const {}}) =>
      l10n.tr(key, args: args);
}
