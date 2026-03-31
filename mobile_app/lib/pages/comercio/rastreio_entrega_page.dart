import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart' hide Marker;
import 'package:supabase_flutter/supabase_flutter.dart';

class RastreioEntregaPage extends StatefulWidget {
  final String pedidoId;
  final String clienteNome;

  const RastreioEntregaPage({
    required this.pedidoId,
    required this.clienteNome,
    super.key,
  });

  @override
  State<RastreioEntregaPage> createState() => _RastreioEntregaPageState();
}

class _RastreioEntregaPageState extends State<RastreioEntregaPage> {
  final MapController _mapController = MapController();
  List<LatLng> _rotaPoints = [];
  bool _modoSatelite = false;
  DateTime? _ultimoRota;

  Future<void> _calcularRota(LatLng inicio, LatLng fim) async {
    if (_ultimoRota != null &&
        DateTime.now().difference(_ultimoRota!).inSeconds < 10) {
      return;
    }
    _ultimoRota = DateTime.now();
    final url = Uri.parse(
        "https://router.project-osrm.org/route/v1/driving/"
        "${inicio.longitude},${inicio.latitude};"
        "${fim.longitude},${fim.latitude}"
        "?overview=full&geometries=geojson");
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if ((data['routes'] as List).isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          if (mounted) {
            setState(() =>
                _rotaPoints = coords.map((p) => LatLng(p[1], p[0])).toList());
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rastreio em Tempo Real'),
            Text(widget.clienteNome,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('pedidos')
            .stream(primaryKey: ['id'])
            .eq('id', widget.pedidoId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final pedido     = snapshot.data!.first;
          final status     = pedido['status'] as String? ?? 'ACEITO';
          final latMotoboy = (pedido['lat_motoboy']  as num?)?.toDouble();
          final lngMotoboy = (pedido['long_motoboy'] as num?)?.toDouble();
          final latDest    = (pedido['lat_destino']  as num?)?.toDouble();
          final lngDest    = (pedido['long_destino'] as num?)?.toDouble();

          if (latDest == null || lngDest == null) {
            return const Center(
                child: Text('Coordenadas de entrega não disponíveis.'));
          }

          final pontoEntrega = LatLng(latDest, lngDest);
          final posMotoboy = latMotoboy != null && lngMotoboy != null
              ? LatLng(latMotoboy, lngMotoboy)
              : pontoEntrega;

          _calcularRota(posMotoboy, pontoEntrega);

          final (Color corStatus, String labelStatus) = switch (status) {
            'ACEITO'     => (Colors.blue,   'A caminho da coleta'),
            'EM_VIAGEM'  => (Colors.indigo, 'Em viagem para entrega'),
            'FINALIZADO' => (Colors.green,  'Entregue!'),
            _            => (Colors.orange, 'Aguardando'),
          };

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                          initialCenter: posMotoboy, initialZoom: 14.0),
                      children: [
                        TileLayer(
                          urlTemplate: _modoSatelite
                              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          subdomains: _modoSatelite
                              ? const []
                              : const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.example.appdeliverymoto',
                        ),
                        if (_rotaPoints.isNotEmpty)
                          PolylineLayer(polylines: [
                            Polyline(
                                points: _rotaPoints,
                                color: corStatus,
                                strokeWidth: 5.0),
                          ]),
                        MarkerLayer(markers: [
                          Marker(
                            point: posMotoboy,
                            width: 80,
                            height: 80,
                            child: Lottie.asset('assets/motoboy.json',
                                fit: BoxFit.contain),
                          ),
                          Marker(
                            point: pontoEntrega,
                            width: 70,
                            height: 80,
                            child: Column(children: [
                              SizedBox(
                                height: 50,
                                width: 50,
                                child: Lottie.asset('assets/location.json',
                                    fit: BoxFit.contain),
                              ),
                              const Text('Entrega',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      backgroundColor: Colors.white)),
                            ]),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: corStatus, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(labelStatus,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: corStatus)),
                              Text(
                                pedido['endereco_destino'] ?? 'Ver no mapa',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (latMotoboy == null)
                          Text('Aguardando posição...',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.orange[700])),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'sat_rastreio',
                  backgroundColor: Colors.white,
                  elevation: 4,
                  onPressed: () =>
                      setState(() => _modoSatelite = !_modoSatelite),
                  child: Icon(
                    _modoSatelite ? Icons.map : Icons.satellite_alt,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
