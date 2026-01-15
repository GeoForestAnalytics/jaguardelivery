import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MinhasEntregasPage extends StatefulWidget {
  @override
  _MinhasEntregasPageState createState() => _MinhasEntregasPageState();
}

class _MinhasEntregasPageState extends State<MinhasEntregasPage> {
  String _campoBusca = 'id_solicitante'; // Padrão Cliente
  bool _isMotoboy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _definirTipoUsuario();
  }

  void _definirTipoUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        String tipo = data['tipo']?.toString().toUpperCase() ?? 'CLIENTE';
        
        setState(() {
          _isMotoboy = (tipo == 'MOTOBOY');
          // Se for motoboy busca pelo ID dele na entrega, se for cliente busca pelo solicitante
          _campoBusca = _isMotoboy ? 'id_motoboy' : 'id_solicitante';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    Color corTema = _isMotoboy ? Colors.green[800]! : Colors.blue[800]!;

    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text("Carregando...")), body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMotoboy ? "Minhas Entregas" : "Meus Pedidos"), 
        backgroundColor: corTema, 
        foregroundColor: Colors.white
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('corridas')
            .where(_campoBusca, isEqualTo: user?.uid) // Busca dinâmica
            .where('status', isEqualTo: 'FINALIZADO')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          
          if (docs.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey[300]),
                Text("Nenhum histórico encontrado."),
              ],
            ));
          }
          
          // --- CÁLCULOS ---
          int totalPedidos = docs.length;
          double valorTotal = 0;
          Duration tempoTotalAcumulado = Duration.zero;
          int corridasComTempoCalculado = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            valorTotal += (data['valor'] ?? 0).toDouble();

            // CÁLCULO DE TEMPO (Eficiência)
            // Calculamos do momento que o motoboy ACEITOU até FINALIZAR
            if (data['data_aceite'] != null && data['data_finalizacao'] != null) {
              DateTime inicio = (data['data_aceite'] as Timestamp).toDate();
              DateTime fim = (data['data_finalizacao'] as Timestamp).toDate();
              
              // Evita datas inconsistentes (negativas)
              if (fim.isAfter(inicio)) {
                tempoTotalAcumulado += fim.difference(inicio);
                corridasComTempoCalculado++;
              }
            }
          }

          // Médias
          double ticketMedio = totalPedidos > 0 ? valorTotal / totalPedidos : 0;
          
          int tempoMedioMinutos = 0;
          if (corridasComTempoCalculado > 0) {
            tempoMedioMinutos = (tempoTotalAcumulado.inMinutes / corridasComTempoCalculado).round();
          }

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // 1. CARD DE TEMPO (Destaque para o Cliente ver eficiência)
              _cardGrande(
                icon: Icons.timer, 
                titulo: "Tempo Médio de Entrega", 
                valor: "$tempoMedioMinutos min", 
                cor: Colors.orange[800]!
              ),

              SizedBox(height: 15),

              Row(
                children: [
                  Expanded(child: _cardPequeno("Total Pedidos", "$totalPedidos", Icons.list_alt, Colors.blue)),
                  SizedBox(width: 10),
                  // Para o cliente mostra "Total Investido/Movimentado"
                  Expanded(child: _cardPequeno("Valor Total", "R\$ ${valorTotal.toStringAsFixed(2)}", Icons.monetization_on, Colors.green)),
                ],
              ),
              
              SizedBox(height: 10),
              
              _cardLinha("Média por Pedido", "R\$ ${ticketMedio.toStringAsFixed(2)}", Icons.analytics),

              SizedBox(height: 20),
              Text("Histórico Recente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey[800])),
              SizedBox(height: 10),

              // LISTA DAS ÚLTIMAS CORRIDAS
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String destino = data['endereco_destino'] ?? 'Destino não informado';
                // Pega só o nome da rua para não poluir
                String ruaDestino = destino.split(',')[0]; 
                
                DateTime? dataFinal = data['data_finalizacao'] != null 
                    ? (data['data_finalizacao'] as Timestamp).toDate() 
                    : null;
                
                String dataFormatada = dataFinal != null 
                    ? DateFormat('dd/MM - HH:mm').format(dataFinal)
                    : 'Data desc.';

                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Icon(_isMotoboy ? Icons.person : Icons.two_wheeler, color: Colors.grey[700]),
                    ),
                    title: Text(ruaDestino, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(dataFormatada),
                    trailing: Text(
                      "R\$ ${(data['valor'] ?? 0).toStringAsFixed(2)}", 
                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)
                    ),
                  ),
                );
              }).toList().reversed.take(10), // Mostra só as últimas 10
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: cor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: cor, size: 32),
          ),
          SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: Colors.black87)),
            ],
          )
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
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text(titulo, style: TextStyle(color: Colors.grey[700])),
            ],
          ),
          Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}