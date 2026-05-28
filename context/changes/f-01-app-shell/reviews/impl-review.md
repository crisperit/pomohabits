<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: F-01 Flutter App Shell

- **Plan**: context/changes/f-01-app-shell/plan.md
- **Scope**: Full plan (4 phases)
- **Date**: 2026-05-28
- **Verdict**: NEEDS ATTENTION (resolved through triage)
- **Findings**: 0 critical, 3 warnings, 5 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | WARNING |
| Scope Discipline | PASS |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS |

## Findings

### F1 - SettingsDialog uses DropdownMenu instead of RadioListTile

- **Severity**: WARNING
- **Impact**: MEDIUM, real tradeoff
- **Dimension**: Plan Adherence
- **Location**: lib/features/settings/presentation/settings_dialog.dart
- **Detail**: Phase 3 contract specifies two RadioListTile groups separated by a Divider. Implementation uses two DropdownMenu with a SizedBox spacer. Functionally equivalent; signed off in manual verification 3.4 to 3.9.
- **Decision**: FIXED via Fix A (documented as in-scope deviation in plan Addenda)

### F2 - Uncaught non-env exceptions in main() show blank crash screen

- **Severity**: WARNING
- **Impact**: MEDIUM
- **Dimension**: Safety & Quality (Reliability)
- **Location**: lib/main.dart:14-21
- **Detail**: try/catch only catches SupabaseEnvException. Other failures from Supabase.initialize() or SharedPreferences.getInstance() propagate uncaught, showing the red Flutter overlay instead of the planned ErrorApp.
- **Decision**: FIXED (boot block wrapped in single try, broad catch funnels any boot exception to ErrorApp)

### F3 - Fire-and-forget prefs writes diverge silently from disk

- **Severity**: WARNING
- **Impact**: LOW
- **Dimension**: Safety & Quality (Data safety)
- **Location**: lib/core/preferences/preferences_providers.dart + lib/features/settings/presentation/settings_dialog.dart
- **Detail**: set() methods updated state optimistically before awaiting prefs.setString; returned Future discarded fire-and-forget at SettingsDialog call sites; unawaited_futures lint not enabled.
- **Decision**: FIXED (rollback-on-exception in both notifiers; unawaited_futures lint enabled; call sites wrapped with unawaited())

### F4 - GoRouterRefreshStream notifies before subscription assigned

- **Severity**: OBSERVATION
- **Impact**: LOW
- **Dimension**: Safety & Quality (Reliability)
- **Location**: lib/app/router.dart:40-42
- **Detail**: Constructor called notifyListeners() before late final _subscription was assigned. Harmless in real usage but a latent ordering footgun.
- **Decision**: FIXED (subscription assigned before notifyListeners(); already in place when revisited)

### F5 - ARB system-default values shortened to "Auto"

- **Severity**: OBSERVATION
- **Impact**: LOW
- **Dimension**: Plan Adherence
- **Location**: lib/l10n/app_en.arb, lib/l10n/app_pl.arb
- **Detail**: themeSystem and localeSystem ship "Auto" in both locales instead of "Follow system"/"Zgodnie z systemem" and "Device default"/"Domyślny dla urządzenia". Intentional UX simplification.
- **Decision**: FIXED via documentation (second Addenda bullet in plan)

### F6 - l10n.yaml missing explicit synthetic-package: false

- **Severity**: OBSERVATION
- **Impact**: LOW
- **Dimension**: Plan Adherence
- **Location**: l10n.yaml
- **Detail**: Plan contract mandated the directive. Adding it triggered a Flutter 3.27+ deprecation warning on every pub get; the directive is a no-op in this toolchain.
- **Decision**: RESOLVED (plan spec is stale; third Addenda bullet in plan documents the deprecation; l10n.yaml stays at three lines)

### F7 - test/.gitkeep not created

- **Severity**: OBSERVATION
- **Impact**: LOW
- **Dimension**: Plan Adherence
- **Location**: test/.gitkeep (missing)
- **Detail**: Phase 1 contract required the placeholder but test/ is now populated by real tests.
- **Decision**: SKIPPED (placeholder is obsolete)

### F8 - unawaited_futures lint not enabled

- **Severity**: OBSERVATION
- **Impact**: LOW
- **Dimension**: Pattern Consistency
- **Location**: analysis_options.yaml
- **Detail**: Enabling unawaited_futures would mechanically catch the class of bugs flagged in F3.
- **Decision**: ACCEPTED-AS-RULE ("Enable strict data-safety lints from project bootstrap" in context/foundation/lessons.md). Fix itself was already applied as a side effect of F3.

## Triage Summary

- Fixed: F1, F2, F3, F4, F5
- Resolved (plan spec stale): F6
- Skipped: F7
- Accepted as rule: F8 (lesson recorded; fix already applied via F3)
