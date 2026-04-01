import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- IMPORTAÇÃO ADICIONADA

class HistoricoClientePage extends StatefulWidget {
  const HistoricoClientePage({super.key});

  @override
  _HistoricoClientePageState createState() => _HistoricoClientePageState();
}

class _HistoricoClientePageState extends State<HistoricoClientePage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _corridas = [];

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _supabase
          .from('corridas')
          .select()
          .eq('id_solicitante', userId)
          .eq('status', 'FINALIZADO')
          .order('data_finalizacao', ascending: false);

      setState(() {
        _corridas = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalGasto = _corridas.fold(0, (sum, item) => sum + (item['valor'] ?? 0).toDouble());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Minhas Viagens"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Resumo de Gastos
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue[800],
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      const Text("Total Gasto em Corridas", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text("R\$ ${totalGasto.toStringAsFixed(2)}", 
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("${_corridas.length} viagens realizadas", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18, color: Colors.grey),
                      SizedBox(width: 8),
                      Text("HISTÓRICO RECENTE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),

                Expanded(
                  child: _corridas.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _corridas.length,
                          itemBuilder: (context, i) => _CardViagem(viagem: _corridas[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bike, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Você ainda não fez viagens.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _CardViagem extends StatelessWidget {
  final Map<String, dynamic> viagem;
  const _CardViagem({required this.viagem});

  @override
  Widget build(BuildContext context) {
    final data = viagem['data_finalizacao'] != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(viagem['data_finalizacao']))
        : 'Data não disponível';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
          child: Icon(Icons.navigation, color: Colors.blue[800], size: 20),
        ),
        title: Text("R\$ ${(viagem['valor'] ?? 0).toStringAsFixed(2)}", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(data, style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detalhe(Icons.circle, "Origem", viagem['endereco_origem'] ?? 'GPS'),
                const SizedBox(height: 8),
                _detalhe(Icons.location_on, "Destino", viagem['endereco_destino'] ?? '---'),
                const Divider(height: 24),
                const Text("QUEM TE LEVOU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.grey[200], child: const Icon(Icons.person, color: Colors.grey)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(viagem['motoboy_nome'] ?? 'Motoboy Parceiro', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Placa: ${viagem['motoboy_placa'] ?? '---'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _ligar(viagem['motoboy_tel']),
                      icon: const Icon(Icons.phone_in_talk, color: Colors.green),
                    )
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _detalhe(IconData icone, String label, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 14, color: icone == Icons.circle ? Colors.grey : Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text("$label: $texto", style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  void _ligar(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    final Uri uri = Uri.parse("tel:$tel");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}