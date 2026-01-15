// Arquivo: lib/widgets/solicitar_corrida_sheet.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart'; 
import 'package:latlong2/latlong.dart'; 
import 'package:geolocator/geolocator.dart'; 

import '../pages/home/selecionar_destino_page.dart';

class SolicitarCorridaSheet extends StatefulWidget {
  final double latOrigem;
  final double longOrigem;

  const SolicitarCorridaSheet({
    Key? key, 
    required this.latOrigem, 
    required this.longOrigem
  }) : super(key: key);

  @override
  _SolicitarCorridaSheetState createState() => _SolicitarCorridaSheetState();
}

class _SolicitarCorridaSheetState extends State<SolicitarCorridaSheet> {
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _obsController = TextEditingController();
  
  String _formaPagamento = "Pix";
  bool _buscandoEndereco = false;
  String _cidadeAtual = ""; 

  double? _latDestino;
  double? _longDestino;
  double _distanciaKm = 0.0;
  double _precoEstimado = 0.0;

  bool _isDelivery = false; 
  String? _itemEntrega;
  
  final List<String> _itensComuns = [
    "Pizza", "Lanche", "Documento", "Bolo", "Remédio", "Chaves", "Outro"
  ];

  @override
  void initState() {
    super.initState();
    _descobrirCidadeAtual();
  }

  void _descobrirCidadeAtual() async {
    try {
      List<Placemark> locais = await placemarkFromCoordinates(widget.latOrigem, widget.longOrigem);
      if (locais.isNotEmpty) {
        setState(() {
          _cidadeAtual = locais.first.subAdministrativeArea ?? locais.first.locality ?? "";
        });
      }
    } catch (e) {
      print("Erro ao detectar cidade: $e");
    }
  }

  void _recalcularPreco() {
    if (_latDestino != null && _longDestino != null) {
      double distanciaMetros = Geolocator.distanceBetween(
        widget.latOrigem,
        widget.longOrigem,
        _latDestino!,
        _longDestino!,
      );

      setState(() {
        // Multiplicamos por 1.35 para compensar as curvas das ruas (estimativa real).
        _distanciaKm = (distanciaMetros / 1000) * 1.35; 
        
        // Tabela de Preços Simples
        if (_distanciaKm <= 1.0) {
          _precoEstimado = 6.00;
        } else if (_distanciaKm > 1.0 && _distanciaKm <= 3.0) {
          _precoEstimado = 7.00;
        } else if (_distanciaKm > 3.0 && _distanciaKm <= 5.0) {
          _precoEstimado = 8.00;
        } else if (_distanciaKm > 5.0 && _distanciaKm <= 10.0) {
          _precoEstimado = 12.00;
        } else {
          // Acima de 10km: R$ 20 base + R$ 2 por km adicional
          _precoEstimado = 20.00 + ((_distanciaKm - 10) * 2.0);
        }
      });
    }
  }

