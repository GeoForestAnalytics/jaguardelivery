import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // Ouvir pedidos pendentes (Radar do Motoboy)
  Stream<List<Map<String, dynamic>>> ouvirPedidosPendentes() {
    return _supabase
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('status', 'PENDENTE')
        .order('criado_em');
  }

  // Aceitar um pedido
  Future<void> aceitarPedido(String pedidoId, String motoboyId) async {
    await _supabase.from('pedidos').update({
      'status': 'ACEITO',
      'motoboy_id': motoboyId,
    }).eq('id', pedidoId);
  }
}