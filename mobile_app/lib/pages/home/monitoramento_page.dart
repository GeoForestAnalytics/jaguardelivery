import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart' hide Marker; // IMPORTANTE: Lottie com hide Marker

class MonitoramentoPage extends StatefulWidget {
  final String corridaId;
  final bool isMotoboy;

  const MonitoramentoPage({required this.corridaId, required this.isMotoboy});

  @override
  _MonitoramentoPageState createState() => _MonitoramentoPageState();
}

class _MonitoramentoPageState extends State<MonitoramentoPage> {
  final MapController _mapController = MapController();
  List<LatLng> _rotaPoints = [];
  Timer? _timerLocalizacaoMotoboy;
  DateTime? _ultimoCalculoRota; 
  
  // Controle de Animação de Overlay
  String? _overlayAnimation; 
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    if (widget.isMotoboy) {
      _iniciarBroadcastDeLocalizacao();
    }
  }

  @override
  void dispose() {
    _timerLocalizacaoMotoboy?.cancel();
    super.dispose();
  }

  // --- Função para tocar animação tela cheia ---
  void _tocarAnimacaoEProsseguir(String jsonAsset, Function onFinish) {
    setState(() {
      _overlayAnimation = jsonAsset;
      _showOverlay = true;
    });

    // Tempo da animação (ajuste conforme a duração do seu Lottie, aprox 3 a 4s)
    Timer(Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showOverlay = false;
          _overlayAnimation = null;
        });
        onFinish(); // Executa a ação (Atualizar banco)
      }
    });
  }

  void _iniciarBroadcastDeLocalizacao() {
    _timerLocalizacaoMotoboy = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition();
        await FirebaseFirestore.instance.collection('corridas').doc(widget.corridaId).update({
          'lat_motoboy': position.latitude,
          'long_motoboy': position.longitude,
        });
      } catch (e) { print(e); }
    });
  }

  Future<void> _calcularRota(LatLng inicio, LatLng fim) async {
    if (_ultimoCalculoRota != null && DateTime.now().difference(_ultimoCalculoRota!).inSeconds < 5) return;
    double distancia = Geolocator.distanceBetween(inicio.latitude, inicio.longitude, fim.latitude, fim.longitude);
    if (distancia < 20) return; 

    _ultimoCalculoRota = DateTime.now();
    final url = Uri.parse("https://router.project-osrm.org/route/v1/driving/${inicio.longitude},${inicio.latitude};${fim.longitude},${fim.latitude}?overview=full&geometries=geojson");
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry']['coordinates'] as List;
          if (mounted) setState(() => _rotaPoints = geometry.map((p) => LatLng(p[1], p[0])).toList());
        }
      }
    } catch (e) { print(e); }
  }

  void _abrirGoogleMaps(double latDestino, double longDestino) async {
    final url = Uri.parse("google.navigation:q=$latDestino,$longDestino&mode=d");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final fallbackUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$latDestino,$longDestino&travelmode=driving");
      await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmarCancelamento() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Cancelar Corrida?"),
        content: Text("Tem certeza que deseja cancelar?"),
        actions: [
          TextButton(child: Text("Não"), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text("SIM, CANCELAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('corridas').doc(widget.corridaId).update({'status': 'CANCELADO'});
              Navigator.pop(ctx); 
              Navigator.pop(context); // Sai da tela de monitoramento
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('corridas').doc(widget.corridaId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Scaffold(body: Center(child: CircularProgressIndicator()));

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status']; 
        
        if (status == 'CANCELADO') return Scaffold(body: Center(child: Text("Corrida Cancelada")));

        LatLng pontoColeta = LatLng(data['lat_origem'], data['long_origem']);
        LatLng pontoEntrega = LatLng(data['lat_destino'], data['long_destino']);
        
        LatLng posMotoboy = (data['lat_motoboy'] != null)
            ? LatLng(data['lat_motoboy'], data['long_motoboy'])
            : pontoColeta; 

        LatLng alvoAtual;
        String textoAlvo;
        Color corRota;

        if (status == 'ACEITO' || status == 'PENDENTE') { // Se pendente, rota vai pra coleta
          alvoAtual = pontoColeta;
          textoAlvo = "Indo para Coleta";
          corRota = Colors.orange; 
        } else {
          alvoAtual = pontoEntrega;
          textoAlvo = "Indo para Entrega";
          corRota = Colors.blue;
        }

        // Só calcula rota se não for PENDENTE (ou se quiser mostrar pro cliente o trajeto)
        // Vamos deixar calculando sempre pra ficar bonito
        _calcularRota(posMotoboy, alvoAtual);

        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.isMotoboy ? "Navegação" : "Rastreio"), Text(textoAlvo, style: TextStyle(fontSize: 12))]),
            backgroundColor: status == 'ACEITO' ? Colors.orange[800] : Colors.blue[800],
            foregroundColor: Colors.white,
            actions: [
              // Botão de cancelar no topo também (Sempre bom ter backup)
              IconButton(icon: Icon(Icons.cancel_outlined), onPressed: _confirmarCancelamento)
            ],
          ),
          
          body: Stack(
            children: [
              // --- 1. CONTEÚDO PRINCIPAL (MAPA E PAINEL) ---
              Column(
                children: [
                  Expanded(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: posMotoboy, 
                        initialZoom: 14.0,
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                        
                        if (_rotaPoints.isNotEmpty)
                          PolylineLayer(polylines: [Polyline(points: _rotaPoints, color: corRota, strokeWidth: 5.0)]),
                        
                        MarkerLayer(
                          markers: [
                            // Marcador do Motoboy (Agora Animado)
                            Marker(
                              point: posMotoboy,
                              width: 80, height: 80,
                              child: Lottie.asset('assets/motoboy.json', fit: BoxFit.contain),
                            ),
                            
                            // Marcador de Coleta (BOX)
                            if (status == 'ACEITO' || status == 'PENDENTE')
                              Marker(
                                point: pontoColeta,
                                width: 80, height: 80,
                                child: Column(
                                  children: [
                                    SizedBox(height: 60, width: 60, child: Lottie.asset('assets/box.json', fit: BoxFit.contain)),
                                    Text("Coleta", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white))
                                  ],
                                ),
                              ),
                            
                            // Marcador de Entrega (LOCATION)
                            if (status == 'EM_VIAGEM' || status == 'FINALIZADO')
                              Marker(
                                point: pontoEntrega,
                                width: 80, height: 80,
                                child: Column(
                                  children: [
                                    SizedBox(height: 60, width: 60, child: Lottie.asset('assets/location.json', fit: BoxFit.contain)),
                                    Text("Entrega", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white))
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // PAINEL INFERIOR
                  Container(
                    width: double.infinity, 
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
                    ),
                    child: Center( 
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 500), 
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // INFO DO LOCAL
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Icon(status == 'ACEITO' || status == 'PENDENTE' ? Icons.store : Icons.home, color: Colors.grey[700]),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      status == 'ACEITO' || status == 'PENDENTE'
                                          ? "Coletar em: \n${data['endereco_origem'] ?? 'Ver no Mapa'}" 
                                          : "Entregar em: \n${data['endereco_destino']}",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 15),
                            
                            // BOTÕES DO MOTOBOY
                            if (widget.isMotoboy) 
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(height: 50, child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: status == 'ACEITO' ? Colors.blue : Colors.red, foregroundColor: Colors.white),
                                        icon: Icon(status == 'ACEITO' ? Icons.play_arrow : Icons.flag),
                                        label: Text(status == 'ACEITO' ? "INICIAR" : "FINALIZAR"),
                                        onPressed: () {
                                           if (status == 'ACEITO') {
                                              // Toca animação de "Check" (receive_order)
                                              _tocarAnimacaoEProsseguir('assets/receive_order.json', () {
                                                  FirebaseFirestore.instance.collection('corridas').doc(widget.corridaId).update({'status': 'EM_VIAGEM'});
                                              });
                                           } else {
                                              // Toca animação de "Entregue" (food_delivered)
                                              _tocarAnimacaoEProsseguir('assets/food_delivered.json', () {
                                                  FirebaseFirestore.instance.collection('corridas').doc(widget.corridaId).update({
                                                    'status': 'FINALIZADO',
                                                    'data_finalizacao': FieldValue.serverTimestamp(),
                                                  });
                                                  Navigator.pop(context); // Fecha a tela de monitoramento após finalizar
                                              });
                                           }
                                        },
                                    )),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(height: 50, child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                                        onPressed: () => _abrirGoogleMaps(alvoAtual.latitude, alvoAtual.longitude),
                                        icon: Icon(Icons.map),
                                        label: Text("GPS"),
                                    )),
                                  ),
                                ],
                              ),
                            
                            // BOTÕES DO CLIENTE (CANCELAR SE PENDENTE)
                            if (!widget.isMotoboy && status == 'PENDENTE') ...[
                               Text("Aguardando um motoboy aceitar...", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                               SizedBox(height: 10),
                               SizedBox(
                                 width: double.infinity, 
                                 height: 50,
                                 child: ElevatedButton.icon(
                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                   icon: Icon(Icons.cancel),
                                   label: Text("CANCELAR PEDIDO"),
                                   onPressed: _confirmarCancelamento, 
                                 ),
                               ),
                            ],

                            // BOTÃO GPS PARA O CLIENTE TAMBÉM (SE JÁ ACEITO)
                            if (!widget.isMotoboy && status != 'PENDENTE')
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: () => _abrirGoogleMaps(alvoAtual.latitude, alvoAtual.longitude),
                                  icon: Icon(Icons.map), 
                                  label: Text("Acompanhar no GPS"),
                                ),
                              ),
                            
                            // Botão cancelar para Motoboy também (emergência)
                            if(widget.isMotoboy) ...[
                               SizedBox(height: 10),
                               SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _confirmarCancelamento, child: Text("CANCELAR CORRIDA", style: TextStyle(color: Colors.red)))),
                            ]
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),

              // --- 2. CAMADA DE OVERLAY (ANIMAÇÃO TELA CHEIA) ---
              if (_showOverlay && _overlayAnimation != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.7), // Fundo escuro transparente
                    child: Center(
                      child: Lottie.asset(
                        _overlayAnimation!,
                        repeat: false, // Toca uma vez só
                        width: 300,
                        height: 300,
                      ),
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