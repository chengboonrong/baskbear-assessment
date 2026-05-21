import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/countries_repository.dart';
import '../../shared/widgets/lotties.dart';
import 'country_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String? _country;
  String? _locale;
  bool _committed = false;

  @override
  Widget build(BuildContext context) {
    // First launch tries to detect the user's country from device location.
    // On a supported match we persist it and skip straight to the menu; the
    // manual picker below is the fallback for denied/unsupported/web cases.
    final auto = ref.watch(autoSelectionProvider);
    return auto.when(
      loading: () => _statusScaffold('Finding your location…'),
      error: (_, _) => _buildPicker(context),
      data: (selection) {
        if (selection == null) return _buildPicker(context);
        if (!_committed) {
          _committed = true;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _commit(selection));
        }
        return _statusScaffold('Setting up ${selection.countryCode}…');
      },
    );
  }

  Future<void> _commit(CountrySelection selection) async {
    await ref
        .read(countrySelectionProvider.notifier)
        .setCountry(selection.countryCode, locale: selection.localeCode);
    ref.invalidate(onboardedProvider);
    if (mounted) context.go('/menu');
  }

  Widget _statusScaffold(String message) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LottieLoader(size: 130, center: false),
                const SizedBox(height: 8),
                Text(message),
              ],
            ),
          ),
        ),
      );

  Widget _buildPicker(BuildContext context) {
    final countriesAsync = ref.watch(countriesListProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: BearAvatar(size: 104)),
              const SizedBox(height: 12),
              Text('Baskbear',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Where are you ordering from?',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 32),
              Expanded(
                child: countriesAsync.when(
                  loading: () => const LottieLoader(),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            "Couldn't reach Baskbear. Check your connection "
                            'and that the app points at a running API.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () =>
                                ref.invalidate(countriesListProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (countries) {
                    final selected = countries.firstWhere(
                      (c) => c.code == _country,
                      orElse: () => countries.first,
                    );
                    _country ??= selected.code;
                    _locale ??= selected.defaultLocale;
                    return ListView(
                      children: [
                        for (final c in countries)
                          Card(
                            child: RadioListTile<String>(
                              value: c.code,
                              groupValue: _country,
                              title: Text(c.name),
                              subtitle: Text('${c.currencyCode} · ${c.locales.map((l) => l.code).join(', ')}'),
                              onChanged: (v) => setState(() {
                                _country = v;
                                _locale = c.defaultLocale;
                              }),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Text('Language',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final l in selected.locales)
                              ChoiceChip(
                                label: Text(l.code.toUpperCase()),
                                selected: _locale == l.code,
                                onSelected: (_) => setState(() => _locale = l.code),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              FilledButton(
                onPressed: _country == null
                    ? null
                    : () async {
                        await ref.read(countrySelectionProvider.notifier)
                            .setCountry(_country!, locale: _locale);
                        ref.invalidate(onboardedProvider);
                        if (mounted) context.go('/menu');
                      },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
