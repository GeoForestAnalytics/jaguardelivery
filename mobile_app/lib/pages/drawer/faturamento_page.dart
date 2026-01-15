import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FaturamentoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text("Faturamento"), backgroundColor: Colors.green[800], foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('corridas')
            .where('id_motoboy', isEqualTo: user?.uid)
            .where('status', isEqualTo: 'FINALIZADO')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          
          double faturamentoTotal = 0;
          Map<String, double> lucroPorDia = {};
          
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            double valor = (data['valor'] ?? 0).toDouble();
            faturamentoTotal += valor;

            if (data['data_criacao'] != null) {
              DateTime dataC = (data['data_criacao'] as Timestamp).toDate();
              String dia = DateFormat('EEEE', 'pt_BR').format(dataC);
              lucroPorDia[dia] = (lucroPorDia[dia] ?? 0) + valor;
            }
          }

          // Dia mais lucrativo
          String diaMaisLucrativo = "N/A";
          double maiorLucro = 0;
          lucroPorDia.forEach((dia, lucro) {
            if (lucro > maiorLucro) {
              maiorLucro = lucro;
              diaMaisLucrativo = dia;
            }
          });

          // Calculo simples de "Meses de Assinatura" (Baseado na data de cadastro do user)
          // Isso exige buscar o usuário, vamos fazer um FutureBuilder aninhado ou simplificar
          // Vou colocar fixo ou buscar do user se quiser complexidade, vou deixar dinamico simples:
          
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).get(),
            builder: (context, userSnap) {
              String mesesApp = "Recém chegado";
              if (userSnap.hasData && userSnap.data!.exists) {
                 final userData = userSnap.data!.data() as Map<String, dynamic>;
                 if (userData['data_cadastro'] != null) {
                   DateTime cadastro = (userData['data_cadastro'] as Timestamp).toDate();
                   int dias = DateTime.now().difference(cadastro).inDays;
                   int meses = (dias / 30).floor();
                   mesesApp = meses < 1 ? "< 1 mês" : "$meses meses";
                 }
              }

              return ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // CARD GRANDE DE SALDO
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green.shade800, Colors.green.shade400]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 10, offset: Offset(0, 5))]
                    ),
                    child: Column(
                      children: [
                        Text("Faturamento Total", style: TextStyle(color: Colors.white70, fontSize: 16)),
                        SizedBox(height: 10),
                        Text("R\$ ${faturamentoTotal.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  _itemLinha("Tempo de Casa", mesesApp, Icons.history),
                  _itemLinha("Dia mais Lucrativo", diaMaisLucrativo.toUpperCase(), Icons.show_chart),
                  _itemLinha("Maior Lucro em um dia", "R\$ ${maiorLucro.toStringAsFixed(2)}", Icons.monetization_on),
                  
                  SizedBox(height: 20),
                  Text("Histórico Recente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  // Aqui poderia entrar uma lista das últimas corridas...
                ],
              );
            }
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