  // --- ATUALIZAÇÃO IMPORTANTE AQUI (API SEGURA) ---
  void _iniciarBuscaInteligente() async {
    String textoDigitado = _ruaController.text.trim();
    if (textoDigitado.length < 3) return;
    
    setState(() { _buscandoEndereco = true; _precoEstimado = 0.0; });
    FocusScope.of(context).unfocus();

    String queryParaAPI = textoDigitado;
    if (_cidadeAtual.isNotEmpty && !queryParaAPI.toLowerCase().contains(_cidadeAtual.toLowerCase())) {
      queryParaAPI = "$queryParaAPI, $_cidadeAtual";
    }

    try {
      double margem = 0.5; 
      String viewbox = "${widget.longOrigem - margem},${widget.latOrigem + margem},${widget.longOrigem + margem},${widget.latOrigem - margem}";
      final uri = Uri.parse("https://nominatim.openstreetmap.org/search?q=$queryParaAPI&format=json&limit=1&viewbox=$viewbox&bounded=1&countrycodes=br");
      
      // Adicionado TIMEOUT de 5 segundos para não travar o app
      final response = await http.get(uri, headers: {'User-Agent': 'com.app.delivery'})
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _latDestino = double.parse(data[0]['lat']);
            _longDestino = double.parse(data[0]['lon']);
            _recalcularPreco();
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Endereço encontrado!"), backgroundColor: Colors.green));
        } else {
          throw Exception("Vazio"); // Força cair no catch para mostrar msg amigável
        }
      } else {
        throw Exception("Erro API");
      }
    } catch (e) { 
      // Tratamento de erro amigável
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Não conseguimos achar automaticamente. Por favor, clique no ícone 'Mapa' ao lado."), 
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ));
    } finally { 
      if (mounted) setState(() => _buscandoEndereco = false); 
    }
  }

  void _abrirMapaSelecao() async {
    final LatLng? resultado = await Navigator.push(context, MaterialPageRoute(builder: (context) => SelecionarDestinoPage(latInicial: widget.latOrigem, longInicial: widget.longOrigem)));
    if (resultado != null) {
      setState(() {
        _latDestino = resultado.latitude;
        _longDestino = resultado.longitude;
        if (_ruaController.text.isEmpty) _ruaController.text = "Localização definida no Mapa";
        _recalcularPreco();
      });
    }
  }

  void _criarPedido() async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Processando localização..."), duration: Duration(seconds: 1)));
    
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    
    // Tratamento de segurança caso o perfil esteja incompleto
    final userData = userDoc.data() ?? {};
    final String nomeUser = userData['nome'] ?? 'Cliente';
    final String telUser = userData['telefone'] ?? '';

    // 1. DESCOBRIR O ENDEREÇO DE ORIGEM (ONDE O CLIENTE ESTÁ)
    String enderecoOrigemTexto = "Localização no Mapa (GPS)";
    try {
      List<Placemark> locaisOrigem = await placemarkFromCoordinates(widget.latOrigem, widget.longOrigem);
      if (locaisOrigem.isNotEmpty) {
        Placemark local = locaisOrigem.first;
        enderecoOrigemTexto = "${local.thoroughfare ?? 'Rua sem nome'}, ${local.subThoroughfare ?? 'S/N'} - ${local.subLocality ?? ''}";
      }
    } catch (e) {
      print("Erro ao converter origem: $e");
    }

    // 2. Montar Endereço de Destino
    String enderecoDestinoFinal = "${_ruaController.text}, Nº ${_numeroController.text}";
    if (_bairroController.text.isNotEmpty) enderecoDestinoFinal += " - ${_bairroController.text}";

    String descricaoFinal = _isDelivery ? "Entrega: ${_itemEntrega ?? 'Não especificado'}" : "Transporte de Passageiro";
    if (_obsController.text.isNotEmpty) descricaoFinal += " | Obs: ${_obsController.text}";

    await FirebaseFirestore.instance.collection('corridas').add({
      'id_solicitante': user.uid,
      'nome_solicitante': nomeUser,
      'telefone_solicitante': telUser,
      'lat_origem': widget.latOrigem,
      'long_origem': widget.longOrigem,
      'endereco_origem': enderecoOrigemTexto, 
      'lat_destino': _latDestino,
      'long_destino': _longDestino,
      'endereco_destino': enderecoDestinoFinal,
      'valor': _precoEstimado,
      'distancia_km': _distanciaKm,
      'pagamento': _formaPagamento,
      'tipo_servico': _isDelivery ? 'ENTREGA' : 'PASSAGEIRO',
      'item_entrega': _isDelivery ? _itemEntrega : null,
      'observacao': descricaoFinal,
      'status': 'PENDENTE',
      'data_criacao': FieldValue.serverTimestamp(),
      'id_motoboy': null,
      'lat_motoboy': null,
      'long_motoboy': null,
    });

    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pedido Enviado!"), backgroundColor: Colors.green[700]));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, 
        left: 16, right: 16, top: 16
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Nova Solicitação ${_cidadeAtual.isNotEmpty ? '($_cidadeAtual)' : ''}", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ruaController,
                    decoration: InputDecoration(
                      labelText: "Destino (Nome da Rua)",
                      hintText: "Ex: Rua Campos Sales",
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(icon: Icon(Icons.search), onPressed: _iniciarBuscaInteligente)
                    ),
                    onSubmitted: (_) => _iniciarBuscaInteligente(),
                  ),
                ),
                SizedBox(width: 8),
                InkWell(
                  onTap: _abrirMapaSelecao,
                  child: Container(
                    height: 55, width: 55,
                    decoration: BoxDecoration(color: Colors.blue[50], border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(8)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map, color: Colors.blue), Text("Mapa", style: TextStyle(fontSize: 10, color: Colors.blue))]),
                  ),
                )
              ],
            ),
            
            if (_buscandoEndereco) LinearProgressIndicator(),
            SizedBox(height: 10),

            Row(
              children: [
                Expanded(flex: 4, child: TextField(controller: _numeroController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Número", errorText: _numeroController.text.isEmpty && _precoEstimado > 0 ? 'Obrigatório' : null), onChanged: (val) => setState((){}))),
                SizedBox(width: 10),
                Expanded(flex: 6, child: TextField(controller: _bairroController, decoration: InputDecoration(labelText: "Bairro", border: OutlineInputBorder()))),
              ],
            ),

            SizedBox(height: 12),

            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: ChoiceChip(label: Center(child: Text("🙋 Passageiro")), selected: !_isDelivery, onSelected: (val) => setState(() { _isDelivery = false; _itemEntrega = null; }), selectedColor: Colors.blue[100])),
                  SizedBox(width: 8),
                  Expanded(child: ChoiceChip(label: Center(child: Text("📦 Entrega")), selected: _isDelivery, onSelected: (val) => setState(() => _isDelivery = true), selectedColor: Colors.orange[100])),
                ],
              ),
            ),

            if (_isDelivery) ...[
              SizedBox(height: 12),
              Wrap(spacing: 8.0, runSpacing: 4.0, children: _itensComuns.map((item) => ChoiceChip(label: Text(item), selected: _itemEntrega == item, onSelected: (selected) => setState(() => _itemEntrega = selected ? item : null), backgroundColor: Colors.grey[100], selectedColor: Colors.orange[200])).toList()),
            ],

            SizedBox(height: 15),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Distância Estimada", style: TextStyle(color: Colors.grey[600], fontSize: 12)), Text("${_distanciaKm.toStringAsFixed(1)} km", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Valor Total", style: TextStyle(color: Colors.grey[600], fontSize: 12)), Text("R\$ ${_precoEstimado.toStringAsFixed(2).replaceAll('.', ',')}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green[800]))]),
                ],
              ),
            ),

            SizedBox(height: 12),
            DropdownButtonFormField<String>(value: _formaPagamento, items: ["Pix", "Dinheiro", "Maquininha"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _formaPagamento = val!), decoration: InputDecoration(labelText: "Forma de Pagamento", border: OutlineInputBorder(), isDense: true)),
            SizedBox(height: 12),
            TextField(controller: _obsController, decoration: InputDecoration(labelText: "Observação (Ex: Portão cinza)", border: OutlineInputBorder())),
            SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _isDelivery ? Colors.orange[800] : Colors.blue[800], foregroundColor: Colors.white),
                onPressed: (_latDestino != null && _precoEstimado > 0 && _numeroController.text.isNotEmpty && (!_isDelivery || _itemEntrega != null)) ? _criarPedido : null,
                child: Text(_isDelivery ? "CHAMAR MOTOBOY (ENTREGA)" : "CHAMAR MOTOBOY (CORRIDA)", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}