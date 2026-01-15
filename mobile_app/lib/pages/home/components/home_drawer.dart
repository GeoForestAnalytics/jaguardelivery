import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Imports das páginas de destino
import '../../drawer/perfil_page.dart';
import '../../drawer/minhas_entregas_page.dart';
import '../../drawer/faturamento_page.dart';
import '../../admin/painel_ceo_page.dart';
// import '../auth/login_page.dart'; // Se precisar redirecionar manualmente

class HomeDrawer extends StatelessWidget {
  final bool souMotoboy;
  final Color corTema;

  const HomeDrawer({
    required this.souMotoboy, 
    required this.corTema, 
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: user != null 
            ? FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots()
            : null,
        builder: (context, snapshot) {
          String nome = "Carregando...";
          String email = user?.email ?? "";
          String tipoUsuario = "";
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            nome = data['nome'] ?? "Usuário";
            tipoUsuario = data['tipo'] ?? "CLIENTE";
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: corTema),
                accountName: Text(nome, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                accountEmail: Text(email),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(souMotoboy ? Icons.two_wheeler : Icons.person, size: 40, color: corTema),
                ),
              ),
              
              _itemMenu(context, "Meu Perfil", Icons.person_outline, PerfilPage()),
              _itemMenu(context, souMotoboy ? "Minhas Entregas" : "Meus Pedidos", Icons.history, MinhasEntregasPage()),
              
              if (souMotoboy)
                _itemMenu(context, "Faturamento", Icons.attach_money, FaturamentoPage(), corIcone: Colors.green),

              if (tipoUsuario == 'ADMIN') ...[
                 Divider(color: Colors.black),
                 ListTile(
                   tileColor: Colors.amber[100],
                   leading: Icon(Icons.security, color: Colors.black),
                   title: Text("Painel do CEO 👔", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                   onTap: () {
                     Navigator.pop(context);
                     Navigator.push(context, MaterialPageRoute(builder: (_) => PainelCeoPage()));
                   },
                 ),
                 Divider(color: Colors.black),
              ],

              Divider(),

              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text("Sair do App", style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemMenu(BuildContext context, String titulo, IconData icone, Widget pagina, {Color? corIcone}) {
    return ListTile(
      leading: Icon(icone, color: corIcone ?? Colors.grey[700]),
      title: Text(titulo),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));
      },
    );
  }
}