import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Provider que apenas informa QUEM é o usuário logado (User do Firebase Auth)
final authUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 2. O PROVIDER MAIS IMPORTANTE:
// Ele pega o ID do usuário logado (do provider acima) e busca os dados no Firestore (Nome, Tipo, etc).
// Se o usuário deslogar, ele zera. Se logar, ele busca. Tudo automático.
final userProfileProvider = StreamProvider<DocumentSnapshot?>((ref) {
  // O 'ref.watch' conecta esse provider ao de cima. 
  // Se o authUser mudar (login/logout), esse aqui roda de novo.
  final authState = ref.watch(authUserProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null); // Ninguém logado
      
      // Retorna o fluxo de dados do Firestore em tempo real
      return FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots();
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});