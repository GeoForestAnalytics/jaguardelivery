import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';

class SelecionarDestinoPage extends StatefulWidget {
  final double latInicial;
  final double longInicial;

  const SelecionarDestinoPage({
    required this.latInicial,
    required this.longInicial,
    super.key,
  });

  @override
  State<SelecionarDestinoPage> createState() => _SelecionarDestinoPageState();
}

class _SelecionarDestinoPageState extends State<SelecionarDestinoPage> {
  late LatLng _centroMapa;
  final _mapController  = MapController();
  final _buscaController = TextEditingController();

  List<Map<String, dynamic>> _sugestoes = [];
  bool    _buscando     = false;
  bool    _modoSatelite = false;
  String? _erroMsg;
  Timer?  _debounce;

  @override
  void initState() {
    super.initState();
    _centroMapa = LatLng(widget.latInicial, widget.longInicial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  // ── Google Places Autocomplete ────────────────────────────────
  void _onTextChanged(String texto) {
    _debounce?.cancel();
    if (texto.trim().length < 3) {
      setState(() { _sugestoes = []; _erroMsg = null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    if (!mounted) return;
    setState(() { _buscando = true; _erroMsg = null; });

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input':      texto,
          'key':        GoogleConfig.placesApiKey,
          'language':   'pt-BR',
          'components': 'country:br',
          'types':      'address',
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;

      final body = json.decode(res.body) as Map<String, dynamic>;

      if (body['status'] == 'OK') {
        final predictions = body['predictions'] as List;
        setState(() {
          _sugestoes = predictions.map<Map<String, dynamic>>((p) => {
            'descricao': p['description'] as String,
            'place_id':  p['place_id']   as String,
          }).toList();
        });
      } else if (body['status'] == 'ZERO_RESULTS') {
        setState(() { _sugestoes = []; _erroMsg = 'Nenhum endereço encontrado.'; });
      } else {
        setState(() { _erroMsg = 'Erro na busca. Tente arrastar o mapa.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _erroMsg = 'Sem conexão. Arraste o mapa para escolher.'; });
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  // ── Busca coordenadas pelo place_id ──────────────────────────
  Future<void> _selecionarSugestao(Map<String, dynamic> item) async {
    FocusScope.of(context).unfocus();
    setState(() { _sugestoes = []; _buscando = true; });
    _buscaController.text = item['descricao'] as String;

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': item['place_id'] as String,
          'fields':   'geometry',
          'key':      GoogleConfig.placesApiKey,
          'language': 'pt-BR',
        },
      );

      final res  = await http.get(uri).timeout(const Duration(seconds: 6));
      final body = json.decode(res.body) as Map<String, dynamic>;

      if (body['status'] == 'OK') {
        final loc = body['result']['geometry']['location'] as Map<String, dynamic>;
        final ponto = LatLng(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        );
        if (mounted) {
          setState(() => _centroMapa = ponto);
          _mapController.move(ponto, 17.0);
        }
      }
    } catch (_) {
      // Mantém o pino onde está
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Para onde?'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroMapa,
              initialZoom:   16.0,
              onPositionChanged: (pos, _) {
                _centroMapa = pos.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _modoSatelite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: _modoSatelite ? const [] : const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.appdeliverymoto',
              ),
            ],
          ),

          // ── Botão satélite ────────────────────────────────────
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'satelite_dest',
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: () => setState(() => _modoSatelite = !_modoSatelite),
              child: Icon(
                _modoSatelite ? Icons.map : Icons.satellite_alt,
                color: Colors.black87,
              ),
            ),
          ),

          // ── Pino central fixo ─────────────────────────────────
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on, color: Colors.red, size: 50),
            ),
          ),

          // ── Campo de busca + sugestões ────────────────────────
          Positioned(
            top: 12, left: 12, right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _buscaController,
                    onChanged: _onTextChanged,
                    autofocus: true,
                    keyboardType: TextInputType.streetAddress,
                    decoration: InputDecoration(
                      hintText: 'Digite o endereço de destino...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buscando
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _buscaController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _buscaController.clear();
                                    setState(() { _sugestoes = []; _erroMsg = null; });
                                  },
                                )
                              : null,
                      filled:    true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                if (_erroMsg != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_erroMsg!,
                        style: const TextStyle(fontSize: 13, color: Colors.deepOrange)),
                  ),

                if (_sugestoes.isNotEmpty)
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _sugestoes.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (context, i) {
                        final item = _sugestoes[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              color: Colors.red, size: 20),
                          title: Text(
                            item['descricao'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _selecionarSugestao(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Botão confirmar ───────────────────────────────────
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, {
                    'ponto':    _centroMapa,
                    'endereco': _buscaController.text.trim(),
                  }),
                  child: const Text('CONFIRMAR ESTE LOCAL',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
