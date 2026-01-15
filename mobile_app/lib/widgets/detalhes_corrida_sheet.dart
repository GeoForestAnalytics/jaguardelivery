import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class DetalhesCorridaSheet extends StatefulWidget {
  final DocumentSnapshot pedido;

  const DetalhesCorridaSheet({required this.pedido});

  @override
  _DetalhesCorridaSheetState createState() => _DetalhesCorridaSheetState();
}

class _DetalhesCorridaSheetState extends State<DetalhesCorridaSheet> {
  bool _processando = false; // Para evitar cliques duplos e mostrar loading

  @override
  Widget build(BuildContext context) {
    // Extraindo dados com segurança
    final data = widget.pedido.data() as Map<String, dynamic>;
    
    final String nome = data['nome_solicitante'] ?? 'Cliente';
    final double valor = data['valor']?.toDouble() ?? 0.0;
    final String endereco = data['endereco_destino'] ?? 'Não informado';
    final String obs = data['observacao'] ?? '';
    // final String telefone = data['telefone_solicitante'] ?? ''; // Usado na função de whats
    
    // Novos Campos
    final double distancia = data['distancia_km']?.toDouble() ?? 0.0;
    final String tipoServico = data['tipo_servico'] ?? 'PASSAGEIRO'; 
    final String? itemEntrega = data['item_entrega'];

    // Definição de Cores e Ícones
    final bool isEntrega = tipoServico == 'ENTREGA';
    final Color corTema = isEntrega ? Colors.brown : Colors.indigo;
    final IconData iconeTema = isEntrega ? Icons.local_shipping : Icons.person;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // 1. CABEÇALHO (Valor e Distância)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Valor da Corrida", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text("R\$ ${valor.toStringAsFixed(2)}", 
                       style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[700])),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions, size: 16, color: Colors.grey[700]),
                    SizedBox(width: 4),
                    Text("${distancia.toStringAsFixed(1)} km", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
                  ],
                ),
              )
            ],
          ),
          
          Divider(height: 30),

          // 2. TIPO DE SERVIÇO
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: corTema.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: corTema.withOpacity(0.3))
            ),
            child: Row(
              children: [
                Icon(iconeTema, color: corTema, size: 30),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEntrega ? "ENTREGA DE ENCOMENDA" : "TRANSPORTE DE PASSAGEIRO", 
                         style: TextStyle(fontWeight: FontWeight.bold, color: corTema, fontSize: 13)),
                    if (isEntrega && itemEntrega != null)
                      Text("Item: $itemEntrega", style: TextStyle(color: Colors.black87, fontSize: 16)),
                  ],
                )
              ],
            ),
          ),

          SizedBox(height: 20),
          
          // 3. DETALHES
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: Colors.grey[200], child: Icon(Icons.location_on, color: Colors.red)),
            title: Text(endereco, style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text("Destino Final"),
          ),
          
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: Colors.grey[200], child: Icon(Icons.person, color: Colors.black)),
            title: Text(nome),
            subtitle: Text("Solicitante"),
          ),

          if (obs.isNotEmpty)
            Container(
              margin: EdgeInsets.only(bottom: 20),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.yellow[50], borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange[800]),
                  SizedBox(width: 8),
                  Expanded(child: Text(obs, style: TextStyle(color: Colors.orange[900], fontStyle: FontStyle.italic))),
                ],
              ),
            ),

          SizedBox(height: 10),

          // 4. BOTÃO ACEITAR
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600], 
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              icon: _processando 
                  ? Container(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Icon(Icons.phone),
              label: Text(_processando ? "GARANTINDO CORRIDA..." : "ACEITAR CORRIDA"),
              onPressed: _processando ? null : () => _tentarAceitarCorrida(context, data),
            ),
          ),
          
          SizedBox(height: 10),
          Center(child: Text("Ao aceitar, você será redirecionado para o WhatsApp.", style: TextStyle(fontSize: 10, color: Colors.grey))),
        ],
      ),
    );
  }

  // --- LÓGICA DE TRANSAÇÃO ---
  void _tentarAceitarCorrida(BuildContext context, Map<String, dynamic> dadosPedido) async {
    setState(() => _processando = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = widget.pedido.reference;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception("Pedido não existe mais!");
        
        String statusAtual = snapshot.get('status');
        if (statusAtual != 'PENDENTE') throw Exception("Esta corrida já foi pega!");

        transaction.update(docRef, {
          'status': 'ACEITO',
          'id_motoboy': user.uid,
          'data_aceite': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.pop(context);
        _abrirWhatsApp(dadosPedido);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _processando = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- NOVA MENSAGEM DO WHATSAPP ---
  void _abrirWhatsApp(Map<String, dynamic> data) async {
    String telefone = data['telefone_solicitante'] ?? '';
    String nome = data['nome_solicitante'] ?? 'Cliente';
    double valor = data['valor']?.toDouble() ?? 0.0;
    
    // Pegando o endereço que o cliente digitou
    String endereco = data['endereco_destino'] ?? 'Endereço na localização';
    String obs = data['observacao'] ?? '';

    String numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // --- MENSAGEM ATUALIZADA ---
    String mensagem = 
        "Olá *$nome*! 🏍️\n\n"
        "Acabei de aceitar sua solicitação no App.\n"
        "💰 Valor: *R\$ ${valor.toStringAsFixed(2)}*\n\n"
        "📍 *Confirmando Destino:*\n$endereco\n";
    
    if (obs.isNotEmpty) {
      mensagem += "📝 Obs: $obs\n";
    }

    mensagem += "\nEstou a caminho!";

    final url = Uri.parse("https://wa.me/55$numeroLimpo?text=${Uri.encodeComponent(mensagem)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print("Não foi possível abrir o WhatsApp: $url");
    }
  }
}