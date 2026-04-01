import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../providers/user_provider.dart';
import '../home/components/home_drawer.dart';
import 'nova_entrega_page.dart';
import 'rastreio_entrega_page.dart';
import 'whatsapp_conectar_page.dart';

class PainelComercioPage extends ConsumerStatefulWidget {
  const PainelComercioPage({super.key});

  @override
  ConsumerState<PainelComercioPage> createState() => _PainelComercioPageState();
}

class _PainelComercioPageState extends ConsumerState<PainelComercioPage> {
  final _supabase   = Supabase.instance.client;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _corTema = Color(0xFF6A1B9A); // roxo

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(userProfileProvider);
    final userId      = _supabase.auth.currentUser?.id;

    final nomeFantasia = perfilAsync.valueOrNull?['nome_fantasia']
        ?? perfilAsync.valueOrNull?['nome']
        ?? 'Meu Estabelecimento';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[100],
      drawer: HomeDrawer(souMotoboy: false, corTema: _corTema),

      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Painel do Comerciante',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(nomeFantasia,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: _corTema,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),

      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('pedidos')
                  .stream(primaryKey: ['id'])
                  .eq('comercio_id', userId)
                  .order('criado_em', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro ao carregar pedidos.',
                        textAlign: TextAlign.center),
                  );
                }

                final todosOsPedidos = snapshot.data ?? [];

                // LISTA FILTRADA: Só mostra o que está ativo (não finalizado/cancelado)
                final pedidosAtivos = todosOsPedidos.where((p) {
                  final st = p['status'] ?? 'PENDENTE';
                  return st != 'FINALIZADO' && st != 'CANCELADO';
                }).toList();

                final perfil = ref.watch(userProfileProvider).valueOrNull;
                final whatsConnected = perfil?['whatsapp_conectado'] == true;

                return Column(
                  children: [
                    _ResumoBar(pedidos: todosOsPedidos),
                    _WhatsappStatusCard(
                      conectado: whatsConnected,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const WhatsappConectarPage())),
                    ),
                    Expanded(
                      child: pedidosAtivos.isEmpty
                          ? _EstadoVazio(onNovoPedido: _abrirNovoPedido)
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: pedidosAtivos.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) =>
                                  _CardPedidoSlidable(pedido: pedidosAtivos[i]),
                            ),
                    ),
                  ],
                );
              },
            ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _corTema,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_box),
        label: const Text('NOVA ENTREGA',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _abrirNovoPedido,
      ),
    );
  }

  void _abrirNovoPedido() async {
    final criou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NovaEntregaPage()),
    );
    if (criou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entrega publicada! Aguardando motoboy.'),
        backgroundColor: Colors.green,
      ));
    }
  }
}

// ─────────────────────────────────────────────
// Widgets de Estatísticas
// ─────────────────────────────────────────────

