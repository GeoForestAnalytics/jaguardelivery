import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/notificacao_service.dart';
import '../../widgets/avaliacao_sheet.dart';
import '../../widgets/card_motoboy_aceito.dart';

class MonitoramentoPage extends StatefulWidget {
  final String corridaId;
  final bool isMotoboy;

  const MonitoramentoPage({required this.corridaId, required this.isMotoboy, Key? key})
      : super(key: key);

  @override
  _MonitoramentoPageState createState() => _MonitoramentoPageState();
}

class _MonitoramentoPageState extends State<MonitoramentoPage> {
  final MapController _mapController = MapController();
  final _supabase = Supabase.instance.client;

  List<LatLng> _rotaPoints = [];
  Timer? _timerLocalizacaoMotoboy;
  DateTime? _ultimoCalculoRota;

  String? _overlayAnimation;
  bool _showOverlay      = false;
  bool _modoSatelite     = false;
  bool _avaliacaoMostrada = false;

  Map<String, dynamic>? _motoboyPerfil;
  String? _ultimoStatus;

  @override
  void initState() {
    super.initState();
    if (widget.isMotoboy) {
      _iniciarBroadcastDeLocalizacao();
    } else {
      _carregarPerfilMotoboy();
    }
  }

  @override
  void dispose() {
    _timerLocalizacaoMotoboy?.cancel();
    super.dispose();
  }

