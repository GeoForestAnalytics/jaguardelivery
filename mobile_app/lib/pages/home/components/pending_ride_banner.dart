import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';

class PendingRideBanner extends StatelessWidget {
  final String? idSolicitacaoPendente;

  const PendingRideBanner({
    required this.idSolicitacaoPendente,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (idSolicitacaoPendente == null) return SizedBox();

    return Positioned(
      bottom: 0, 
      left: 0, 
      right: 0,
      child: Material(
        elevation: 15,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)), 
        color: Colors.white,
        child: Center( // Centraliza o conteúdo na Web
          child: Container(
            // AQUI ESTÁ A CORREÇÃO: Limita a largura no PC para não esticar
            constraints: BoxConstraints(maxWidth: 600), 
            padding: EdgeInsets.fromLTRB(20, 20, 20, 30), 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LINHA DA ANIMAÇÃO + TEXTO
                Row(
                  children: [
                    SizedBox(
                      height: 50, 
                      width: 50,
                      child: Lottie.asset('assets/waiting.json', fit: BoxFit.contain),
                    ),
                    
                    SizedBox(width: 15),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Procurando entregador...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                          Text("Aguarde o aceite", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: Colors.orange[50], 
                              color: Colors.orange
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // BOTÃO CANCELAR RESPONSIVO
                Center(
                  child: Container(
                    // Trava a largura do botão em 400px no PC. 
                    // No celular (que é menor que 400px), ele vai ocupar 100%.
                    constraints: BoxConstraints(maxWidth: 400), 
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50], 
                        foregroundColor: Colors.red[700], 
                        elevation: 0, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _confirmarCancelamento(context),
                      child: Text(
                        "CANCELAR PEDIDO", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarCancelamento(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Cancelar pedido?"),
        content: Text("Tem certeza que deseja cancelar a busca?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text("Não, esperar", style: TextStyle(color: Colors.grey[800]))
          ),
          TextButton(
            child: Text("Sim, cancelar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('corridas').doc(idSolicitacaoPendente).delete();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}