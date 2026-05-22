import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/preferences.dart';
import '../onboarding/country_controller.dart';

/// The user's selected outlet for the *current* country, or null = "All
/// outlets" (country-wide availability — the default).
///
/// Persisted per-country in SharedPreferences. `build()` watches the country
/// selection, so switching country re-loads that country's stored outlet (or
/// resets to null). Anything that depends on this — the menu list/detail
/// queries — re-runs automatically.
class OutletController extends Notifier<int?> {
  @override
  int? build() {
    final code = ref.watch(countrySelectionProvider).countryCode;
    // Hydrate asynchronously; UI shows "All outlets" until ready.
    Future.microtask(() => _load(code));
    return null;
  }

  Future<void> _load(String countryCode) async {
    final prefs = await ref.read(preferencesProvider.future);
    state = prefs.getInt(PrefsKeys.outlet(countryCode));
  }

  Future<void> setOutlet(int? outletId) async {
    final code = ref.read(countrySelectionProvider).countryCode;
    state = outletId;
    final prefs = await ref.read(preferencesProvider.future);
    if (outletId == null) {
      await prefs.remove(PrefsKeys.outlet(code));
    } else {
      await prefs.setInt(PrefsKeys.outlet(code), outletId);
    }
  }
}

final selectedOutletProvider =
    NotifierProvider<OutletController, int?>(OutletController.new);
