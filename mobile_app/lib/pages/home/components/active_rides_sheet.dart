import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
          Container(
            constraints: BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: idsCorridas.length,
              itemBuilder: (ctx, index) => _itemCorrida(context, idsCorridas[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCorrida(BuildContext context, String corridaId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('corridas')
          .select()
          .eq('id', corridaId)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();

        final data   = snapshot.data;
        if (data == null) return SizedBox();

        final String status  = data['status'] ?? 'ACEITO';
        final String destino = data['endereco_destino'] ?? 'Destino desconhecido';
        final String rua     = destino.split(',')[0];

        return Card(
          margin: EdgeInsets.only(bottom: 10),
          color: status == 'ACEITO' ? Colors.orange[50] : Colors.blue[50],
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'ACEITO' ? Colors.orange : Colors.blue,
              child: Icon(
                status == 'ACEITO' ? Icons.store : Icons.local_shipping,
                color: Colors.white,
              ),
            ),
            title: Text(rua, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(status == 'ACEITO' ? "Ir para Coleta" : "Ir para Entrega"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MonitoramentoPage(corridaId: corridaId, isMotoboy: true),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
