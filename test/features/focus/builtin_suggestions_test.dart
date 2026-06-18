import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:pomohabits/features/focus/builtin_suggestions.dart';

void main() {
  group('BuiltInSuggestion.values', () {
    test('contains all five enum values', () {
      expect(BuiltInSuggestion.values, containsAll(BuiltInSuggestion.values));
      expect(BuiltInSuggestion.values.length, 5);
    });
  });

  group('pickBuiltInSuggestion', () {
    test('returns a valid BuiltInSuggestion enum value', () {
      final result = pickBuiltInSuggestion(Random());
      expect(BuiltInSuggestion.values, contains(result));
    });

    test('is deterministic under a seeded Random', () {
      final a = pickBuiltInSuggestion(Random(42));
      final b = pickBuiltInSuggestion(Random(42));
      expect(a, equals(b));
    });

    test('different seeds can produce different results', () {
      // With 5 values, seeds 0 and 1 are virtually certain to differ.
      final results = List.generate(
        10,
        (i) => pickBuiltInSuggestion(Random(i)),
      );
      // At least two distinct values must appear across 10 seeds.
      expect(results.toSet().length, greaterThan(1));
    });

    test('seed 0 always picks the same value as another Random(0)', () {
      final expected = pickBuiltInSuggestion(Random(0));
      for (var i = 0; i < 5; i++) {
        expect(pickBuiltInSuggestion(Random(0)), equals(expected));
      }
    });
  });
}