class _ResumoBar extends StatelessWidget {
  final List<Map<String, dynamic>> pedidos;
  const _ResumoBar({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    
    final pedidosHoje = pedidos.where((p) {
      final raw = p['criado_em'];
      if (raw == null) return false;
      final dt = DateTime.parse(raw);
      return dt.year == hoje.year && dt.month == hoje.month && dt.day == hoje.day;
    }).toList();

    final pendentes = pedidos.where((p) => p['status'] == 'PENDENTE').length;

    // Faturado Hoje: Apenas pedidos FINALIZADOS hoje
    final valorHoje = pedidosHoje
        .where((p) => p['status'] == 'FINALIZADO')
        .fold<double>(0, (sum, p) => sum + (p['valor_total'] ?? 0).toDouble());

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _MetricaCard(label: 'Hoje', valor: '${pedidosHoje.length}', icone: Icons.today, cor: Colors.blue),
          const SizedBox(width: 8),
          _MetricaCard(label: 'Pendentes', valor: '$pendentes', icone: Icons.access_time, cor: Colors.orange),
          const SizedBox(width: 8),
          _MetricaCard(label: 'Faturado hoje', valor: 'R\$ ${valorHoje.toStringAsFixed(2)}', icone: Icons.attach_money, cor: Colors.green),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Card com Funções de Arrastar (Swipe)
// ─────────────────────────────────────────────

class _CardPedidoSlidable extends StatefulWidget {
  final Map<String, dynamic> pedido;
  const _CardPedidoSlidable({required this.pedido});

  @override
  State<_CardPedidoSlidable> createState() => _CardPedidoSlidableState();
}

class _CardPedidoSlidableState extends State<_CardPedidoSlidable> {
  static const _actionWidth = 130.0;
  double _offset = 0;

  bool get _isPendente => (widget.pedido['status'] ?? 'PENDENTE') == 'PENDENTE';
  bool get _isAtivo    => ['ACEITO', 'EM_VIAGEM'].contains(widget.pedido['status']);

  void _fechar() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() => _offset = (_offset + d.delta.dx).clamp(-_actionWidth, 0)),
      onHorizontalDragEnd: (d) => setState(() => _offset = _offset < -_actionWidth / 2 ? -_actionWidth : 0),
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isPendente) ...[
                  _BotaoAcao(cor: Colors.blue[700]!, icone: Icons.edit, label: 'Editar', onTap: () {
                    _fechar();
                    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _EditarPedidoSheet(pedido: widget.pedido));
                  }),
                  _BotaoAcao(cor: Colors.red[700]!, icone: Icons.cancel, label: 'Cancelar', onTap: () {
                    _fechar();
                    _confirmarCancelamento(context);
                  }),
                ],
                if (_isAtivo)
                  _BotaoAcao(cor: Colors.indigo, icone: Icons.my_location, label: 'Rastrear', onTap: () {
                    _fechar();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RastreioEntregaPage(pedidoId: widget.pedido['id'], clienteNome: widget.pedido['cliente_nome'] ?? 'Cliente')));
                  }),
                // Opção de deletar registro
                _BotaoAcao(cor: Colors.black87, icone: Icons.delete_forever, label: 'Excluir', onTap: () {
                  _fechar();
                  _confirmarExclusao(context);
                }),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: _CardPedido(pedido: widget.pedido),
          ),
        ],
      ),
    );
  }

  void _confirmarCancelamento(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cancelar pedido?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Não')),
        TextButton(onPressed: () async {
          await Supabase.instance.client.from('pedidos').update({'status': 'CANCELADO'}).eq('id', widget.pedido['id']);
          Navigator.pop(ctx);
        }, child: const Text('Sim, Cancelar', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _confirmarExclusao(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir definitivamente?'),
      content: const Text('Esta ação apagará o pedido do banco de dados.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
        TextButton(onPressed: () async {
          await Supabase.instance.client.from('pedidos').delete().eq('id', widget.pedido['id']);
          Navigator.pop(ctx);
        }, child: const Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

// ─────────────────────────────────────────────
// Card Simples e Modal de Detalhes
// ─────────────────────────────────────────────

class _CardPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _CardPedido({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final status = pedido['status'] ?? 'PENDENTE';
    final (cor, icone) = switch (status) {
      'ACEITO'     => (Colors.blue, Icons.two_wheeler),
      'EM_VIAGEM'  => (Colors.indigo, Icons.local_shipping),
      _            => (Colors.orange, Icons.access_time),
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: cor.withOpacity(0.1), child: Icon(icone, color: cor)),
        title: Text(pedido['cliente_nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(pedido['endereco_destino'] ?? 'Endereço não informado', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('R\$ ${(pedido['valor_total'] ?? 0).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
        onTap: () => _mostrarDetalhes(context),
      ),
    );
  }

  void _mostrarDetalhes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalhes da Entrega', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            _Linha(icone: Icons.person, label: 'Cliente', valor: pedido['cliente_nome'] ?? '-'),
            _Linha(icone: Icons.phone, label: 'Telefone', valor: pedido['cliente_tel'] ?? '-'),
            _Linha(icone: Icons.location_on, label: 'Destino', valor: pedido['endereco_destino'] ?? '-'),
            const Divider(),
            _Linha(icone: Icons.shopping_bag, label: 'Produtos', valor: 'R\$ ${(pedido['valor_produto'] ?? 0).toStringAsFixed(2)}'),
            _Linha(icone: Icons.delivery_dining, label: 'Frete', valor: 'R\$ ${(pedido['valor_frete'] ?? 0).toStringAsFixed(2)}'),
            _Linha(icone: Icons.payments, label: 'Total a receber', valor: 'R\$ ${(pedido['valor_total'] ?? 0).toStringAsFixed(2)}', corDestaque: Colors.green[700]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets de Suporte (UI)
// ─────────────────────────────────────────────

class _Linha extends StatelessWidget {
  final IconData icone; final String label; final String valor; final Color? corDestaque;
  const _Linha({required this.icone, required this.label, required this.valor, this.corDestaque});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icone, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Expanded(child: Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: corDestaque ?? Colors.black87, fontSize: 14))),
      ]),
    );
  }
}

class _MetricaCard extends StatelessWidget {
  final String label; final String valor; final IconData icone; final Color cor;
  const _MetricaCard({required this.label, required this.valor, required this.icone, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cor.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: cor.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, color: cor, size: 18),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cor)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ]),
      ),
    );
  }
}

