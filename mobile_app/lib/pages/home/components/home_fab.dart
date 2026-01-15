import 'package:flutter/material.dart';

class HomeFab extends StatelessWidget {
  final bool souMotoboyTrabalhando;
  final bool temLocalizacao;
  final VoidCallback onNovoPedido;
  final VoidCallback onCentralizar;

  const HomeFab({
    required this.souMotoboyTrabalhando,
    required this.temLocalizacao,
    required this.onNovoPedido,
    required this.onCentralizar,
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!temLocalizacao) return SizedBox(); // Se não tem GPS, não mostra nada ainda

    if (souMotoboyTrabalhando) {
      // Botão pequeno só para centralizar (Motoboy)
      return FloatingActionButton(
        onPressed: onCentralizar,
        child: Icon(Icons.my_location, color: Colors.blue[800]),
        backgroundColor: Colors.white,
      );
    } else {
      // Botão grande para Pedir (Cliente) ou Motoboy Offline
      return FloatingActionButton.extended(
        onPressed: onNovoPedido,
        label: Text("NOVO PEDIDO"),
        icon: Icon(Icons.add_shopping_cart),
        backgroundColor: const Color.fromARGB(235, 255, 209, 149),
      );
    }
  }
}