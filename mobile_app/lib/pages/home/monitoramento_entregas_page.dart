import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart' hide Marker;

class MonitoramentoEntregasPage extends StatefulWidget {
  final List<Map<String, dynamic>> pedidos;

  const MonitoramentoEntregasPage({required this.pedidos, super.key});

  @override
  State<MonitoramentoEntregasPage> createState() =>
      _MonitoramentoEntregasPageState();
}

class _MonitoramentoEntregasPageState extends State<MonitoramentoEntregasPage> {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  
  int _indiceAtual = 0;
  bool _carregando = false;
  Timer? _timerLocalizacao;
  
  LatLng? _minhaPosicao;
  List<LatLng> _rotaPoints = [];
  DateTime? _ultimoCalculoRota;

  @override
  void initState() {
    super.initState();
    _iniciarBroadcastLocalizacao();
  }

  @override
  void dispose() {
    _timerLocalizacao?.cancel();
    super.dispose();
  }

  // Ajuste de câmera estilo Uber
  void _ajustarCamera(LatLng posMotoboy, LatLng alvo) {
    try {
      final bounds = LatLngBounds.fromPoints([posMotoboy, alvo]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40.0),
        ),
      );
    } catch (_) {}
  }

  // Cálculo de rota em tempo real
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

  void _iniciarBroadcastLocalizacao() {
    _timerLocalizacao = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _minhaPosicao = LatLng(pos.latitude, pos.longitude));

        // Atualiza o destino atual no mapa
        final destino = LatLng(_pedidoAtual['lat_destino'], _pedidoAtual['long_destino']);
        _calcularRota(_minhaPosicao!, destino);
        _ajustarCamera(_minhaPosicao!, destino);

        // Envia para o banco de dados para o cliente ver
        for (final p in _pedidos) {
          final st = p['status'] as String? ?? '';
          if (st == 'ACEITO' || st == 'EM_VIAGEM') {
            await _supabase.from('pedidos').update({
              'lat_motoboy':  pos.latitude,
              'long_motoboy': pos.longitude,
            }).eq('id', p['id']);
          }
        }
      } catch (_) {}
    });
  }

  Map<String, dynamic> get _pedidoAtual => _pedidos[_indiceAtual];
  List<Map<String, dynamic>> get _pedidos => widget.pedidos;
  int get _total => _pedidos.length;
  int get _finalizados => _pedidos.where((p) => p['status'] == 'FINALIZADO').length;

  @override
  Widget build(BuildContext context) {
    final status = _pedidoAtual['status'] as String? ?? 'ACEITO';
    final (corStatus, labelStatus) = _infoStatus(status);
    final destinoAtual = LatLng(_pedidoAtual['lat_destino'], _pedidoAtual['long_destino']);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Rota de Entregas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // MAPA NO TOPO (Estilo Uber)
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _minhaPosicao ?? destinoAtual,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                if (_rotaPoints.isNotEmpty)
                  PolylineLayer(polylines: [
                    Polyline(points: _rotaPoints, color: Colors.green[700]!, strokeWidth: 5, borderColor: Colors.white, borderStrokeWidth: 2),
                  ]),
                MarkerLayer(markers: [
                  if (_minhaPosicao != null)
                    Marker(
                      point: _minhaPosicao!,
                      width: 60, height: 60,
                      child: Lottie.asset('assets/motoboy.json'),
                    ),
                  Marker(
                    point: destinoAtual,
                    width: 50, height: 50,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ]),
              ],
            ),
          ),

          _BarraProgresso(finalizados: _finalizados, total: _total),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _total,
              itemBuilder: (context, i) {
                final p = _pedidos[i];
                final st = p['status'] as String? ?? 'ACEITO';
                final ativo = i == _indiceAtual;
                final (cor, label) = _infoStatus(st);

                return GestureDetector(
                  onTap: () => setState(() {
                    _indiceAtual = i;
                    _rotaPoints = []; // Limpa a rota para recalcular para o novo destino
                  }),
                  onLongPress: (st == 'FINALIZADO' || st == 'CANCELADO') ? () => _excluirPedido(i) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ativo ? Colors.green[700]! : Colors.transparent, width: 2),
                      boxShadow: [
                        if (ativo) BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))
                        else const BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: cor.withOpacity(0.15),
                        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: cor)),
                      ),
                      title: Text(p['cliente_nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(p['endereco_destino'] ?? 'Endereço não informado', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      trailing: Text('R\$ ${(p['valor_total'] ?? 0).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                    ),
                  ),
                );
              },
            ),
          ),

          if (status != 'FINALIZADO')
            _PainelAcao(
              pedido: _pedidoAtual,
              status: status,
              corStatus: corStatus,
              labelStatus: labelStatus,
              carregando: _carregando,
              onAvancar: _avancarStatus,
              onAbrirMaps: _abrirMaps,
              onWhatsApp: () {
                final tel = _pedidoAtual['cliente_tel'] as String? ?? '';
                if (tel.isNotEmpty) _abrirWhatsApp(tel);
              },
            ),

          if (status == 'FINALIZADO' && _finalizados < _total)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('PRÓXIMA ENTREGA', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _proximaEntregaPendente,
                ),
              ),
            ),
            
          if (_finalizados == _total)
             Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                onPressed: () => Navigator.pop(context),
                child: const Text('CONCLUIR ROTA', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  (Color, String) _infoStatus(String status) => switch (status) {
        'ACEITO'     => (Colors.blue, 'A caminho da coleta'),
        'EM_VIAGEM'  => (Colors.indigo, 'Em viagem'),
        'FINALIZADO' => (Colors.green, 'Entregue ✓'),
        _            => (Colors.orange, 'Pendente'),
      };

  Future<void> _excluirPedido(int indice) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir entrega?'),
        actions: [
          TextButton(child: const Text('Não'), onPressed: () => Navigator.pop(ctx, false)),
          TextButton(child: const Text('Excluir', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirmar != true) return;
    await _supabase.from('pedidos').delete().eq('id', _pedidos[indice]['id']);
    setState(() {
      _pedidos.removeAt(indice);
      if (_pedidos.isEmpty) Navigator.pop(context);
      else _indiceAtual = _indiceAtual.clamp(0, _pedidos.length - 1);
    });
  }

  void _abrirWhatsApp(String tel) async {
    final numero = tel.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/55$numero');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _avancarStatus() async {
    setState(() => _carregando = true);
    final status = _pedidoAtual['status'] as String? ?? 'ACEITO';
    final novoStatus = status == 'ACEITO' ? 'EM_VIAGEM' : 'FINALIZADO';
    try {
      await _supabase.from('pedidos').update({
        'status': novoStatus,
        if (novoStatus == 'FINALIZADO') 'data_finalizacao': DateTime.now().toIso8601String(),
      }).eq('id', _pedidoAtual['id']);
      setState(() => _pedidos[_indiceAtual]['status'] = novoStatus);
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _proximaEntregaPendente() {
    for (int i = 0; i < _total; i++) {
      if (_pedidos[i]['status'] != 'FINALIZADO') {
        setState(() => _indiceAtual = i);
        return;
      }
    }
  }

  void _abrirMaps() async {
    final lat = _pedidoAtual['lat_destino'];
    final lng = _pedidoAtual['long_destino'];
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// Widgets internos (_BarraProgresso e _PainelAcao permanecem iguais à sua lógica anterior)
class _BarraProgresso extends StatelessWidget {
  final int finalizados; final int total;
  const _BarraProgresso({required this.finalizados, required this.total});
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : finalizados / total;
    return Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progresso', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          Text('$finalizados/$total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: Colors.grey[200], color: Colors.green[600]),
      ]),
    );
  }
}

