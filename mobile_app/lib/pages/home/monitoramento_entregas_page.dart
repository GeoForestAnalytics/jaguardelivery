import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MonitoramentoEntregasPage extends StatefulWidget {
  final List<Map<String, dynamic>> pedidos;

  const MonitoramentoEntregasPage({required this.pedidos, super.key});

  @override
  State<MonitoramentoEntregasPage> createState() =>
      _MonitoramentoEntregasPageState();
}

class _MonitoramentoEntregasPageState
    extends State<MonitoramentoEntregasPage> {
  final _supabase = Supabase.instance.client;
  int _indiceAtual = 0;
  bool _carregando = false;
  Timer? _timerLocalizacao;

  @override
  void initState() {
    super.initState();
    _iniciarBroadcastLocalizacao();
  }

  @override
  void dispose() {
    _timerLocalizacao?.cancel();
    super.dispose();
  }

  void _iniciarBroadcastLocalizacao() {
    _timerLocalizacao = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition();
        for (final p in _pedidos) {
          final st = p['status'] as String? ?? '';
          if (st == 'ACEITO' || st == 'EM_VIAGEM') {
            await _supabase.from('pedidos').update({
              'lat_motoboy':  pos.latitude,
              'long_motoboy': pos.longitude,
            }).eq('id', p['id']);
          }
        }
      } catch (_) {}
    });
  }

  Map<String, dynamic> get _pedidoAtual => _pedidos[_indiceAtual];
  List<Map<String, dynamic>> get _pedidos => widget.pedidos;

  int get _total => _pedidos.length;
  int get _finalizados =>
      _pedidos.where((p) => p['status'] == 'FINALIZADO').length;

  @override
  Widget build(BuildContext context) {
    final status = _pedidoAtual['status'] as String? ?? 'ACEITO';
    final (corStatus, labelStatus) = _infoStatus(status);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rota de Entregas',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('$_finalizados de $_total concluídas',
                style:
                    const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de progresso
          _BarraProgresso(finalizados: _finalizados, total: _total),

          // Lista de entregas (scroll lateral - tabs)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _total,
              itemBuilder: (context, i) {
                final p      = _pedidos[i];
                final st     = p['status'] as String? ?? 'ACEITO';
                final ativo  = i == _indiceAtual;
                final (cor, label) = _infoStatus(st);

                return GestureDetector(
                  onTap: () => setState(() => _indiceAtual = i),
                  onLongPress: (st == 'FINALIZADO' || st == 'CANCELADO')
                      ? () => _excluirPedido(i)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ativo ? Colors.green[700]! : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        if (ativo)
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        else
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                          ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: cor.withValues(alpha: 0.15),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: cor)),
                      ),
                      title: Text(p['cliente_nome'] ?? 'Cliente',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            p['endereco_destino'] ??
                                'Endereço não informado',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: cor,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      trailing: Text(
                        'R\$ ${(p['valor_total'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                            fontSize: 14),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Painel de ação da entrega atual
          if (status != 'FINALIZADO')
            _PainelAcao(
              pedido: _pedidoAtual,
              status: status,
              corStatus: corStatus,
              labelStatus: labelStatus,
              carregando: _carregando,
              onAvancar: _avancarStatus,
              onAbrirMaps: _abrirMaps,
              onWhatsApp: () {
                final tel = _pedidoAtual['cliente_tel'] as String? ?? '';
                if (tel.isNotEmpty) _abrirWhatsApp(tel);
              },
            ),

          if (status == 'FINALIZADO' && _finalizados < _total)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('PRÓXIMA ENTREGA',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _proximaEntregaPendente,
                ),
              ),
            ),

          if (_finalizados == _total)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.celebration,
                      color: Colors.amber, size: 48),
                  const SizedBox(height: 8),
                  const Text('Todas as entregas concluídas! 🎉',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('VOLTAR AO MAPA',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  (Color, String) _infoStatus(String status) => switch (status) {
        'ACEITO'     => (Colors.blue, 'A caminho da coleta'),
        'EM_VIAGEM'  => (Colors.indigo, 'Em viagem'),
        'FINALIZADO' => (Colors.green, 'Entregue ✓'),
        _            => (Colors.orange, 'Pendente'),
      };

  Future<void> _excluirPedido(int indice) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir entrega?'),
        content: const Text('Deseja remover este item da lista?'),
        actions: [
          TextButton(
              child: const Text('Não'),
              onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
            child: const Text('Excluir',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _supabase.from('pedidos').delete().eq('id', _pedidos[indice]['id']);
      setState(() {
        _pedidos.removeAt(indice);
        if (_pedidos.isEmpty) {
          Navigator.pop(context);
          return;
        }
        _indiceAtual = _indiceAtual.clamp(0, _pedidos.length - 1);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _abrirWhatsApp(String tel) async {
    final numero = tel.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/55$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _avancarStatus() async {
    setState(() => _carregando = true);
    final status = _pedidoAtual['status'] as String? ?? 'ACEITO';
    final novoStatus =
        status == 'ACEITO' ? 'EM_VIAGEM' : 'FINALIZADO';

    try {
      await _supabase.from('pedidos').update({
        'status': novoStatus,
        if (novoStatus == 'FINALIZADO')
          'data_finalizacao': DateTime.now().toIso8601String(),
      }).eq('id', _pedidoAtual['id']);

      setState(() {
        _pedidos[_indiceAtual] = {
          ..._pedidoAtual,
          'status': novoStatus,
        };
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _proximaEntregaPendente() {
    for (int i = 0; i < _total; i++) {
      if (_pedidos[i]['status'] != 'FINALIZADO') {
        setState(() => _indiceAtual = i);
        return;
      }
    }
  }

  void _abrirMaps() async {
    final lat = _pedidoAtual['lat_destino'];
    final lng = _pedidoAtual['long_destino'];
    final endereco = Uri.encodeComponent(
        _pedidoAtual['endereco_destino'] ?? '');

    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
          'google.navigation:q=$lat,$lng&mode=d');
    } else {
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$endereco&travelmode=driving');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallback = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$endereco&travelmode=driving');
      await launchUrl(fallback,
          mode: LaunchMode.externalApplication);
    }
  }
}

// ─── Widgets internos ───────────────────────────────────────

class _BarraProgresso extends StatelessWidget {
  final int finalizados;
  final int total;
  const _BarraProgresso(
      {required this.finalizados, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : finalizados / total;
    return Container(
      color: Colors.white,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progresso',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 12)),
              Text('$finalizados/$total',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700])),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: Colors.green[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _PainelAcao extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final String status;
  final Color corStatus;
  final String labelStatus;
  final bool carregando;
  final VoidCallback onAvancar;
  final VoidCallback onAbrirMaps;
  final VoidCallback onWhatsApp;

  const _PainelAcao({
    required this.pedido,
    required this.status,
    required this.corStatus,
    required this.labelStatus,
    required this.carregando,
    required this.onAvancar,
    required this.onAbrirMaps,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final botaoLabel =
        status == 'ACEITO' ? 'CONFIRMAR COLETA' : 'CONFIRMAR ENTREGA';
    final botaoCor =
        status == 'ACEITO' ? Colors.blue[700]! : Colors.green[700]!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: corStatus, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(labelStatus,
                  style: TextStyle(
                      color: corStatus, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status == 'ACEITO'
                ? 'Coletar em: ${pedido['comercio_nome'] ?? 'Estabelecimento'}'
                : 'Entregar para: ${pedido['cliente_nome'] ?? 'Cliente'}\n${pedido['endereco_destino'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: botaoCor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: carregando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(botaoLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    onPressed: carregando ? null : onAvancar,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                width: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onAbrirMaps,
                  child: const Icon(Icons.map),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                width: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onWhatsApp,
                  child: const Icon(Icons.chat),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
