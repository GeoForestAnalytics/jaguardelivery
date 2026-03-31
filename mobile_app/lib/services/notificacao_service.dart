import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class NotificacaoService {
  static final _supabase = Supabase.instance.client;

  /// Chama uma vez no main() após Supabase.initialize()
  static Future<void> inicializar() async {
    OneSignal.initialize(OneSignalConfig.appId);
    await OneSignal.Notifications.requestPermission(true);

    // Salva o player ID sempre que ele estiver disponível / mudar
    OneSignal.User.pushSubscription.addObserver((state) {
      final id = state.current.id;
      if (id != null) _salvarPlayerId(id);
    });

    final idAtual = OneSignal.User.pushSubscription.id;
    if (idAtual != null) await _salvarPlayerId(idAtual);
  }

  static Future<void> _salvarPlayerId(String playerId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('usuarios')
          .update({'onesignal_player_id': playerId})
          .eq('id', userId);
    } catch (_) {}
  }

  // ─── Envio via Supabase Edge Function (mantém a REST key no servidor) ──────

  static Future<void> _enviar({
    required List<String> playerIds,
    required String titulo,
    required String mensagem,
    Map<String, dynamic>? dados,
  }) async {
    if (playerIds.isEmpty) return;
    try {
      await _supabase.functions.invoke('notificar', body: {
        'player_ids': playerIds,
        'titulo':     titulo,
        'mensagem':   mensagem,
        'dados':      dados ?? {},
      });
    } catch (_) {}
  }

  // ─── Helpers de busca de player IDs ────────────────────────────────────────

  static Future<String?> _playerIdDe(String userId) async {
    try {
      final row = await _supabase
          .from('usuarios')
          .select('onesignal_player_id')
          .eq('id', userId)
          .maybeSingle();
      return row?['onesignal_player_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> _playerIdsDeMotoboys() async {
    try {
      final rows = await _supabase
          .from('usuarios')
          .select('onesignal_player_id')
          .eq('tipo', 'MOTOBOY')
          .not('onesignal_player_id', 'is', null);
      return (rows as List)
          .map((r) => r['onesignal_player_id'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Métodos públicos ───────────────────────────────────────────────────────

  /// Nova corrida criada — notifica todos os motoboys disponíveis
  static Future<void> novaCorrida(String enderecoDest) async {
    final ids = await _playerIdsDeMotoboys();
    await _enviar(
      playerIds: ids,
      titulo:    '🏍️ Nova corrida disponível!',
      mensagem:  'Destino: $enderecoDest',
      dados:     {'tipo': 'nova_corrida'},
    );
  }

  /// Novo pedido comercial — notifica todos os motoboys
  static Future<void> novoPedidoComercial(String enderecoDestino) async {
    final ids = await _playerIdsDeMotoboys();
    await _enviar(
      playerIds: ids,
      titulo:    '📦 Novo pedido de entrega!',
      mensagem:  'Entrega em: $enderecoDestino',
      dados:     {'tipo': 'novo_pedido'},
    );
  }

  /// Motoboy aceitou — notifica o cliente
  static Future<void> corridaAceita({
    required String idCliente,
    required String nomeMotoboy,
  }) async {
    final pid = await _playerIdDe(idCliente);
    if (pid == null) return;
    await _enviar(
      playerIds: [pid],
      titulo:    '✅ Motoboy a caminho!',
      mensagem:  '$nomeMotoboy aceitou e está indo buscar você.',
      dados:     {'tipo': 'aceito'},
    );
  }

  /// Motoboy coletou e saiu para entrega — notifica o cliente
  static Future<void> corridaEmViagem({required String idCliente}) async {
    final pid = await _playerIdDe(idCliente);
    if (pid == null) return;
    await _enviar(
      playerIds: [pid],
      titulo:    '🚀 A caminho do destino!',
      mensagem:  'Seu pedido foi coletado e está sendo entregue.',
      dados:     {'tipo': 'em_viagem'},
    );
  }

  /// Corrida finalizada — notifica o cliente
  static Future<void> corridaFinalizada({required String idCliente}) async {
    final pid = await _playerIdDe(idCliente);
    if (pid == null) return;
    await _enviar(
      playerIds: [pid],
      titulo:    '🎉 Pedido entregue!',
      mensagem:  'Sua entrega foi concluída com sucesso.',
      dados:     {'tipo': 'finalizado'},
    );
  }
}
