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
                    child: Text('Erro ao carregar pedidos.\n${snapshot.error}',
                        textAlign: TextAlign.center),
                  );
                }

                final pedidos = snapshot.data ?? [];

                final perfil = ref.watch(userProfileProvider).valueOrNull;
                final whatsConnected = perfil?['whatsapp_conectado'] == true;

                return Column(
                  children: [
                    _ResumoBar(pedidos: pedidos),
                    _WhatsappStatusCard(
                      conectado: whatsConnected,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const WhatsappConectarPage())),
                    ),
                    Expanded(
                      child: pedidos.isEmpty
                          ? _EstadoVazio(onNovoPedido: _abrirNovoPedido)
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: pedidos.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) =>
                                  _CardPedidoSlidable(pedido: pedidos[i]),
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
// Widgets internos
// ─────────────────────────────────────────────

class _WhatsappStatusCard extends StatelessWidget {
  final bool conectado;
  final VoidCallback onTap;
  const _WhatsappStatusCard({required this.conectado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = conectado ? const Color(0xFF25D366) : Colors.orange;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.chat, color: cor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conectado ? 'WhatsApp Conectado' : 'WhatsApp não conectado',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cor, fontSize: 13),
                  ),
                  Text(
                    conectado
                        ? 'Clientes podem pedir pelo WhatsApp'
                        : 'Toque para conectar e receber pedidos via WhatsApp',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cor),
          ],
        ),
      ),
    );
  }
}

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

    final pendentes   = pedidos.where((p) => p['status'] == 'PENDENTE').length;
    final valorHoje   = pedidosHoje.fold<double>(
        0, (sum, p) => sum + (p['valor_total'] ?? 0).toDouble());

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _MetricaCard(
              label: 'Hoje', valor: '${pedidosHoje.length}', icone: Icons.today,
              cor: Colors.blue),
          const SizedBox(width: 8),
          _MetricaCard(
              label: 'Pendentes', valor: '$pendentes', icone: Icons.access_time,
              cor: Colors.orange),
          const SizedBox(width: 8),
          _MetricaCard(
              label: 'Faturado hoje',
              valor: 'R\$ ${valorHoje.toStringAsFixed(2)}',
              icone: Icons.attach_money,
              cor: Colors.green),
        ],
      ),
    );
  }
}

class _MetricaCard extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icone;
  final Color cor;
  const _MetricaCard(
      {required this.label,
      required this.valor,
      required this.icone,
      required this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor, size: 18),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cor)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final VoidCallback onNovoPedido;
  const _EstadoVazio({required this.onNovoPedido});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Nenhuma entrega ainda.',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text('Crie sua primeira entrega!',
              style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.add_box),
            label: const Text('CRIAR ENTREGA'),
            onPressed: onNovoPedido,
          ),
        ],
      ),
    );
  }
}

// ── Slidable (arrasta para revelar Editar / Cancelar) ─────────

class _CardPedidoSlidable extends StatefulWidget {
  final Map<String, dynamic> pedido;
  const _CardPedidoSlidable({required this.pedido});

  @override
  State<_CardPedidoSlidable> createState() => _CardPedidoSlidableState();
}

class _CardPedidoSlidableState extends State<_CardPedidoSlidable> {
  static const _actionWidth = 130.0;
  double _offset = 0;

  bool get _isPendente =>
      (widget.pedido['status'] ?? 'PENDENTE') == 'PENDENTE';
  bool get _isAtivo =>
      ['ACEITO', 'EM_VIAGEM'].contains(widget.pedido['status'] ?? '');
  bool get _isFinalizado =>
      ['FINALIZADO', 'CANCELADO'].contains(widget.pedido['status'] ?? '');
  bool get _temSwipe => _isPendente || _isAtivo || _isFinalizado;

