import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/home/monitoramento_entregas_page.dart';

class LoteEntregasSheet extends StatefulWidget {
  final List<Map<String, dynamic>> pedidos;

  const LoteEntregasSheet({required this.pedidos, super.key});

  @override
  State<LoteEntregasSheet> createState() => _LoteEntregasSheetState();
}

class _LoteEntregasSheetState extends State<LoteEntregasSheet> {
  final _supabase = Supabase.instance.client;
  final Set<String> _selecionados = {};
  bool _aceitando = false;

  double get _totalSelecionado => widget.pedidos
      .where((p) => _selecionados.contains(p['id']))
      .fold(0.0, (sum, p) => sum + (p['valor_total'] ?? 0).toDouble());

  @override
  void initState() {
    super.initState();
    // Seleciona todos por padrão
    for (final p in widget.pedidos) {
      _selecionados.add(p['id'] as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nomeComercio = widget.pedidos.first['comercio_nome'] as String? ?? 'Comerciante';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.store, color: Colors.orange[800], size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomeComercio,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${widget.pedidos.length} entregas disponíveis',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),

          // Lista de pedidos com checkbox
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.pedidos.length,
              itemBuilder: (context, i) {
                final pedido = widget.pedidos[i];
                final id     = pedido['id'] as String;
                final selecionado = _selecionados.contains(id);
                final valor  = (pedido['valor_total'] ?? 0).toDouble();

                return CheckboxListTile(
                  value: selecionado,
                  onChanged: (val) => setState(() {
                    val == true ? _selecionados.add(id) : _selecionados.remove(id);
                  }),
                  activeColor: Colors.green[700],
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    pedido['cliente_nome'] ?? 'Cliente',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    pedido['endereco_destino'] ?? 'Endereço não informado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  secondary: Text(
                    'R\$ ${valor.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                        fontSize: 15),
                  ),
                );
              },
            ),
          ),

          const Divider(),
          const SizedBox(height: 8),

          // Resumo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_selecionados.length} selecionada(s)',
                  style: TextStyle(color: Colors.grey[600])),
              Text(
                'Total: R\$ ${_totalSelecionado.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[800]),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Botão aceitar
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selecionados.isEmpty ? Colors.grey : Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _aceitando
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(
                _aceitando
                    ? 'Aceitando...'
                    : 'ACEITAR ${_selecionados.length} ENTREGA(S)',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: _selecionados.isEmpty || _aceitando ? null : _aceitar,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _aceitar() async {
    if (_aceitando) return;
    setState(() => _aceitando = true);
    
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. BUSCA O PERFIL
      final res = await _supabase
          .from('usuarios')
          .select('nome, telefone, moto_placa')
          .eq('id', user.id)
          .single();

      final String nome   = res['nome'] ?? 'Sem Nome';
      final String tel    = res['telefone'] ?? '---';
      final String placa  = res['moto_placa'] ?? '---';

      // AVISO DE DEBUG: Vai aparecer na tela do seu celular o nome que ele achou
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gravando aceite para: $nome'), backgroundColor: Colors.blue)
      );

      // 2. ATUALIZA OS PEDIDOS
      final listaIds = _selecionados.toList();
      await _supabase.from('pedidos').update({
        'status':        'ACEITO',
        'motoboy_id':    user.id,
        'motoboy_nome':  nome,
        'motoboy_tel':   tel,
        'motoboy_placa': placa,
      }).inFilter('id', listaIds);

      // 3. SEGUE PARA O MONITORAMENTO
      final pedidosAceitos = widget.pedidos
          .where((p) => _selecionados.contains(p['id']))
          .toList();

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MonitoramentoEntregasPage(pedidos: pedidosAceitos),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ERRO CRÍTICO: $e'),
          backgroundColor: Colors.red,
        ));
        setState(() => _aceitando = false);
      }
    }
  }
}
