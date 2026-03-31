import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/user_provider.dart';
import 'components/home_drawer.dart';
import 'components/home_fab.dart';
import 'components/active_ride_banner.dart';
import 'components/pending_ride_banner.dart';
import '../../widgets/solicitar_corrida_sheet.dart';
import '../../widgets/detalhes_corrida_sheet.dart';
import '../../widgets/lote_entregas_sheet.dart';
import 'selecionar_destino_page.dart';
import 'monitoramento_page.dart';

class MapaPage extends ConsumerStatefulWidget {
  @override
  _MapaPageState createState() => _MapaPageState();
}

class _MapaPageState extends ConsumerState<MapaPage> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _supabase = Supabase.instance.client;

  LatLng? _localizacaoAtual;
  bool _permissaoNegada    = false;
  bool _modoTrabalhoAtivo  = false;
  bool _modoSatelite       = false;

  // Corridas ativas do usuário (como solicitante ou motoboy)
  List<String> _idsCorridasAtivas = [];
  String? _idSolicitacaoPendente;

  // Pedidos comerciais (Supabase — merchant_web)
  List<Map<String, dynamic>> _pedidosComerciais = [];
  int _quantidadePedidosAnterior = 0;


  // Corridas PENDENTE de qualquer cliente — motoboy vê no radar
  List<Map<String, dynamic>> _corridasPendentesRadar = [];

  // Canal realtime para INSERT imediato de novas corridas
  RealtimeChannel? _canalNovasCorridas;

  @override
  void initState() {
    super.initState();
    _buscarLocalizacaoAtual();
    _ouvirPedidosComerciais();
    _ouvirCorridasAtivas();
    _ouvirNovasCorridasChannel();
  }

  @override
  void dispose() {
    _canalNovasCorridas?.unsubscribe();
    super.dispose();
  }

  // --- Radar de pedidos comerciais (merchant_web) ---
  void _ouvirPedidosComerciais() {
    _supabase
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('status', 'PENDENTE')
        .order('criado_em')
        .listen((List<Map<String, dynamic>> data) {
          if (!mounted) return;
          if (data.length > _quantidadePedidosAnterior && _modoTrabalhoAtivo) {
            _audioPlayer.play(AssetSource('alert.mp3'));
          }
          setState(() {
            _pedidosComerciais = data;
            _quantidadePedidosAnterior = data.length;
          });
        });
  }

  // --- Canal Realtime para INSERT imediato de novas corridas ---
  void _ouvirNovasCorridasChannel() {
    _canalNovasCorridas = _supabase
        .channel('novas-corridas')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'corridas',
          callback: (payload) {
            if (!mounted) return;
            final nova = payload.newRecord;
            if (nova['status'] == 'PENDENTE') {
              setState(() {
                // Adiciona imediatamente ao radar sem esperar o stream
                if (!_corridasPendentesRadar.any((c) => c['id'] == nova['id'])) {
                  _corridasPendentesRadar = [..._corridasPendentesRadar, nova];
                }
              });
              if (_modoTrabalhoAtivo) {
                _audioPlayer.play(AssetSource('alert.mp3'));
              }
            }
          },
        )
        .subscribe();
  }

  // --- Radar de corridas do app ---
  void _ouvirCorridasAtivas() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase
        .from('corridas')
        .stream(primaryKey: ['id'])
        .inFilter('status', ['PENDENTE', 'ACEITO', 'A_CAMINHO_COLETA', 'EM_VIAGEM'])
        .listen((List<Map<String, dynamic>> data) {
          if (!mounted) return;

          final ativas = data
              .where((c) => c['id_solicitante'] == userId || c['id_motoboy'] == userId)
              .toList();

          final pendentes = data
              .where((c) => c['id_solicitante'] == userId && c['status'] == 'PENDENTE')
              .toList();

          // Auto-navegar para rastreio quando motoboy aceitar
          final antigoIdPendente = _idSolicitacaoPendente;
          if (antigoIdPendente != null) {
            final aceita = ativas.where((c) =>
                c['id'].toString() == antigoIdPendente &&
                c['status'] == 'ACEITO' &&
                c['id_motoboy'] != null).firstOrNull;
            if (aceita != null) {
              final idParaNavegar = antigoIdPendente;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MonitoramentoPage(
                        corridaId: idParaNavegar,
                        isMotoboy: false,
                      ),
                    ),
                  ).then((_) {
                    if (mounted) setState(() => _idsCorridasAtivas = []);
                  });
                }
              });
            }
          }

          // Todas as corridas PENDENTE visíveis — motoboy usa no radar
          final todasPendentes = data
              .where((c) => c['status'] == 'PENDENTE')
              .toList();

          setState(() {
            _corridasPendentesRadar = todasPendentes;
            _idsCorridasAtivas = ativas
                .where((c) => c['status'] != 'PENDENTE' || c['id_motoboy'] != null)
                .map((c) => c['id'].toString())
                .toList();
            _idSolicitacaoPendente = pendentes.isNotEmpty ? pendentes.first['id'].toString() : null;
          });
        });
  }

  Future<void> _buscarLocalizacaoAtual() async {
    bool servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) return;
    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied) {
        if (mounted) setState(() => _permissaoNegada = true);
        return;
      }
    }
    Position posicao = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() { _localizacaoAtual = LatLng(posicao.latitude, posicao.longitude); });
      try { _mapController.move(_localizacaoAtual!, 15.0); } catch (e) {}
    }
  }

  void _toggleModoTrabalho(bool val) async {
    if (!val) {
      setState(() => _modoTrabalhoAtivo = false);
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final data = await _supabase
        .from('usuarios')
        .select('validade_assinatura')
        .eq('id', userId)
        .maybeSingle();

    if (!mounted) return;

    final validade = data?['validade_assinatura'];
    if (validade != null && DateTime.parse(validade).isAfter(DateTime.now())) {
      setState(() => _modoTrabalhoAtivo = true);
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Assinatura Vencida 🚫"),
          content: Text("Sua assinatura expirou. Renove para receber corridas."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
        ),
      );
      setState(() => _modoTrabalhoAtivo = false);
    }
  }

  Future<void> _abrirModalPedido() async {
    if (_localizacaoAtual == null) return;
    if (_idSolicitacaoPendente != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Você já tem um pedido aguardando!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Passo 1 — tela de busca/confirmação do destino (padrão Uber)
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelecionarDestinoPage(
          latInicial: _localizacaoAtual!.latitude,
          longInicial: _localizacaoAtual!.longitude,
        ),
      ),
    );

    if (resultado == null || !mounted) return;

    final ponto    = resultado['ponto'];
    final endereco = (resultado['endereco'] as String? ?? '').isNotEmpty
        ? resultado['endereco'] as String
        : 'Destino selecionado no mapa';

    // Passo 2 — sheet de confirmação (preço + pagamento)
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SolicitarCorridaSheet(
        latOrigem:       _localizacaoAtual!.latitude,
        longOrigem:      _localizacaoAtual!.longitude,
        latDestino:      (ponto.latitude  as num).toDouble(),
        longDestino:     (ponto.longitude as num).toDouble(),
        enderecoDestino: endereco,
      ),
    );
  }

  void _abrirLoteEntregas(List<Map<String, dynamic>> pedidosDoComercio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => LoteEntregasSheet(pedidos: pedidosDoComercio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    String tipoConta = 'CLIENTE';
    userProfileAsync.whenData((perfil) {
      if (perfil != null) {
        tipoConta = perfil['tipo']?.toString().toUpperCase() ?? 'CLIENTE';
      }
    });

    bool souMotoboy = tipoConta == 'MOTOBOY';
    bool souMotoboyTrabalhando = souMotoboy && _modoTrabalhoAtivo;
    Color corPrincipal = souMotoboy ? Colors.green[700]! : Colors.blue[700]!;

    return Scaffold(
      key: _scaffoldKey,
      drawer: HomeDrawer(souMotoboy: souMotoboy, corTema: corPrincipal),
      appBar: AppBar(
        title: Text(souMotoboyTrabalhando ? "Radar 🏍️" : "Solicitar 📦"),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        actions: [
          if (souMotoboy)
            Row(children: [
              Text(_modoTrabalhoAtivo ? "ON" : "OFF", style: TextStyle(fontWeight: FontWeight.bold)),
              Switch(
                value: _modoTrabalhoAtivo,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.greenAccent,
                onChanged: _toggleModoTrabalho,
              ),
            ]),
        ],
      ),
      body: Stack(
        children: [
          _conteudoDoMapa(souMotoboyTrabalhando, tipoConta),
          // Botão satélite
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'satelite',
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: () => setState(() => _modoSatelite = !_modoSatelite),
              child: Icon(
                _modoSatelite ? Icons.map : Icons.satellite_alt,
                color: Colors.black87,
              ),
            ),
          ),
          ActiveRideBanner(idsCorridasAtivas: _idsCorridasAtivas, souMotoboy: souMotoboy),
          if (_idsCorridasAtivas.isEmpty)
            PendingRideBanner(
              idSolicitacaoPendente: _idSolicitacaoPendente,
              onCancelado: () => setState(() => _idSolicitacaoPendente = null),
            ),
        ],
      ),
      floatingActionButton: _idSolicitacaoPendente == null
          ? HomeFab(
              souMotoboyTrabalhando: souMotoboyTrabalhando,
              temLocalizacao: _localizacaoAtual != null,
              onCentralizar: _buscarLocalizacaoAtual,
              onNovoPedido: _abrirModalPedido,
            )
          : null,
      floatingActionButtonLocation: !souMotoboyTrabalhando
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _conteudoDoMapa(bool souMotoboyTrabalhando, String tipoConta) {
    if (_permissaoNegada) return Center(child: Text("Sem permissão de GPS"));
    if (_localizacaoAtual == null) return Center(child: CircularProgressIndicator());

    List<Marker> marcadores = [];
    // Usa _idSolicitacaoPendente diretamente — já é zerado no cancelamento
    final clienteEstaAguardando = _idSolicitacaoPendente != null;

    // Marcadores de pedidos comerciais agrupados por comércio
    if (souMotoboyTrabalhando) {
      // Agrupa pedidos pelo comercio_id
      final Map<String, List<Map<String, dynamic>>> porComercio = {};
      for (final p in _pedidosComerciais) {
        final cid = p['comercio_id'] as String? ?? 'unknown';
        porComercio.putIfAbsent(cid, () => []).add(p);
      }

      for (final entry in porComercio.entries) {
        final pedidos  = entry.value;
        final primeiro = pedidos.first;
        // Mostra a caixa na origem (comércio), não no destino
        final lat = (primeiro['lat_origem'] ?? primeiro['lat_destino'])?.toDouble();
        final lng = (primeiro['long_origem'] ?? primeiro['long_destino'])?.toDouble();
        if (lat == null || lng == null) continue;

        final qtd         = pedidos.length;
        final totalValor  = pedidos.fold<double>(
            0, (s, p) => s + (p['valor_total'] ?? 0).toDouble());

        marcadores.add(Marker(
          point: LatLng(lat, lng),
          width: 180,
          height: 180,
          child: GestureDetector(
            onTap: () => _abrirLoteEntregas(pedidos),
            child: MarcadorPulo(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      SizedBox(height: 100, width: 100,
                          child: Lottie.asset('assets/box.json', fit: BoxFit.contain)),
                      if (qtd > 1)
                        Positioned(
                          top: 0, right: 0,
                          child: Container(
                            width: 26, height: 26,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('$qtd',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[900],
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                    ),
                    child: Text(
                      qtd > 1
                          ? '$qtd entregas · R\$ ${totalValor.toStringAsFixed(0)}'
                          : 'R\$ ${totalValor.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }

    // Marcadores de corridas PENDENTE do app — motoboy vê de todos os clientes
    for (final corrida in _corridasPendentesRadar) {
      final status = corrida['status'] ?? 'PENDENTE';

      if (souMotoboyTrabalhando && status == 'PENDENTE' && corrida['lat_origem'] != null) {
        marcadores.add(Marker(
          point: LatLng(corrida['lat_origem'].toDouble(), corrida['long_origem'].toDouble()),
          width: 180,
          height: 180,
          child: GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => DetalhesCorridaSheet(pedido: corrida),
            ),
            child: MarcadorPulo(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 120, width: 120, child: Lottie.asset('assets/box.json', fit: BoxFit.contain)),
                  Text("PEDIDO APP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white)),
                ],
              ),
            ),
          ),
        ));
      }
    }

    // Marcador do usuário atual
    marcadores.add(Marker(
      point: _localizacaoAtual!,
      width: 120,
      height: 120,
      child: Column(children: [
        _iconeDoUsuario(clienteEstaAguardando, tipoConta),
        Text("Eu", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white)),
      ]),
    ));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: _localizacaoAtual!, initialZoom: 15.0),
      children: [
        TileLayer(
          urlTemplate: _modoSatelite
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: _modoSatelite ? const [] : const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.appdeliverymoto',
        ),
        MarkerLayer(markers: marcadores),
      ],
    );
  }

  Widget _iconeDoUsuario(bool clienteAguardando, String tipoConta) {
    if (clienteAguardando) return SizedBox(height: 80, width: 80, child: Lottie.asset('assets/waiting.json', fit: BoxFit.contain));
    if (tipoConta == 'MOTOBOY') return SizedBox(height: 100, width: 100, child: Lottie.asset('assets/motoboy.json', fit: BoxFit.contain));
    return SizedBox(height: 70, width: 70, child: Lottie.asset('assets/person.json', fit: BoxFit.contain));
  }
}

class MarcadorPulo extends StatefulWidget {
  final Widget child;
  const MarcadorPulo({required this.child, super.key});
  @override State<MarcadorPulo> createState() => _MarcadorPuloState();
}

class _MarcadorPuloState extends State<MarcadorPulo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: -15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(offset: Offset(0, _animation.value), child: widget.child),
    );
  }
}