  void _fechar() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _temSwipe
          ? (d) => setState(
              () => _offset = (_offset + d.delta.dx).clamp(-_actionWidth, 0))
          : null,
      onHorizontalDragEnd: _temSwipe
          ? (d) => setState(() =>
              _offset = _offset < -_actionWidth / 2 ? -_actionWidth : 0)
          : null,
      child: Stack(
        children: [
          // Botões de ação revelados atrás do card
          if (_temSwipe)
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isPendente) ...[
                    _BotaoAcao(
                      cor: Colors.blue[700]!,
                      icone: Icons.edit,
                      label: 'Editar',
                      onTap: () {
                        _fechar();
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (context.mounted) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20))),
                              builder: (_) =>
                                  _EditarPedidoSheet(pedido: widget.pedido),
                            );
                          }
                        });
                      },
                    ),
                    _BotaoAcao(
                      cor: Colors.red[700]!,
                      icone: Icons.cancel,
                      label: 'Cancelar',
                      onTap: () {
                        _fechar();
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (context.mounted) _confirmarCancelamento(context);
                        });
                      },
                    ),
                  ],
                  if (_isAtivo)
                    _BotaoAcao(
                      cor: Colors.indigo,
                      icone: Icons.my_location,
                      label: 'Rastrear',
                      onTap: () {
                        _fechar();
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RastreioEntregaPage(
                                  pedidoId: widget.pedido['id'] as String,
                                  clienteNome:
                                      widget.pedido['cliente_nome'] ?? 'Cliente',
                                ),
                              ),
                            );
                          }
                        });
                      },
                    ),
                  if (_isFinalizado)
                    _BotaoAcao(
                      cor: Colors.grey[700]!,
                      icone: Icons.delete_outline,
                      label: 'Excluir',
                      onTap: () {
                        _fechar();
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (context.mounted) _confirmarExclusao(context);
                        });
                      },
                    ),
                ],
              ),
            ),

          // Card que desliza
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido?'),
        content: const Text(
            'O pedido será cancelado e removido da fila de motoboys.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client
                  .from('pedidos')
                  .update({'status': 'CANCELADO'})
                  .eq('id', widget.pedido['id']);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Cancelar pedido',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusao(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir pedido?'),
        content: const Text('Este pedido será removido permanentemente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Não')),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client
                  .from('pedidos')
                  .delete()
                  .eq('id', widget.pedido['id']);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Excluir',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _BotaoAcao extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final String label;
  final VoidCallback onTap;
  const _BotaoAcao(
      {required this.cor,
      required this.icone,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ── Sheet de edição ───────────────────────────────────────────

class _EditarPedidoSheet extends StatefulWidget {
  final Map<String, dynamic> pedido;
  const _EditarPedidoSheet({required this.pedido});

  @override
  State<_EditarPedidoSheet> createState() => _EditarPedidoSheetState();
}

class _EditarPedidoSheetState extends State<_EditarPedidoSheet> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _enderecoCtrl;
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _valorCtrl;
  late String _formaPagamento;
  bool _salvando = false;

  static const _corTema = Color(0xFF6A1B9A);

  @override
  void initState() {
    super.initState();
    _nomeCtrl     = TextEditingController(text: widget.pedido['cliente_nome'] ?? '');
    _enderecoCtrl = TextEditingController(text: widget.pedido['endereco_destino'] ?? '');
    _descricaoCtrl= TextEditingController(text: widget.pedido['descricao'] ?? '');
    _valorCtrl    = TextEditingController(
        text: (widget.pedido['valor_total'] ?? 0).toStringAsFixed(2));
    _formaPagamento = widget.pedido['forma_pagamento'] ?? 'DINHEIRO';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _enderecoCtrl.dispose();
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Editar Pedido',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            _campo(_nomeCtrl,     'Nome do cliente',    Icons.person_outline),
            const SizedBox(height: 12),
            _campo(_enderecoCtrl, 'Endereço de entrega',Icons.location_on_outlined),
            const SizedBox(height: 12),
            _campo(_descricaoCtrl,'Descrição do pedido', Icons.description_outlined, maxLines: 2),
            const SizedBox(height: 12),
            _campo(_valorCtrl,    'Valor total (R\$)',   Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _formaPagamento,
              decoration: InputDecoration(
                labelText: 'Forma de pagamento',
                prefixIcon: const Icon(Icons.payment, color: _corTema),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              items: ['DINHEIRO', 'CARTÃO', 'PIX']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _formaPagamento = v!),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corTema,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _salvando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_salvando ? 'Salvando...' : 'SALVAR ALTERAÇÕES',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _salvando ? null : _salvar,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icone,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone, color: _corTema),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
    );
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final valor = double.tryParse(
            _valorCtrl.text.trim().replaceAll(',', '.')) ??
        0;
    try {
      await Supabase.instance.client.from('pedidos').update({
        'cliente_nome':     _nomeCtrl.text.trim(),
        'endereco_destino': _enderecoCtrl.text.trim(),
        'descricao':        _descricaoCtrl.text.trim(),
        'valor_total':      valor,
        'forma_pagamento':  _formaPagamento,
      }).eq('id', widget.pedido['id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pedido atualizado!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}

class _CardPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _CardPedido({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final String status      = pedido['status'] ?? 'PENDENTE';
    final String cliente     = pedido['cliente_nome'] ?? 'Cliente';
    final String destino     = pedido['endereco_destino'] ?? 'Endereço não informado';
    final double valor       = (pedido['valor_total'] ?? 0).toDouble();
    final String? criadoRaw  = pedido['criado_em'];
    final String dataHora    = criadoRaw != null
        ? DateFormat('dd/MM HH:mm').format(DateTime.parse(criadoRaw))
        : '';

    final (Color cor, IconData icone) = switch (status) {
      'ACEITO'     => (Colors.blue, Icons.two_wheeler),
      'EM_VIAGEM'  => (Colors.indigo, Icons.local_shipping),
      'FINALIZADO' => (Colors.green, Icons.check_circle),
      'CANCELADO'  => (Colors.red, Icons.cancel),
      _            => (Colors.orange, Icons.access_time), // PENDENTE
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.15),
          child: Icon(icone, color: cor),
        ),
        title: Text(cliente,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(destino,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 10,
                          color: cor,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(dataHora,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
        trailing: Text(
          'R\$ ${valor.toStringAsFixed(2)}',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
              fontSize: 15),
        ),
        onTap: () => _mostrarDetalhes(context),
      ),
    );
  }

  void _mostrarDetalhes(BuildContext context) {
    final String status   = pedido['status'] ?? 'PENDENTE';
    final String cliente  = pedido['cliente_nome'] ?? '-';
    final String tel      = pedido['cliente_tel'] ?? '-';
    final String destino  = pedido['endereco_destino'] ?? '-';
    final String descricao = pedido['descricao'] ?? '-';
    final double valor    = (pedido['valor_total'] ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalhes do Pedido',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            _Linha(icone: Icons.person, label: 'Cliente', valor: cliente),
            _Linha(icone: Icons.phone, label: 'Telefone', valor: tel),
            _Linha(icone: Icons.location_on, label: 'Destino', valor: destino),
            _Linha(icone: Icons.description, label: 'Descrição', valor: descricao),
            _Linha(
              icone: Icons.attach_money,
              label: 'Valor',
              valor: 'R\$ ${valor.toStringAsFixed(2)}',
            ),
            _Linha(icone: Icons.info_outline, label: 'Status', valor: status),
          ],
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valor;
  const _Linha({required this.icone, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(valor,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
