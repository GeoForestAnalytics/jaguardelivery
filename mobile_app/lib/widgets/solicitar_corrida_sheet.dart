import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notificacao_service.dart';

/// Sheet exibido APÓS o usuário confirmar o destino na tela de mapa.
/// Recebe as coordenadas prontas e só pergunta: tipo de serviço,
/// forma de pagamento e observação.
class SolicitarCorridaSheet extends StatefulWidget {
  final double latOrigem;
  final double longOrigem;
  final double latDestino;
  final double longDestino;
  final String enderecoDestino;

  const SolicitarCorridaSheet({
    Key? key,
    required this.latOrigem,
    required this.longOrigem,
    required this.latDestino,
    required this.longDestino,
    required this.enderecoDestino,
  }) : super(key: key);

  @override
  _SolicitarCorridaSheetState createState() => _SolicitarCorridaSheetState();
}

class _SolicitarCorridaSheetState extends State<SolicitarCorridaSheet> {
  final _obsController = TextEditingController();

  String _formaPagamento = "Pix";
  bool   _isDelivery     = false;
  String? _itemEntrega;

  double _distanciaKm   = 0.0;
  double _precoEstimado = 0.0;

  final List<String> _itensComuns = [
    "Pizza", "Lanche", "Documento", "Bolo", "Remédio", "Chaves", "Outro"
  ];

  @override
  void initState() {
    super.initState();
    _calcularPreco();
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  void _calcularPreco() {
    final metros = Geolocator.distanceBetween(
      widget.latOrigem,  widget.longOrigem,
      widget.latDestino, widget.longDestino,
    );
    final km = (metros / 1000) * 1.35;

    double preco;
    if (km <= 1.0) {
      preco = 6.00;
    } else if (km <= 3.0) {
      preco = 7.00;
    } else if (km <= 5.0) {
      preco = 8.00;
    } else if (km <= 10.0) {
      preco = 12.00;
    } else {
      preco = 20.00 + ((km - 10) * 2.0);
    }

    setState(() {
      _distanciaKm   = km;
      _precoEstimado = preco;
    });
  }

  Future<void> _criarPedido() async {
    final supabase = Supabase.instance.client;
    final user     = supabase.auth.currentUser!;

    final perfilData = await supabase
        .from('usuarios')
        .select('nome, telefone')
        .eq('id', user.id)
        .maybeSingle();

    final String nomeUser = perfilData?['nome'] ?? 'Cliente';
    final String telUser  = perfilData?['telefone'] ?? '';

    String enderecoOrigemTexto = "Localização GPS";
    String cidadeOrigem = '';
    String estadoOrigem = '';
    try {
      final locais = await placemarkFromCoordinates(
          widget.latOrigem, widget.longOrigem);
      if (locais.isNotEmpty) {
        final l = locais.first;
        enderecoOrigemTexto =
            "${l.thoroughfare ?? 'Rua'}, ${l.subThoroughfare ?? 'S/N'}"
            "${l.subLocality != null ? ' - ${l.subLocality}' : ''}";
        cidadeOrigem = l.locality ?? l.subAdministrativeArea ?? '';
        estadoOrigem = l.administrativeArea ?? '';
      }
    } catch (_) {}

    String descricao = _isDelivery
        ? "Entrega: ${_itemEntrega ?? 'Não especificado'}"
        : "Transporte de Passageiro";
    if (_obsController.text.isNotEmpty) {
      descricao += " | ${_obsController.text}";
    }

    await supabase.from('corridas').insert({
      'id_solicitante':       user.id,
      'nome_solicitante':     nomeUser,
      'telefone_solicitante': telUser,
      'lat_origem':           widget.latOrigem,
      'long_origem':          widget.longOrigem,
      'endereco_origem':      enderecoOrigemTexto,
      'lat_destino':          widget.latDestino,
      'long_destino':         widget.longDestino,
      'endereco_destino':     widget.enderecoDestino,
      'valor':                _precoEstimado,
      'distancia_km':         _distanciaKm,
      'pagamento':            _formaPagamento,
      'tipo_servico':         _isDelivery ? 'ENTREGA' : 'PASSAGEIRO',
      'item_entrega':         _isDelivery ? _itemEntrega : null,
      'observacao':           descricao,
      'status':               'PENDENTE',
      'criado_em':            DateTime.now().toIso8601String(),
    });

    // Notifica todos os motoboys disponíveis
    await NotificacaoService.novaCorrida(widget.enderecoDestino);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Pedido enviado! Aguardando motoboy..."),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Card do destino confirmado
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Destino",
                          style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                        ),
                        Text(
                          widget.enderecoDestino.isNotEmpty
                              ? widget.enderecoDestino
                              : "Local selecionado no mapa",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Passageiro / Entrega
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("🙋 Passageiro")),
                      selected: !_isDelivery,
                      onSelected: (_) => setState(() {
                        _isDelivery  = false;
                        _itemEntrega = null;
                      }),
                      selectedColor: Colors.blue[100],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("📦 Entrega")),
                      selected: _isDelivery,
                      onSelected: (_) => setState(() => _isDelivery = true),
                      selectedColor: Colors.orange[100],
                    ),
                  ),
                ],
              ),
            ),

            if (_isDelivery) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _itensComuns.map((item) => ChoiceChip(
                  label: Text(item),
                  selected: _itemEntrega == item,
                  onSelected: (sel) =>
                      setState(() => _itemEntrega = sel ? item : null),
                  backgroundColor: Colors.grey[100],
                  selectedColor: Colors.orange[200],
                )).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Resumo de preço
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Distância",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text("${_distanciaKm.toStringAsFixed(1)} km",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Valor estimado",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text(
                        "R\$ ${_precoEstimado.toStringAsFixed(2).replaceAll('.', ',')}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                            color: Colors.green[800]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Pagamento
            DropdownButtonFormField<String>(
              initialValue: _formaPagamento,
              items: ["Pix", "Dinheiro", "Maquininha"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _formaPagamento = val!),
              decoration: const InputDecoration(
                labelText: "Forma de Pagamento",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 12),

            // Observação
            TextField(
              controller: _obsController,
              decoration: const InputDecoration(
                labelText: "Observação (Ex: Portão cinza)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Botão chamar
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isDelivery ? Colors.orange[800] : Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.motorcycle),
                label: Text(
                  _isDelivery
                      ? "CHAMAR MOTOBOY (ENTREGA)"
                      : "CHAMAR MOTOBOY (CORRIDA)",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: (!_isDelivery || _itemEntrega != null)
                    ? _criarPedido
                    : null,
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
