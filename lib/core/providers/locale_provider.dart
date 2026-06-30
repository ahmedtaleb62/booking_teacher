import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

const _kLangKey = 'language_preference';

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ar')) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangKey) ?? 'ar';
    state = Locale(saved);

    try {
      final uid = SupabaseService.userId;
      if (uid == null) return;
      final data = await SupabaseService.client
          .from('profiles')
          .select('language_preference')
          .eq('id', uid)
          .single();
      final remote = (data['language_preference'] as String?) ?? 'ar';
      if (remote != saved) {
        state = Locale(remote);
        await prefs.setString(_kLangKey, remote);
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, locale.languageCode);
    try {
      final uid = SupabaseService.userId;
      if (uid == null) return;
      await SupabaseService.client
          .from('profiles')
          .update({'language_preference': locale.languageCode})
          .eq('id', uid);
    } catch (_) {}
  }
}
