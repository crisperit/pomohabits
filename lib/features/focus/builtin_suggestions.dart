import 'dart:math';

/// Identifiers for the shipped fallback break nudges (FR-011).
///
/// Localized strings for each value live in the ARB files under matching
/// `breakSuggestion*` keys. The mapping is done in the Phase 4 UI layer to
/// avoid a dependency on generated l10n from pure logic.
enum BuiltInSuggestion {
  stretch,
  hydrate,
  lookAway,
  breathe,
  walk,
}

/// Returns a uniformly random [BuiltInSuggestion] using the supplied [random].
///
/// Inject a seeded [Random] in tests for deterministic results.
BuiltInSuggestion pickBuiltInSuggestion(Random random) {
  return BuiltInSuggestion.values[random.nextInt(BuiltInSuggestion.values.length)];
}
