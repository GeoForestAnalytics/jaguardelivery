import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// Provider do usuário autenticado (quem está logado)
final authUserProvider = StreamProvider<User?>((ref) {
  return _supabase.auth.onAuthStateChange.map((data) => data.session?.user);
});

// Provider do perfil completo do usuário (dados da tabela usuarios)
final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authUserProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return _supabase
          .from('usuarios')
          .stream(primaryKey: ['id'])
          .eq('id', user.id)
          .map((rows) => rows.isNotEmpty ? rows.first : null);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});
