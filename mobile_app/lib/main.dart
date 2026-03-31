import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/auth/login_page.dart';
import 'pages/roteador_por_tipo.dart';
import 'services/notificacao_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ecmxxtocvbfbnlpnnqqi.supabase.co',
    anonKey: 'sb_publishable_zW8lTB422gDal0DSXiTDDg_CQ-WhlBT',
  );

  // Push notifications via OneSignal (não precisa de Firebase)
  await NotificacaoService.inicializar();
  await initializeDateFormatting('pt_BR', null);

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
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data?.session;
        if (session != null) {
          return const RoteadorPorTipo();
        }

        return LoginPage();
      },
    );
  }
}