class _PainelAcao extends StatelessWidget {
  final Map<String, dynamic> pedido; final String status; final Color corStatus; final String labelStatus; final bool carregando;
  final VoidCallback onAvancar; final VoidCallback onAbrirMaps; final VoidCallback onWhatsApp;
  const _PainelAcao({required this.pedido, required this.status, required this.corStatus, required this.labelStatus, required this.carregando, required this.onAvancar, required this.onAbrirMaps, required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    final botaoLabel = status == 'ACEITO' ? 'CONFIRMAR COLETA' : 'CONFIRMAR ENTREGA';
    final botaoCor = status == 'ACEITO' ? Colors.blue[700]! : Colors.green[700]!;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(labelStatus, style: TextStyle(color: corStatus, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(status == 'ACEITO' ? 'Retirar em: ${pedido['comercio_nome'] ?? 'Loja'}' : 'Entregar para: ${pedido['cliente_nome']}\n${pedido['endereco_destino']}', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: SizedBox(height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: botaoCor, foregroundColor: Colors.white), onPressed: carregando ? null : onAvancar, child: carregando ? const CircularProgressIndicator(color: Colors.white) : Text(botaoLabel, style: const TextStyle(fontWeight: FontWeight.bold))))),
          const SizedBox(width: 8),
          IconButton.filled(style: IconButton.styleFrom(backgroundColor: Colors.orange[700]), onPressed: onAbrirMaps, icon: const Icon(Icons.map)),
          IconButton.filled(style: IconButton.styleFrom(backgroundColor: Colors.green[600]), onPressed: onWhatsApp, icon: const Icon(Icons.chat)),
        ]),
      ]),
    );
  }
}