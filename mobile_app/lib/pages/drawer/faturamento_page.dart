import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class FaturamentoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final userId   = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text("Faturamento"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: userId == null
          ? Center(child: Text("Não autenticado"))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('corridas')
                  .stream(primaryKey: ['id'])
                  .eq('id_motoboy', userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!
                    .where((c) => c['status'] == 'FINALIZADO')
                    .toList();

                double faturamentoTotal = 0;
                Map<String, double> lucroPorDia = {};

                for (final data in docs) {
                  double valor = (data['valor'] ?? 0).toDouble();
                  faturamentoTotal += valor;

                  if (data['criado_em'] != null) {
                    DateTime dataC = DateTime.parse(data['criado_em']);
                    String dia = DateFormat('EEEE', 'pt_BR').format(dataC);
                    lucroPorDia[dia] = (lucroPorDia[dia] ?? 0) + valor;
                  }
                }

                String diaMaisLucrativo = "N/A";
                double maiorLucro = 0;
                lucroPorDia.forEach((dia, lucro) {
                  if (lucro > maiorLucro) {
                    maiorLucro = lucro;
                    diaMaisLucrativo = dia;
                  }
                });

                return FutureBuilder<Map<String, dynamic>?>(
                  future: supabase
                      .from('usuarios')
                      .select('data_cadastro')
                      .eq('id', userId)
                      .maybeSingle(),
                  builder: (context, userSnap) {
                    String mesesApp = "Recém chegado";
                    if (userSnap.hasData && userSnap.data != null) {
                      final cadastroRaw = userSnap.data!['data_cadastro'];
                      if (cadastroRaw != null) {
                        DateTime cadastro = DateTime.parse(cadastroRaw);
                        int dias  = DateTime.now().difference(cadastro).inDays;
                        int meses = (dias / 30).floor();
                        mesesApp = meses < 1 ? "< 1 mês" : "$meses meses";
                      }
                    }

                    return ListView(
                      padding: EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Colors.green.shade800, Colors.green.shade400]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: Offset(0, 5))
                            ],
                          ),
                          child: Column(
                            children: [
                              Text("Faturamento Total",
                                  style: TextStyle(color: Colors.white70, fontSize: 16)),
                              SizedBox(height: 10),
                              Text("R\$ ${faturamentoTotal.toStringAsFixed(2)}",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        _itemLinha("Tempo de Casa", mesesApp, Icons.history),
                        _itemLinha("Dia mais Lucrativo",
                            diaMaisLucrativo.toUpperCase(), Icons.show_chart),
                        _itemLinha("Maior Lucro em um dia",
                            "R\$ ${maiorLucro.toStringAsFixed(2)}", Icons.monetization_on),
                        SizedBox(height: 20),
                        Text("Histórico Recente",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _itemLinha(String titulo, String valor, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.green[800]),
        title: Text(titulo),
        trailing: Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
