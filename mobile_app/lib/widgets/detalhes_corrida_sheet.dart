import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notificacao_service.dart';

class DetalhesCorridaSheet extends StatefulWidget {
  final Map<String, dynamic> pedido;

  const DetalhesCorridaSheet({required this.pedido, Key? key}) : super(key: key);

  @override
  _DetalhesCorridaSheetState createState() => _DetalhesCorridaSheetState();
}

class _DetalhesCorridaSheetState extends State<DetalhesCorridaSheet> {
  bool _processando = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.pedido;

    final String nome     = data['nome_solicitante'] ?? 'Cliente';
    final double valor    = (data['valor'] ?? 0).toDouble();
    final String endereco = data['endereco_destino'] ?? 'Não informado';
    final String obs      = data['observacao'] ?? '';
    final double distancia = (data['distancia_km'] ?? 0).toDouble();
    final String tipoServico = data['tipo_servico'] ?? 'PASSAGEIRO';
    final String? itemEntrega = data['item_entrega'];

    final bool isEntrega = tipoServico == 'ENTREGA';
    final Color corTema = isEntrega ? Colors.brown : Colors.indigo;
    final IconData iconeTema = isEntrega ? Icons.local_shipping : Icons.person;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho: valor e distância
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
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions, size: 16, color: Colors.grey[700]),
                    SizedBox(width: 4),
                    Text("${distancia.toStringAsFixed(1)} km",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
                  ],
                ),
              ),
            ],
          ),

          Divider(height: 30),

          // Tipo de serviço
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: corTema.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: corTema.withValues(alpha: 0.3)),
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
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

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

          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _processando
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(Icons.phone),
              label: Text(_processando ? "GARANTINDO CORRIDA..." : "ACEITAR CORRIDA"),
              onPressed: _processando ? null : _tentarAceitarCorrida,
            ),
          ),

          SizedBox(height: 10),
          Center(
            child: Text("Ao aceitar, você será redirecionado para o WhatsApp.",
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _tentarAceitarCorrida() async {
    setState(() => _processando = true);

    final supabase = Supabase.instance.client;
    final motoboyId = supabase.auth.currentUser?.id;
    if (motoboyId == null) return;

    final corridaId = widget.pedido['id'].toString();

    try {
      // Aceite atômico via função RPC (evita corrida dupla)
      final aceito = await supabase.rpc('aceitar_corrida', params: {
        'p_corrida_id': corridaId,
        'p_motoboy_id': motoboyId,
      });

      if (!mounted) return;

      if (aceito == true) {
        // Notifica o cliente que o motoboy aceitou
        final idCliente  = widget.pedido['id_solicitante']?.toString() ?? '';
        final nomeMoto   = (await Supabase.instance.client
            .from('usuarios')
            .select('nome')
            .eq('id', motoboyId)
            .maybeSingle())?['nome'] as String? ?? 'Motoboy';
        if (idCliente.isNotEmpty) {
          await NotificacaoService.corridaAceita(
              idCliente: idCliente, nomeMotoboy: nomeMoto);
        }
        if (!mounted) return;
        Navigator.pop(context);
        _abrirWhatsApp(widget.pedido);
      } else {
        setState(() => _processando = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Esta corrida já foi pega!"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processando = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao aceitar corrida."), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirWhatsApp(Map<String, dynamic> data) async {
    final String telefone = data['telefone_solicitante'] ?? '';
    final String nome     = data['nome_solicitante'] ?? 'Cliente';
    final double valor    = (data['valor'] ?? 0).toDouble();
    final String endereco = data['endereco_destino'] ?? 'Endereço na localização';
    final String obs      = data['observacao'] ?? '';

    final String numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');

    String mensagem =
        "Olá *$nome*! 🏍️\n\n"
        "Acabei de aceitar sua solicitação no App.\n"
        "💰 Valor: *R\$ ${valor.toStringAsFixed(2)}*\n\n"
        "📍 *Confirmando Destino:*\n$endereco\n";

    if (obs.isNotEmpty) mensagem += "📝 Obs: $obs\n";
    mensagem += "\nEstou a caminho!";

    final url = Uri.parse("https://wa.me/55$numeroLimpo?text=${Uri.encodeComponent(mensagem)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
