# Lessons Learned

> Append-only register of recurring rules and patterns. Re-read at start by /10x-frame, /10x-research, /10x-plan, /10x-plan-review, /10x-implement, /10x-impl-review.

## Enable strict data-safety lints from project bootstrap

- **Context**: analysis_options.yaml for a Dart/Flutter project, near the project bootstrap moment when lint rules are first declared.
- **Problem**: Fire-and-forget `Future` returns from optimistic setters (e.g. `notifier.set(v)` in a UI callback that calls `await prefs.setString(...)` underneath) silently lose disk writes on failure. The analyzer cannot flag the discarded `Future` at the call sites unless `unawaited_futures` is enabled, so the divergence between in-memory and persisted state goes unnoticed in CI.
- **Rule**: Enable `unawaited_futures` (and the small cluster of strict-data-flow lints) when first writing `analysis_options.yaml`, not after a data-loss bug surfaces.
- **Applies to**: Dart/Flutter projects, specifically when configuring `analysis_options.yaml` for the first time or auditing it.
