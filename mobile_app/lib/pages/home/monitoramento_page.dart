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

  // Perfil do motoboy (carregado para o cliente)
  Map<String, dynamic>? _motoboyPerfil;
  String? _ultimoStatus; // para detectar mudanças de status

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

  // ─── Perfil do motoboy (para cliente) ──────────────────────────────────────

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

  // ─── Broadcast de localização (motoboy) ────────────────────────────────────

  void _iniciarBroadcastDeLocalizacao() {
    _timerLocalizacaoMotoboy = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition();
        await _supabase.from('corridas').update({
          'lat_motoboy':  position.latitude,
          'long_motoboy': position.longitude,
        }).eq('id', widget.corridaId);
      } catch (_) {}
    });
  }

  // ─── Rota OSRM ─────────────────────────────────────────────────────────────

  Future<void> _calcularRota(LatLng inicio, LatLng fim) async {
    if (_ultimoCalculoRota != null &&
        DateTime.now().difference(_ultimoCalculoRota!).inSeconds < 5) return;

    if (Geolocator.distanceBetween(
            inicio.latitude, inicio.longitude, fim.latitude, fim.longitude) < 20) return;

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

  // ─── Animação de transição ──────────────────────────────────────────────────

  void _tocarAnimacaoEProsseguir(String jsonAsset, Future<void> Function() onFinish) {
    setState(() { _overlayAnimation = jsonAsset; _showOverlay = true; });
    Timer(Duration(seconds: 4), () async {
      if (mounted) {
        setState(() { _showOverlay = false; _overlayAnimation = null; });
        await onFinish();
      }
    });
  }

  // ─── Avaliação ─────────────────────────────────────────────────────────────

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
        shape: RoundedRectangleBorder(
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

  // ─── Google Maps externo ────────────────────────────────────────────────────

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

  // ─── Cancelamento ───────────────────────────────────────────────────────────

  void _confirmarCancelamento() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Cancelar Corrida?"),
        content: Text(widget.isMotoboy
            ? "A corrida voltará para a fila e outro motoboy poderá aceitá-la."
            : "Tem certeza que deseja cancelar?"),
        actions: [
          TextButton(child: Text("Não"), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text("SIM, CANCELAR",
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

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('corridas').stream(primaryKey: ['id']).eq('id', widget.corridaId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data   = snapshot.data!.first;
        final status = data['status'] as String? ?? 'PENDENTE';

        // Detecta mudança de status para recarregar perfil do motoboy
        if (!widget.isMotoboy && status == 'ACEITO' &&
            _ultimoStatus != 'ACEITO' && _motoboyPerfil == null) {
          _carregarPerfilMotoboy();
        }

        // Mostra avaliação ao finalizar
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
                  SizedBox(height: 16),
                  Text("Corrida Cancelada",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Voltar ao Mapa"),
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
        final textoAlvo  = faseColeta ? "Indo para Coleta" : "Indo para Entrega";
        final corRota    = faseColeta ? Colors.orange : Colors.blue;

        _calcularRota(posMotoboy, alvoAtual);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.isMotoboy ? "Navegação" : "Rastreio ao Vivo"),
                Text(textoAlvo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
              ],
            ),
            backgroundColor: faseColeta ? Colors.orange[800] : Colors.blue[800],
            foregroundColor: Colors.white,
            actions: [
              IconButton(icon: Icon(Icons.cancel_outlined), onPressed: _confirmarCancelamento),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // ── Mapa ───────────────────────────────────────────────────
                  Expanded(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: posMotoboy, initialZoom: 14.0),
                      children: [
                        TileLayer(
                          urlTemplate: _modoSatelite
                              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          subdomains: _modoSatelite ? const [] : const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.example.appdeliverymoto',
                        ),
                        if (_rotaPoints.isNotEmpty)
                          PolylineLayer(polylines: [
                            Polyline(points: _rotaPoints, color: corRota, strokeWidth: 5.0),
                          ]),
                        MarkerLayer(markers: [
                          // Motoboy
                          Marker(
                            point: posMotoboy, width: 80, height: 80,
                            child: Lottie.asset('assets/motoboy.json', fit: BoxFit.contain),
                          ),
                          // Ponto de coleta
                          if (faseColeta)
                            Marker(
                              point: pontoColeta, width: 80, height: 80,
                              child: Column(children: [
                                SizedBox(height: 60, width: 60,
                                    child: Lottie.asset('assets/box.json', fit: BoxFit.contain)),
                                Text("Coleta",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                        backgroundColor: Colors.white)),
                              ]),
                            ),
                          // Ponto de entrega
                          if (!faseColeta)
                            Marker(
                              point: pontoEntrega, width: 80, height: 80,
                              child: Column(children: [
                                SizedBox(height: 60, width: 60,
                                    child: Lottie.asset('assets/location.json', fit: BoxFit.contain)),
                                Text("Entrega",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                        backgroundColor: Colors.white)),
                              ]),
                            ),
                        ]),
                      ],
                    ),
                  ),

                  // ── Card do motoboy (para o cliente) ───────────────────────
                  if (!widget.isMotoboy && _motoboyPerfil != null)
                    CardMotoboyAceito(motoboy: _motoboyPerfil!),

                  // ── Painel inferior ────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 500),
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Endereço atual
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Icon(
                                    faseColeta ? Icons.store : Icons.home,
                                    color: Colors.grey[700],
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      faseColeta
                                          ? "Coletar em:\n${data['endereco_origem'] ?? 'Ver no Mapa'}"
                                          : "Entregar em:\n${data['endereco_destino'] ?? 'Ver no Mapa'}",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),

                            // ── Botões do MOTOBOY ──────────────────────────
                            if (widget.isMotoboy) ...[
                              Row(children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            faseColeta ? Colors.blue : Colors.green[700],
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: Icon(faseColeta ? Icons.play_arrow : Icons.flag),
                                      label: Text(faseColeta ? "INICIAR" : "FINALIZAR"),
                                      onPressed: () async {
                                        if (faseColeta) {
                                          _tocarAnimacaoEProsseguir(
                                            'assets/receive_order.json',
                                            () async {
                                              await _supabase.from('corridas')
                                                  .update({'status': 'EM_VIAGEM'})
                                                  .eq('id', widget.corridaId);
                                              // Notifica cliente
                                              final idCliente = data['id_solicitante']?.toString();
                                              if (idCliente != null) {
                                                await NotificacaoService.corridaEmViagem(
                                                    idCliente: idCliente);
                                              }
                                            },
                                          );
                                        } else {
                                          _tocarAnimacaoEProsseguir(
                                            'assets/food_delivered.json',
                                            () async {
                                              await _supabase.from('corridas').update({
                                                'status':           'FINALIZADO',
                                                'data_finalizacao': DateTime.now().toIso8601String(),
                                              }).eq('id', widget.corridaId);
                                              // Notifica cliente
                                              final idCliente = data['id_solicitante']?.toString();
                                              if (idCliente != null) {
                                                await NotificacaoService.corridaFinalizada(
                                                    idCliente: idCliente);
                                              }
                                              // Pop é feito via _mostrarAvaliacao.whenComplete
                                            },
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[800],
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _abrirGoogleMaps(
                                          alvoAtual.latitude, alvoAtual.longitude),
                                      icon: Icon(Icons.map),
                                      label: Text("GPS"),
                                    ),
                                  ),
                                ),
                              ]),
                              SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _confirmarCancelamento,
                                  child: Text("CANCELAR CORRIDA",
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ),
                            ],

                            // ── Botões do CLIENTE ──────────────────────────
                            if (!widget.isMotoboy) ...[
                              if (status == 'PENDENTE') ...[
                                Text("Aguardando motoboy aceitar...",
                                    style: TextStyle(
                                        color: Colors.orange, fontWeight: FontWeight.bold)),
                                SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity, height: 50,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    icon: Icon(Icons.cancel),
                                    label: Text("CANCELAR PEDIDO"),
                                    onPressed: _confirmarCancelamento,
                                  ),
                                ),
                              ],
                              if (status != 'PENDENTE' && status != 'FINALIZADO')
                                SizedBox(
                                  width: double.infinity, height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _abrirGoogleMaps(
                                        alvoAtual.latitude, alvoAtual.longitude),
                                    icon: Icon(Icons.map),
                                    label: Text("Acompanhar no GPS"),
                                  ),
                                ),
                              if (status == 'FINALIZADO')
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green[200]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green[700]),
                                      SizedBox(width: 8),
                                      Text("Entregue com sucesso! 🎉",
                                          style: TextStyle(
                                              color: Colors.green[800],
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Botão satélite
              Positioned(
                top: 16, right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'satelite_mon',
                  backgroundColor: Colors.white,
                  elevation: 4,
                  onPressed: () => setState(() => _modoSatelite = !_modoSatelite),
                  child: Icon(
                    _modoSatelite ? Icons.map : Icons.satellite_alt,
                    color: Colors.black87,
                  ),
                ),
              ),

              // Overlay de animação
              if (_showOverlay && _overlayAnimation != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Center(
                      child: Lottie.asset(_overlayAnimation!, repeat: false,
                          width: 300, height: 300),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