class _BotaoAcao extends StatelessWidget {
  final Color cor; final IconData icone; final String label; final VoidCallback onTap;
  const _BotaoAcao({required this.cor, required this.icone, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(2),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icone, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _WhatsappStatusCard extends StatelessWidget {
  final bool conectado; final VoidCallback onTap;
  const _WhatsappStatusCard({required this.conectado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = conectado ? const Color(0xFF25D366) : Colors.orange;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cor.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: cor.withOpacity(0.3))),
        child: Row(children: [
          Icon(Icons.chat, color: cor),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(conectado ? 'WhatsApp Conectado' : 'WhatsApp Desconectado', style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 13)),
            Text(conectado ? 'Bot de pedidos ativo' : 'Toque para conectar', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
          Icon(Icons.chevron_right, color: cor),
        ]),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final VoidCallback onNovoPedido;
  const _EstadoVazio({required this.onNovoPedido});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox, size: 70, color: Colors.grey[300]),
      const SizedBox(height: 10),
      const Text('Nenhuma entrega ativa no momento.', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: onNovoPedido, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white), child: const Text('CRIAR ENTREGA')),
    ]));
  }
}

// ─────────────────────────────────────────────
// Sheet de Edição (Mantido Completo)
// ─────────────────────────────────────────────

class _EditarPedidoSheet extends StatefulWidget {
  final Map<String, dynamic> pedido;
  const _EditarPedidoSheet({required this.pedido});
  @override State<_EditarPedidoSheet> createState() => _EditarPedidoSheetState();
}

class _EditarPedidoSheetState extends State<_EditarPedidoSheet> {
  late TextEditingController _nomeCtrl, _enderecoCtrl, _descCtrl, _valorCtrl;
  String _formaPagamento = 'DINHEIRO';
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.pedido['cliente_nome']);
    _enderecoCtrl = TextEditingController(text: widget.pedido['endereco_destino']);
    _descCtrl = TextEditingController(text: widget.pedido['descricao']);
    _valorCtrl = TextEditingController(text: (widget.pedido['valor_total'] ?? 0).toStringAsFixed(2));
    _formaPagamento = widget.pedido['forma_pagamento'] ?? 'DINHEIRO';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Editar Pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do Cliente', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _enderecoCtrl, decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _valorCtrl, decoration: const InputDecoration(labelText: 'Valor Total', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
            onPressed: _salvando ? null : () async {
              setState(() => _salvando = true);
              await Supabase.instance.client.from('pedidos').update({
                'cliente_nome': _nomeCtrl.text,
                'endereco_destino': _enderecoCtrl.text,
                'valor_total': double.tryParse(_valorCtrl.text) ?? 0,
              }).eq('id', widget.pedido['id']);
              Navigator.pop(context);
            },
            child: Text(_salvando ? 'SALVANDO...' : 'SALVAR'),
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}