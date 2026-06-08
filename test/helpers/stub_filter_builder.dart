import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal fake builder that delegates [then] to an inner future and routes
/// everything else through [noSuchMethod]. This satisfies the static type
/// [PostgrestFilterBuilder] that [SupabaseClient.rpc] returns, which Dart
/// would otherwise fail to downcast from a plain [Future].
class StubFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  StubFilterBuilder(this._future);
  final Future<T> _future;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) =>
      _future.then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
