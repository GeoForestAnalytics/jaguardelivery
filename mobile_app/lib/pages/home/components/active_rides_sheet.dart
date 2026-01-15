import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../monitoramento_page.dart';

class ActiveRidesSheet extends StatelessWidget {
  final List<String> idsCorridas;

  const ActiveRidesSheet({required this.idsCorridas, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Minhas Entregas Ativas (${idsCorridas.length})", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 15),
          
          // Lista limitada para não ocupar a tela toda
          Container(
            constraints: BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: idsCorridas.length,
              itemBuilder: (ctx, index) {
                return _itemCorrida(context, idsCorridas[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCorrida(BuildContext context, String docId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('corridas').doc(docId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status'];
        String destino = data['endereco_destino'] ?? 'Destino desconhecido';
        // Pega só o nome da rua para ficar curto
        String rua = destino.split(',')[0];

        return Card(
          margin: EdgeInsets.only(bottom: 10),
          color: status == 'ACEITO' ? Colors.orange[50] : Colors.blue[50], // Laranja = Coletar, Azul = Entregar
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'ACEITO' ? Colors.orange : Colors.blue,
              child: Icon(status == 'ACEITO' ? Icons.store : Icons.local_shipping, color: Colors.white),
            ),
            title: Text(rua, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(status == 'ACEITO' ? "Ir para Coleta" : "Ir para Entrega"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Fecha a lista e abre o monitoramento DESSA corrida específica
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MonitoramentoPage(corridaId: docId, isMotoboy: true)
              ));
            },
          ),
        );
      },
    );
  }
}