  // Lógica de ajuste automático de câmera (Estilo Uber)
  void _ajustarCamera(LatLng posMotoboy, LatLng alvo) {
    try {
      final bounds = LatLngBounds.fromPoints([posMotoboy, alvo]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 100, bottom: 300, left: 50, right: 50),
        ),
      );
    } catch (_) {}
  }

  Future<void> _carregarPerfilMotoboy() async {
    try {
      final corrida = await _supabase
          .from('corridas')
          .select('id_motoboy')
          .eq('id', widget.corridaId)
          .maybeSingle();

      final motoboyId = corrida?['id_motoboy'] as String?;
      if (motoboyId == null) return;

      final perfil = await _supabase
          .from('usuarios')
          .select('nome, foto_url, moto_modelo, moto_placa, telefone, avaliacao_media, total_avaliacoes')
          .eq('id', motoboyId)
          .maybeSingle();

      if (perfil != null && mounted) {
        setState(() => _motoboyPerfil = perfil);
      }
    } catch (_) {}
  }

  void _iniciarBroadcastDeLocalizacao() {
    // Frequência de 5 segundos para movimento suave
    _timerLocalizacaoMotoboy = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition();
        await _supabase.from('corridas').update({
          'lat_motoboy':  position.latitude,
          'long_motoboy': position.longitude,
        }).eq('id', widget.corridaId);
      } catch (_) {}
    });
  }

  Future<void> _calcularRota(LatLng inicio, LatLng fim) async {
    if (_ultimoCalculoRota != null &&
        DateTime.now().difference(_ultimoCalculoRota!).inSeconds < 8) return;

    _ultimoCalculoRota = DateTime.now();
    final url = Uri.parse(
        "https://router.project-osrm.org/route/v1/driving/"
        "${inicio.longitude},${inicio.latitude};"
        "${fim.longitude},${fim.latitude}"
        "?overview=full&geometries=geojson");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if ((data['routes'] as List).isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          if (mounted) {
            setState(() => _rotaPoints = coords.map((p) => LatLng(p[1], p[0])).toList());
          }
        }
      }
    } catch (_) {}
  }

  void _tocarAnimacaoEProsseguir(String jsonAsset, Future<void> Function() onFinish) {
    setState(() { _overlayAnimation = jsonAsset; _showOverlay = true; });
    Timer(const Duration(seconds: 4), () async {
      if (mounted) {
        setState(() { _showOverlay = false; _overlayAnimation = null; });
        await onFinish();
      }
    });
  }

  void _mostrarAvaliacao(Map<String, dynamic> data) {
    if (_avaliacaoMostrada) return;
    _avaliacaoMostrada = true;

    final idAvaliado = widget.isMotoboy
        ? data['id_solicitante']?.toString() ?? ''
        : data['id_motoboy']?.toString() ?? '';

    if (idAvaliado.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => AvaliacaoSheet(
          corridaId:           widget.corridaId,
          idAvaliado:          idAvaliado,
          avaliadoPeloCliente: !widget.isMotoboy,
        ),
      ).whenComplete(() {
        if (mounted) Navigator.pop(context);
      });
    });
  }

  void _abrirGoogleMaps(double lat, double lng) async {
    final nav = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(nav)) {
      await launchUrl(nav);
    } else {
      final web = Uri.parse(
          "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmarCancelamento() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancelar Corrida?"),
        content: Text(widget.isMotoboy
            ? "A corrida voltará para a fila e outro motoboy poderá aceitá-la."
            : "Tem certeza que deseja cancelar?"),
        actions: [
          TextButton(child: const Text("Não"), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: const Text("SIM, CANCELAR",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (widget.isMotoboy) {
                await _supabase.from('corridas').update({
                  'status':      'PENDENTE',
                  'id_motoboy':  null,
                  'data_aceite': null,
                }).eq('id', widget.corridaId);
              } else {
                await _supabase.from('corridas')
                    .update({'status': 'CANCELADO'})
                    .eq('id', widget.corridaId);
              }
              if (mounted) { Navigator.pop(ctx); Navigator.pop(context); }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('corridas').stream(primaryKey: ['id']).eq('id', widget.corridaId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data   = snapshot.data!.first;
        final status = data['status'] as String? ?? 'PENDENTE';

        if (!widget.isMotoboy && status == 'ACEITO' &&
            _ultimoStatus != 'ACEITO' && _motoboyPerfil == null) {
          _carregarPerfilMotoboy();
        }

        if (status == 'FINALIZADO') {
          _mostrarAvaliacao(data);
        }

        _ultimoStatus = status;

        if (status == 'CANCELADO') {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, size: 80, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text("Corrida Cancelada",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Voltar ao Mapa"),
                  ),
                ],
              ),
            ),
          );
        }

        final pontoColeta  = LatLng(data['lat_origem']  as double, data['long_origem']  as double);
        final pontoEntrega = LatLng(data['lat_destino'] as double, data['long_destino'] as double);
        final posMotoboy = (data['lat_motoboy'] != null)
            ? LatLng(data['lat_motoboy'] as double, data['long_motoboy'] as double)
            : pontoColeta;

        final bool faseColeta = status == 'ACEITO' || status == 'PENDENTE';
        final alvoAtual  = faseColeta ? pontoColeta  : pontoEntrega;
        final textoAlvo  = faseColeta ? "Indo retirar pedido" : "Indo entregar pedido";
        final corRota    = faseColeta ? Colors.orange[700]! : Colors.blue[700]!;

        // Calcula a rota e ajusta a câmera automaticamente
        _calcularRota(posMotoboy, alvoAtual);
        WidgetsBinding.instance.addPostFrameCallback((_) => _ajustarCamera(posMotoboy, alvoAtual));

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.isMotoboy ? "Navegação" : "Rastreio em Tempo Real"),
                Text(textoAlvo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
              ],
            ),
            backgroundColor: faseColeta ? Colors.orange[800] : Colors.blue[800],
            foregroundColor: Colors.white,
            actions: [
              IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: _confirmarCancelamento),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: posMotoboy, initialZoom: 15.0),
                      children: [
                        TileLayer(
                          urlTemplate: _modoSatelite
                              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          subdomains: _modoSatelite ? const [] : const ['a', 'b', 'c', 'd'],
                        ),
                        if (_rotaPoints.isNotEmpty)
                          PolylineLayer(polylines: [
                            Polyline(
                              points: _rotaPoints, 
                              color: corRota, 
                              strokeWidth: 5.0,
                              borderColor: Colors.white,
                              borderStrokeWidth: 2.0,
                            ),
                          ]),
                        MarkerLayer(markers: [
                          // Motoboy
                          Marker(
                            point: posMotoboy, width: 80, height: 80,
                            child: Lottie.asset('assets/motoboy.json', fit: BoxFit.contain),
                          ),
                          // Alvo Atual (Loja ou Cliente)
                          Marker(
                            point: alvoAtual, width: 80, height: 80,
                            child: Column(children: [
                              SizedBox(height: 60, width: 60,
                                  child: Lottie.asset(faseColeta ? 'assets/box.json' : 'assets/location.json', fit: BoxFit.contain)),
                              Text(faseColeta ? "Loja" : "Cliente",
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                      backgroundColor: Colors.white)),
                            ]),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  if (!widget.isMotoboy && _motoboyPerfil != null)
                    CardMotoboyAceito(motoboy: _motoboyPerfil!),

                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(faseColeta ? Icons.store : Icons.home, color: corRota),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  faseColeta
                                      ? "Retirar em: ${data['endereco_origem'] ?? 'Ver no Mapa'}"
                                      : "Entregar em: ${data['endereco_destino'] ?? 'Ver no Mapa'}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (widget.isMotoboy) ...[
                          Row(children: [
                            Expanded(
                              child: SizedBox(
                                height: 55,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: faseColeta ? Colors.blue[700] : Colors.green[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: Icon(faseColeta ? Icons.play_arrow : Icons.flag),
                                  label: Text(faseColeta ? "CONFIRMAR COLETA" : "FINALIZAR ENTREGA", 
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    if (faseColeta) {
                                      _tocarAnimacaoEProsseguir('assets/receive_order.json', () async {
                                        await _supabase.from('corridas').update({'status': 'EM_VIAGEM'}).eq('id', widget.corridaId);
                                        final idCliente = data['id_solicitante']?.toString();
                                        if (idCliente != null) await NotificacaoService.corridaEmViagem(idCliente: idCliente);
                                      });
                                    } else {
                                      _tocarAnimacaoEProsseguir('assets/food_delivered.json', () async {
                                        await _supabase.from('corridas').update({
                                          'status': 'FINALIZADO',
                                          'data_finalizacao': DateTime.now().toIso8601String(),
                                        }).eq('id', widget.corridaId);
                                        final idCliente = data['id_solicitante']?.toString();
                                        if (idCliente != null) await NotificacaoService.corridaFinalizada(idCliente: idCliente);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 55, width: 60,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[800],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _abrirGoogleMaps(alvoAtual.latitude, alvoAtual.longitude),
                                child: const Icon(Icons.map),
                              ),
                            ),
                          ]),
                        ],

                        if (!widget.isMotoboy) ...[
                          if (status == 'PENDENTE')
                            const Center(child: Text("Aguardando motoboy aceitar...", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                          if (status != 'PENDENTE' && status != 'FINALIZADO')
                            SizedBox(
                              width: double.infinity, height: 50,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: () => _abrirGoogleMaps(alvoAtual.latitude, alvoAtual.longitude),
                                icon: const Icon(Icons.gps_fixed),
                                label: const Text("VER NO GPS EXTERNO"),
                              ),
                            ),
                          if (status == 'FINALIZADO')
                            const Text("Pedido Finalizado ✓", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              Positioned(
                top: 16, right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'satelite_mon',
                  backgroundColor: Colors.white,
                  onPressed: () => setState(() => _modoSatelite = !_modoSatelite),
                  child: Icon(_modoSatelite ? Icons.map : Icons.satellite_alt, color: Colors.black87),
                ),
              ),

              if (_showOverlay && _overlayAnimation != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Center(child: Lottie.asset(_overlayAnimation!, repeat: false, width: 300, height: 300)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}