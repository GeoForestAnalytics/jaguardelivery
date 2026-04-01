import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../drawer/perfil_page.dart';
import '../../drawer/minhas_entregas_page.dart';
import '../../drawer/historico_cliente_page.dart'; // <--- NOVA IMPORTAÇÃO
import '../../drawer/faturamento_page.dart';
import '../../admin/painel_ceo_page.dart';
import '../../comercio/painel_comercio_page.dart';

class HomeDrawer extends StatelessWidget {
  final bool souMotoboy;
  final Color corTema;

  const HomeDrawer({required this.souMotoboy, required this.corTema, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final userId   = supabase.auth.currentUser?.id;
    final email    = supabase.auth.currentUser?.email ?? "";

    return Drawer(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: userId != null
            ? supabase.from('usuarios').stream(primaryKey: ['id']).eq('id', userId)
            : const Stream.empty(),
        builder: (context, snapshot) {
          String nome          = "Carregando...";
          String tipoUsuario   = "CLIENTE";

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final data = snapshot.data!.first;
            nome        = data['nome'] ?? "Usuário";
            tipoUsuario = (data['tipo'] ?? "CLIENTE").toString().toUpperCase();
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
              
              // LÓGICA DE HISTÓRICO AJUSTADA
              _itemMenu(
                context,
                souMotoboy ? "Minhas Entregas" : "Meus Pedidos",
                Icons.history,
                tipoUsuario == 'CLIENTE' 
                    ? const HistoricoClientePage() // Perfil passageiro
                    : MinhasEntregasPage(),        // Perfil Comércio ou Motoboy
              ),

              if (souMotoboy)
                _itemMenu(context, "Faturamento", Icons.attach_money, FaturamentoPage(),
                    corIcone: Colors.green),

              if (tipoUsuario == 'COMERCIO') ...[
                Divider(),
                ListTile(
                  leading: Icon(Icons.store, color: Colors.purple[700]),
                  title: Text("Meu Painel",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[700])),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PainelComercioPage()));
                  },
                ),
              ],

              if (tipoUsuario == 'ADMIN') ...[
                Divider(color: Colors.black),
                ListTile(
                  tileColor: Colors.amber[100],
                  leading: Icon(Icons.security, color: Colors.black),
                  title: Text("Painel do CEO 👔",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
                  await supabase.auth.signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemMenu(BuildContext context, String titulo, IconData icone, Widget pagina,
      {Color? corIcone}) {
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