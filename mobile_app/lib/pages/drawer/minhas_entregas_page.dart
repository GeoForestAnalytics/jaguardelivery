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
  bool _isMotoboy    = false;
  bool _loading      = true;
  List<Map<String, dynamic>> _docs = [];

  @override
  void initState() {
    super.initState();
    _definirTipoUsuario();
  }

  Future<void> _exportarCSV() async {
    if (_docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum dado para exportar')));
      return;
    }
    final linhas = <String>['Data,Endereço,Valor (R\$),Status'];
    for (final d in _docs) {
      final dataStr = d['data_finalizacao'] != null
          ? DateFormat('dd/MM/yyyy HH:mm')
              .format(DateTime.parse(d['data_finalizacao']))
          : 'sem data';
      final endereco =
          (d['endereco_destino'] ?? '').toString().replaceAll(',', ';');
      final valor = (d['valor'] ?? 0).toStringAsFixed(2);
      final status = d['status'] ?? '';
      linhas.add('$dataStr,$endereco,$valor,$status');
    }
    final csv = linhas.join('\n');
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/historico_entregas.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Histórico de Entregas',
    );
  }

  void _definirTipoUsuario() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final data = await _supabase
        .from('usuarios')
        .select('tipo')
        .eq('id', userId)
        .maybeSingle();

    if (data != null && mounted) {
      final String tipo = data['tipo']?.toString().toUpperCase() ?? 'CLIENTE';
      setState(() {
        _isMotoboy  = tipo == 'MOTOBOY';
        _campoBusca = _isMotoboy ? 'id_motoboy' : 'id_solicitante';
        _loading    = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId   = _supabase.auth.currentUser?.id;
    Color corTema  = _isMotoboy ? Colors.green[800]! : Colors.blue[800]!;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text("Carregando...")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMotoboy ? "Minhas Entregas" : "Meus Pedidos"),
        backgroundColor: corTema,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar CSV',
            onPressed: _exportarCSV,
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: userId != null
            ? _supabase
                .from('corridas')
                .stream(primaryKey: ['id'])
                .eq(_campoBusca, userId)
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          // Filtra apenas as finalizadas
          final docs = snapshot.data!
              .where((c) => c['status'] == 'FINALIZADO')
              .toList();

          // Mantém referência para exportação CSV
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _docs.length != docs.length) {
              setState(() => _docs = docs);
            }
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[300]),
                  Text("Nenhum histórico encontrado."),
                ],
              ),
            );
          }

          int totalPedidos = docs.length;
          double valorTotal = 0;
          Duration tempoTotalAcumulado = Duration.zero;
          int corridasComTempo = 0;

          for (final data in docs) {
            valorTotal += (data['valor'] ?? 0).toDouble();

            if (data['data_aceite'] != null && data['data_finalizacao'] != null) {
              final inicio = DateTime.parse(data['data_aceite']);
              final fim    = DateTime.parse(data['data_finalizacao']);
              if (fim.isAfter(inicio)) {
                tempoTotalAcumulado += fim.difference(inicio);
                corridasComTempo++;
              }
            }
          }

          double ticketMedio    = totalPedidos > 0 ? valorTotal / totalPedidos : 0;
          int tempoMedioMinutos = corridasComTempo > 0
              ? (tempoTotalAcumulado.inMinutes / corridasComTempo).round()
              : 0;

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              _cardGrande(
                icon: Icons.timer,
                titulo: "Tempo Médio de Entrega",
                valor: "$tempoMedioMinutos min",
                cor: Colors.orange[800]!,
              ),
              SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _cardPequeno("Total Pedidos", "$totalPedidos", Icons.list_alt, Colors.blue)),
                  SizedBox(width: 10),
                  Expanded(child: _cardPequeno("Valor Total", "R\$ ${valorTotal.toStringAsFixed(2)}", Icons.monetization_on, Colors.green)),
                ],
              ),
              SizedBox(height: 10),
              _cardLinha("Média por Pedido", "R\$ ${ticketMedio.toStringAsFixed(2)}", Icons.analytics),
              SizedBox(height: 20),
              Text("Histórico Recente",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey[800])),
              SizedBox(height: 10),
              ...docs.reversed.take(10).map((data) {
                final String destino    = data['endereco_destino'] ?? 'Destino não informado';
                final String ruaDestino = destino.split(',')[0];
                final DateTime? dataFinal = data['data_finalizacao'] != null
                    ? DateTime.parse(data['data_finalizacao'])
                    : null;
                final String dataFormatada = dataFinal != null
                    ? DateFormat('dd/MM - HH:mm').format(dataFinal)
                    : 'Data desc.';

                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Icon(
                          _isMotoboy ? Icons.person : Icons.two_wheeler,
                          color: Colors.grey[700]),
                    ),
                    title: Text(ruaDestino, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(dataFormatada),
                    trailing: Text(
                      "R\$ ${(data['valor'] ?? 0).toStringAsFixed(2)}",
                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _cardGrande({required IconData icon, required String titulo, required String valor, required Color cor}) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: cor, size: 32),
          ),
          SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardPequeno(String titulo, String valor, IconData icon, Color cor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cor),
          SizedBox(height: 8),
          Text(titulo, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _cardLinha(String titulo, String valor, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            SizedBox(width: 8),
            Text(titulo, style: TextStyle(color: Colors.grey[700])),
          ]),
          Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}
