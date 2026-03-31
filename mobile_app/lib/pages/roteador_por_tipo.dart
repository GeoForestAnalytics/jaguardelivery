import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import 'home/mapa_page.dart';
import 'comercio/painel_comercio_page.dart';

/// Após o login, redireciona o usuário para a página correta
/// conforme seu tipo: CLIENTE, MOTOBOY, COMERCIO ou ADMIN.
class RoteadorPorTipo extends ConsumerWidget {
  const RoteadorPorTipo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(userProfileProvider);

    return perfilAsync.when(
      loading: () => const _TelaCarregando(),
      error: (err, _) => _TelaErro(
        mensagem: "Erro ao carregar perfil.\nTente sair e entrar novamente.",
        onTentar: () => ref.invalidate(userProfileProvider),
      ),
      data: (perfil) {
        // Perfil ainda não chegou do stream — aguardar
        if (perfil == null) return const _TelaCarregando();

        final tipo = perfil['tipo']?.toString().toUpperCase() ?? 'CLIENTE';

        return switch (tipo) {
          'COMERCIO' => const PainelComercioPage(),
          // CLIENTE, MOTOBOY e ADMIN usam o MapaPage
          // (o drawer e o toggle interno tratam MOTOBOY e ADMIN)
          _ => MapaPage(),
        };
      },
    );
  }
}

class _TelaCarregando extends StatelessWidget {
  const _TelaCarregando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF011D42),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 20),
            Text(
              "Carregando...",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelaErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentar;

  const _TelaErro({required this.mensagem, required this.onTentar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF011D42),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: Colors.orange, size: 64),
              const SizedBox(height: 20),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: onTentar,
                icon: const Icon(Icons.refresh),
                label: const Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
