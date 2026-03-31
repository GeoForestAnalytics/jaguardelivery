import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PainelCeoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: Text("Painel do CEO 👔"),
        centerTitle: true,
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 1200),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('usuarios')
                .stream(primaryKey: ['id'])
                .eq('tipo', 'MOTOBOY')
                .order('nome'),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
                        SizedBox(height: 15),
                        Text("Erro ao carregar",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        SelectableText(snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final motoboys = snapshot.data ?? [];

              if (motoboys.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.two_wheeler, size: 80, color: Colors.grey[300]),
                      SizedBox(height: 10),
                      Text("Nenhum motoboy cadastrado.",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    return GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: motoboys.length,
                      itemBuilder: (context, index) =>
                          _buildCard(context, motoboys[index]),
                    );
                  } else {
                    return ListView.builder(
                      padding: EdgeInsets.all(10),
                      itemCount: motoboys.length,
                      itemBuilder: (context, index) =>
                          _buildCard(context, motoboys[index]),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data) {
    DateTime? validade;
    if (data['validade_assinatura'] != null) {
      validade = DateTime.parse(data['validade_assinatura']);
    }

    bool estaVencido = validade == null || DateTime.now().isAfter(validade);

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      color: estaVencido ? Colors.red[50] : Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: estaVencido
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.green.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _mostrarOpcoesRenovacao(
            context, data['id'].toString(), data['nome'] ?? 'Sem Nome', validade),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
            leading: CircleAvatar(
              backgroundColor: estaVencido ? Colors.red[700] : Colors.green[700],
              child: Icon(Icons.two_wheeler, color: Colors.white),
            ),
            title: Text(data['nome'] ?? 'Sem Nome',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data['email'] ?? 'Sem email',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: estaVencido ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      estaVencido
                          ? "⛔ BLOQUEADO / VENCIDO"
                          : "✅ Vence: ${validade != null ? DateFormat('dd/MM/yyyy').format(validade) : 'N/A'}",
                      style: TextStyle(
                        color: estaVencido ? Colors.red[900] : Colors.green[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Icon(Icons.more_vert, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  void _mostrarOpcoesRenovacao(BuildContext context, String uid, String nome,
      DateTime? validadeAtual) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 20),
              Text("Gerenciar: $nome",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("Adicione dias de acesso ao motoboy",
                  style: TextStyle(color: Colors.grey)),
              SizedBox(height: 20),
              _botaoRenovar(context, uid, "1 Dia (Diária)", 1, validadeAtual, Colors.blue),
              _botaoRenovar(context, uid, "30 Dias (Mensal)", 30, validadeAtual, Colors.purple),
              _botaoRenovar(context, uid, "365 Dias (Anual)", 365, validadeAtual, Colors.orange),
              SizedBox(height: 10),
              Divider(),
              if (validadeAtual case final val? when DateTime.now().isBefore(val))
                TextButton.icon(
                  icon: Icon(Icons.block, color: Colors.red),
                  onPressed: () => _confirmarBloqueio(context, uid, nome),
                  label: Text("BLOQUEAR ACESSO",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoRenovar(BuildContext context, String uid, String label, int dias,
      DateTime? validadeAtual, Color cor) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10),
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          _aplicarRenovacao(uid, dias, validadeAtual);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Renovado por $dias dias com sucesso!"),
              backgroundColor: Colors.green));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Icon(Icons.add_circle_outline),
          ],
        ),
      ),
    );
  }

  void _aplicarRenovacao(String uid, int diasAdicionais, DateTime? validadeAtual) {
    DateTime base = DateTime.now();
    if (validadeAtual != null && validadeAtual.isAfter(base)) {
      base = validadeAtual;
    }
    final novaData = base.add(Duration(days: diasAdicionais));

    Supabase.instance.client
        .from('usuarios')
        .update({'validade_assinatura': novaData.toIso8601String()})
        .eq('id', uid);
  }

  void _confirmarBloqueio(BuildContext context, String uid, String nome) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Bloquear Usuário?"),
        content: Text(
            "Tem certeza que deseja remover o acesso de $nome? "
            "Ele não poderá receber novas corridas."),
        actions: [
          TextButton(
              child: Text("Cancelar"), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text("SIM, BLOQUEAR",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () {
              _bloquearUsuario(context, uid);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _bloquearUsuario(BuildContext context, String uid) {
    final ontem = DateTime.now().subtract(Duration(days: 1));
    Supabase.instance.client
        .from('usuarios')
        .update({'validade_assinatura': ontem.toIso8601String()})
        .eq('id', uid);

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Usuário bloqueado."), backgroundColor: Colors.red));
  }
}
