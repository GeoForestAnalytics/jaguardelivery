import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MinhasEntregasPage extends StatefulWidget {
  @override
  _MinhasEntregasPageState createState() => _MinhasEntregasPageState();
}

class _MinhasEntregasPageState extends State<MinhasEntregasPage> {
  final _supabase = Supabase.instance.client;
  String _campoBusca = 'id_solicitante';
  String _tipoUsuario = 'CLIENTE';
  bool _isMotoboy = false;
  bool _loading = true;
  
  // Controle de Filtro
  String _filtroSelecionado = 'Hoje'; // Opções: 'Hoje', 'Semana', 'Mês', 'Todas'
  List<Map<String, dynamic>> _dadosExibidos = [];

  @override
  void initState() {
    super.initState();
    _definirTipoUsuario();
  }

  void _definirTipoUsuario() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final data = await _supabase.from('usuarios').select('tipo').eq('id', userId).maybeSingle();
    if (data != null && mounted) {
      final String tipo = data['tipo']?.toString().toUpperCase() ?? 'CLIENTE';
      setState(() {
        _tipoUsuario = tipo;
        _isMotoboy = tipo == 'MOTOBOY';
        _campoBusca = (tipo == 'COMERCIO') ? 'comercio_id' : (_isMotoboy ? 'id_motoboy' : 'id_solicitante');
        _loading = false;
      });
    }
  }

  // Lógica para filtrar a lista baseada no tempo
  List<Map<String, dynamic>> _aplicarFiltro(List<Map<String, dynamic>> docs) {
    final agora = DateTime.now();
    
    return docs.where((doc) {
      if (doc['data_finalizacao'] == null) return false;
      final dataPed = DateTime.parse(doc['data_finalizacao']);

      if (_filtroSelecionado == 'Hoje') {
        return dataPed.year == agora.year && dataPed.month == agora.month && dataPed.day == agora.day;
      } else if (_filtroSelecionado == 'Semana') {
        final seteDiasAtras = agora.subtract(Duration(days: 7));
        return dataPed.isAfter(seteDiasAtras);
      } else if (_filtroSelecionado == 'Mês') {
        return dataPed.year == agora.year && dataPed.month == agora.month;
      }
      return true; // 'Todas'
    }).toList();
  }

  Future<void> _exportarCSV() async {
    if (_dadosExibidos.isEmpty) return;
    final linhas = <String>['Data,Cliente,Endereco,Produto,V. Produto,V. Frete,Total,Motoboy,Placa,Status'];
    for (final d in _dadosExibidos) {
      final dataStr = d['data_finalizacao'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(d['data_finalizacao'])) : '---';
      linhas.add([
        dataStr,
        d['cliente_nome'] ?? '',
        (d['endereco_destino'] ?? '').toString().replaceAll(',', ';'),
        (d['descricao'] ?? '').toString().replaceAll(',', ';'),
        d['valor_produto'] ?? '0',
        d['valor_frete'] ?? '0',
        d['valor_total'] ?? d['valor'] ?? '0',
        d['motoboy_nome'] ?? '',
        d['motoboy_placa'] ?? '',
        d['status'] ?? ''
      ].join(','));
    }
    final file = File('${(await getTemporaryDirectory()).path}/relatorio_jaguar_${_filtroSelecionado.toLowerCase()}.csv');
    await file.writeAsString(linhas.join('\n'));
    await Share.shareXFiles([XFile(file.path)], subject: 'Relatório Jaguar - $_filtroSelecionado');
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;
    Color corTema = (_tipoUsuario == 'COMERCIO') ? const Color(0xFF6A1B9A) : (_isMotoboy ? Colors.green[800]! : Colors.blue[800]!);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_tipoUsuario == 'COMERCIO' ? "Histórico de Vendas" : "Meus Pedidos"),
        backgroundColor: corTema,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.file_download), onPressed: _exportarCSV)],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: userId != null
            ? _supabase.from(_tipoUsuario == 'COMERCIO' ? 'pedidos' : 'corridas').stream(primaryKey: ['id']).eq(_campoBusca, userId)
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          // Filtra primeiro por FINALIZADO e depois pelo tempo selecionado
          final todosFinalizados = snapshot.data!.where((c) => c['status'] == 'FINALIZADO').toList();
          final docs = _aplicarFiltro(todosFinalizados);
          
          // Guarda para o exportar CSV
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _dadosExibidos = docs;
          });

          double totalFaturado = 0;
          for (var d in docs) totalFaturado += (d['valor_total'] ?? d['valor'] ?? 0).toDouble();

          return Column(
            children: [
              // Barra de Filtros
              Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['Hoje', 'Semana', 'Mês', 'Todas'].map((filtro) {
                      bool selecionado = _filtroSelecionado == filtro;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filtro),
                          selected: selecionado,
                          onSelected: (val) => setState(() => _filtroSelecionado = filtro),
                          selectedColor: corTema.withOpacity(0.2),
                          labelStyle: TextStyle(color: selecionado ? corTema : Colors.grey[600], fontWeight: selecionado ? FontWeight.bold : FontWeight.normal),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _CardResumo(total: totalFaturado, qtd: docs.length, cor: corTema, periodo: _filtroSelecionado),
                    const SizedBox(height: 20),
                    Text("RESULTADOS: $_filtroSelecionado", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    if (docs.isEmpty) 
                      Center(child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text("Nenhuma venda neste período.", style: TextStyle(color: Colors.grey)),
                      ))
                    else
                      ...docs.reversed.map((data) => _ItemHistoricoClean(data: data)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardResumo extends StatelessWidget {
  final double total; final int qtd; final Color cor; final String periodo;
  const _CardResumo({required this.total, required this.qtd, required this.cor, required this.periodo});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: cor.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Total $periodo", style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text("R\$ ${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text("Vendas", style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text("$qtd", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }
}

class _ItemHistoricoClean extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ItemHistoricoClean({required this.data});

  @override
  Widget build(BuildContext context) {
    final dataFinal = data['data_finalizacao'] != null ? DateFormat('dd/MM HH:mm').format(DateTime.parse(data['data_finalizacao'])) : '---';
    final valorTotal = (data['valor_total'] ?? data['valor'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[300]!)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(data['cliente_nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text("$dataFinal • R\$ ${valorTotal.toStringAsFixed(2)}", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row("📍 Destino", data['endereco_destino'] ?? '---'),
                _row("📦 Produto", data['descricao'] ?? '---'),
                const Divider(),
                Row(
                  children: [
                    Expanded(child: _mini("Valor Produto", "R\$ ${data['valor_produto'] ?? '0.00'}")),
                    Expanded(child: _mini("Taxa Entrega", "R\$ ${data['valor_frete'] ?? '0.00'}")),
                  ],
                ),
                const Divider(),
                const Text("DADOS DO ENTREGADOR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                _row("🏍️ Motoboy", data['motoboy_nome'] ?? 'Não informado'),
                _row("🔢 Placa", data['motoboy_placa'] ?? '---'),
                _row("📞 Tel Motoboy", data['motoboy_tel'] ?? '---'),
                _row("📱 Tel Cliente", data['cliente_tel'] ?? '---'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _row(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 10),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _mini(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}