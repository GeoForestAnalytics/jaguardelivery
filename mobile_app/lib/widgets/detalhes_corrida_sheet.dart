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

          const Divider(height: 30),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: corTema.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: corTema.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(iconeTema, color: corTema, size: 30),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEntrega ? "ENTREGA DE ENCOMENDA" : "TRANSPORTE DE PASSAGEIRO",
                        style: TextStyle(fontWeight: FontWeight.bold, color: corTema, fontSize: 13)),
                    if (isEntrega && itemEntrega != null)
                      Text("Item: $itemEntrega", style: const TextStyle(color: Colors.black87, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: Colors.grey[200], child: const Icon(Icons.location_on, color: Colors.red)),
            title: Text(endereco, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text("Destino Final"),
          ),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: Colors.grey[200], child: const Icon(Icons.person, color: Colors.black)),
            title: Text(nome),
            subtitle: const Text("Solicitante"),
          ),

          if (obs.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.yellow[50], borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange[800]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(obs, style: TextStyle(color: Colors.orange[900], fontStyle: FontStyle.italic))),
                ],
              ),
            ),

          const SizedBox(height: 10),

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
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(_processando ? "GARANTINDO CORRIDA..." : "ACEITAR CORRIDA"),
              onPressed: _processando ? null : _tentarAceitarCorrida,
            ),
          ),

          const SizedBox(height: 10),
          const Center(
            child: Text("Ao aceitar, os dados serão vinculados ao histórico.",
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
      // 1. ACEITE ATÔMICO (RPC) - Garante que ninguém mais pegue a corrida
      final aceito = await supabase.rpc('aceitar_corrida', params: {
        'p_corrida_id': corridaId,
        'p_motoboy_id': motoboyId,
      });

      if (!mounted) return;

      if (aceito == true) {
        // 2. BUSCA OS DADOS DO MOTOBOY PARA O CARIMBO
        final perfilMoto = await supabase
            .from('usuarios')
            .select('nome, telefone, moto_placa')
            .eq('id', motoboyId)
            .single();

        // 3. SALVA OS DADOS DESCRITIVOS NA CORRIDA (CARIMBO)
        await supabase.from('corridas').update({
          'motoboy_nome':  perfilMoto['nome'],
          'motoboy_tel':   perfilMoto['telefone'],
          'motoboy_placa': perfilMoto['moto_placa'],
          'data_aceite':   DateTime.now().toIso8601String(),
        }).eq('id', corridaId);

        // 4. NOTIFICA O CLIENTE
        final idCliente = widget.pedido['id_solicitante']?.toString() ?? '';
        if (idCliente.isNotEmpty) {
          await NotificacaoService.corridaAceita(
              idCliente: idCliente, nomeMotoboy: perfilMoto['nome'] ?? 'Motoboy');
        }

        if (!mounted) return;
        Navigator.pop(context); // Fecha o sheet
        _abrirWhatsApp(widget.pedido); // Abre o zap com o cliente
        
      } else {
        setState(() => _processando = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Esta corrida já foi pega por outro motoboy!"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao aceitar corrida: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirWhatsApp(Map<String, dynamic> data) async {
    final String telefone = data['telefone_solicitante'] ?? '';
    final String nome     = data['nome_solicitante'] ?? 'Cliente';
    final double valor    = (data['valor'] ?? 0).toDouble();
    final String endereco = data['endereco_destino'] ?? 'Endereço na localização';

    final String numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    String mensagem = "Olá *$nome*! 🏍️\nAcabei de aceitar sua corrida no Jaguar Delivery.\n💰 Valor: *R\$ ${valor.toStringAsFixed(2)}*\n📍 Destino: $endereco\nEstou a caminho!";

    final url = Uri.parse("https://wa.me/55$numeroLimpo?text=${Uri.encodeComponent(mensagem)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}