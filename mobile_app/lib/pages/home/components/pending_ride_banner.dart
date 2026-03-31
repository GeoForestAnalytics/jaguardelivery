import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingRideBanner extends StatelessWidget {
  final String? idSolicitacaoPendente;
  final VoidCallback? onCancelado;

  const PendingRideBanner({
    required this.idSolicitacaoPendente,
    this.onCancelado,
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
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 600),
            padding: EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          Text("Procurando entregador...",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                          Text("Aguarde o aceite", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: Colors.orange[50],
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Center(
                  child: Container(
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
                      child: Text("CANCELAR PEDIDO",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ),
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
            child: Text("Não, esperar", style: TextStyle(color: Colors.grey[800])),
          ),
          TextButton(
            child: Text("Sim, cancelar",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client
                    .from('corridas')
                    .update({'status': 'CANCELADO'})
                    .eq('id', idSolicitacaoPendente!)
                    .eq('status', 'PENDENTE');
                onCancelado?.call();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erro ao cancelar: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
