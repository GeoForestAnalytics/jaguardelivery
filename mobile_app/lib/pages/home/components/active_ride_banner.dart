import 'package:flutter/material.dart';
import '../monitoramento_page.dart';
import 'active_rides_sheet.dart'; // <--- Import novo

class ActiveRideBanner extends StatelessWidget {
  final List<String> idsCorridasAtivas; // <--- Mudou de String? para List<String>
  final bool souMotoboy;

  const ActiveRideBanner({
    required this.idsCorridasAtivas,
    required this.souMotoboy,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (idsCorridasAtivas.isEmpty) return SizedBox();

    int qtd = idsCorridasAtivas.length;
    bool multiplas = qtd > 1;

    return Positioned(
      top: 10, left: 16, right: 16,
      child: GestureDetector(
        onTap: () {
          if (multiplas) {
            // Abre a lista para escolher
            showModalBottomSheet(
              context: context,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => ActiveRidesSheet(idsCorridas: idsCorridasAtivas)
            );
          } else {
            // Abre direto a única que tem
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => MonitoramentoPage(corridaId: idsCorridasAtivas.first, isMotoboy: souMotoboy)
            ));
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: multiplas ? Colors.blue[800] : Colors.green[600], // Azul se for lista, Verde se for única
            borderRadius: BorderRadius.circular(30), 
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(multiplas ? Icons.format_list_bulleted : Icons.navigation, color: Colors.white),
              SizedBox(width: 8),
              Text(
                multiplas ? "$qtd ENTREGAS EM ANDAMENTO" : "VOLTAR PARA CORRIDA ATUAL", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
      ),
    );
  }
}