import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 1. AJUSTE AQUI: Adicione o "hide User" para evitar conflito com o Firebase
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'firebase_options.dart'; 
import 'pages/auth/login_page.dart';
import 'pages/home/mapa_page.dart';

void main() async {
  // 1. Garante que o motor do Flutter esteja pronto
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicia o Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Inicia o Supabase
  await Supabase.initialize(
    url: 'https://ecmxxtocvbfbnlpnnqqi.supabase.co',
    anonKey: 'sb_publishable_zW8lTB422gDal0DSXiTDDg_CQ-WhlBT', 
  );

  // 4. Roda o App com Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jaguar Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const RoteadorDeTelas(),
    );
  }
}

class RoteadorDeTelas extends StatelessWidget {
  const RoteadorDeTelas({super.key});

  @override
  Widget build(BuildContext context) {
    // Agora o 'User' aqui será obrigatoriamente o do Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData) {
          return MapaPage(); 
        }

        return LoginPage(); 
      },
    );
  }
}