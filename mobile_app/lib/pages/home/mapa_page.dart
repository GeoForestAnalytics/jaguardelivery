import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:lottie/lottie.dart' hide Marker; 
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
// --- NOVO IMPORT SUPABASE ---
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/user_provider.dart';

// Componentes
import 'components/home_drawer.dart';
import 'components/home_fab.dart';
import 'components/active_ride_banner.dart';
import 'components/pending_ride_banner.dart'; 

import '../../widgets/solicitar_corrida_sheet.dart'; 
import '../../widgets/detalhes_corrida_sheet.dart'; 

class MapaPage extends ConsumerStatefulWidget {
  @override
  _MapaPageState createState() => _MapaPageState();
}

class _MapaPageState extends ConsumerState<MapaPage> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); 
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // --- CLIENTE SUPABASE ---
  final supabase = Supabase.instance.client;
  List<Marker> _marcadoresSupabase = []; 

  LatLng? _localizacaoAtual;
  bool _permissaoNegada = false;
  bool _modoTrabalhoAtivo = false; 
  
  List<String> _idsCorridasAtivas = []; 
  String? _idSolicitacaoPendente; 
  int _quantidadePedidosAnterior = 0; 

  @override
  void initState() {
    super.initState();
    _inicializarTudo();
    _ouvirPedidosSupabase(); // Inicia o radar do Next.js
  }

  void _inicializarTudo() async {
    await _buscarLocalizacaoAtual();
    _verificarCorridasAtivas(); 
    _verificarMinhaSolicitacao();  
  }

  // --- LÓGICA DO RADAR SUPABASE (NEXT.JS) ---
  void _ouvirPedidosSupabase() {
    supabase
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('status', 'PENDENTE')
        .listen((List<Map<String, dynamic>> data) {
          if (!mounted) return;

          // Alerta sonoro se entrar pedido novo
          if (data.length > _marcadoresSupabase.length && _modoTrabalhoAtivo) {
            _audioPlayer.play(AssetSource('alert.mp3'));
          }

          setState(() {
            _marcadoresSupabase = data.map((pedido) {
              return Marker(
                point: LatLng(pedido['lat_destino'] ?? 0.0, pedido['long_destino'] ?? 0.0),
                width: 180,
                height: 180,
                child: GestureDetector(
                  onTap: () => _modalAceitarPedidoSupabase(pedido),
                  child: MarcadorPulo(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 120, width: 120, child: Lottie.asset('assets/box.json', fit: BoxFit.contain)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange[900], borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)]),
                          child: Text("LOJA: R\$ ${pedido['valor_total']}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList();
          });
        });
  }

  void _modalAceitarPedidoSupabase(Map<String, dynamic> pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Nova Entrega de Comerciante 📦", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            Text("Cliente: ${pedido['cliente_nome']}", style: TextStyle(fontSize: 16)),
            Text("Endereço: ${pedido['endereco_destino']}", style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 20),
            Text("GANHO ESTIMADO", style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text("R\$ ${pedido['valor_total']}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green[700])),
            SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 15)),
              onPressed: () async {
                await supabase.from('pedidos').update({
                  'status': 'ACEITO',
                  'motoboy_id': FirebaseAuth.instance.currentUser?.uid,
                }).eq('id', pedido['id']);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Corrida aceita! Fale com o lojista."), backgroundColor: Colors.green));
              },
              child: Text("ACEITAR E IR COLETAR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
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

  void _verificarCorridasAtivas() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance.collection('corridas')
        .where('status', whereIn: ['ACEITO', 'EM_VIAGEM']) 
        .snapshots().listen((snapshot) {
          List<String> listaAtualizada = [];
          for (var doc in snapshot.docs) {
            if (doc['id_solicitante'] == user.uid || doc['id_motoboy'] == user.uid) {
              listaAtualizada.add(doc.id);
            }
          }
          if (mounted) setState(() { _idsCorridasAtivas = listaAtualizada; });
        });
  }

  void _verificarMinhaSolicitacao() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance.collection('corridas')
        .where('id_solicitante', isEqualTo: user.uid) 
        .where('status', isEqualTo: 'PENDENTE')       
        .snapshots().listen((snapshot) {
          String? pendenteEncontrada;
          if (snapshot.docs.isNotEmpty) pendenteEncontrada = snapshot.docs.first.id;
          if (mounted) setState(() { _idSolicitacaoPendente = pendenteEncontrada; });
        });
  }

  void _toggleModoTrabalho(bool val) async {
    if (val == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      final data = doc.data() as Map<String, dynamic>;
      Timestamp? validadeTS = data['validade_assinatura'];
      if (validadeTS != null && validadeTS.toDate().isAfter(DateTime.now())) {
        setState(() => _modoTrabalhoAtivo = true);
      } else {
        showDialog(context: context, builder: (_) => AlertDialog(title: Text("Assinatura Vencida 🚫"), content: Text("Sua assinatura expirou."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))]));
        setState(() => _modoTrabalhoAtivo = false);
      }
    } else {
      setState(() => _modoTrabalhoAtivo = false);
    }
  }

  void _abrirModalPedido() {
    if (_localizacaoAtual == null) return;
    if (_idSolicitacaoPendente != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Você já tem um pedido aguardando!"), backgroundColor: Colors.orange));
      return;
    }
    showModalBottomSheet(context: context, isScrollControlled: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => SolicitarCorridaSheet(latOrigem: _localizacaoAtual!.latitude, longOrigem: _localizacaoAtual!.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    String tipoConta = 'CLIENTE'; 
    userProfileAsync.whenData((snapshot) {
      if (snapshot != null && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        tipoConta = data['tipo']?.toString().toUpperCase() ?? 'CLIENTE';
      }
    });
    bool souMotoboy = tipoConta == 'MOTOBOY';
    bool souMotoboyTrabalhando = (souMotoboy && _modoTrabalhoAtivo);
    Color corPrincipal = souMotoboy ? Colors.green[700]! : Colors.blue[700]!;

    return Scaffold(
      key: _scaffoldKey,
      drawer: HomeDrawer(souMotoboy: souMotoboy, corTema: corPrincipal),
      appBar: AppBar(
        title: Text(souMotoboyTrabalhando ? "Radar 🏍️" : "Solicitar 📦"),
        backgroundColor: corPrincipal, foregroundColor: Colors.white,
        actions: [
          if (souMotoboy)
            Row(children: [Text(_modoTrabalhoAtivo ? "ON" : "OFF", style: TextStyle(fontWeight: FontWeight.bold)), Switch(value: _modoTrabalhoAtivo, activeColor: Colors.white, activeTrackColor: Colors.greenAccent, onChanged: _toggleModoTrabalho)]),
        ],
      ),
      body: Stack(
        children: [
          _conteudoDoMapa(souMotoboyTrabalhando, tipoConta), 
          ActiveRideBanner(idsCorridasAtivas: _idsCorridasAtivas, souMotoboy: souMotoboy),
          if (_idsCorridasAtivas.isEmpty) PendingRideBanner(idSolicitacaoPendente: _idSolicitacaoPendente),
        ],
      ),
      floatingActionButton: (_idSolicitacaoPendente == null) 
        ? HomeFab(souMotoboyTrabalhando: souMotoboyTrabalhando, temLocalizacao: _localizacaoAtual != null, onCentralizar: _buscarLocalizacaoAtual, onNovoPedido: _abrirModalPedido)
        : null, 
      floatingActionButtonLocation: !souMotoboyTrabalhando ? FloatingActionButtonLocation.centerFloat : FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _conteudoDoMapa(bool souMotoboyTrabalhando, String tipoConta) {
    if (_permissaoNegada) return Center(child: Text("Sem permissão de GPS"));
    if (_localizacaoAtual == null) return Center(child: CircularProgressIndicator());

    final user = FirebaseAuth.instance.currentUser;
    Query? query;

    if (souMotoboyTrabalhando) {
      query = FirebaseFirestore.instance.collection('corridas').where('status', whereIn: ['PENDENTE', 'ACEITO', 'EM_VIAGEM', 'A_CAMINHO_COLETA']);
    } else if (user != null) {
      query = FirebaseFirestore.instance.collection('corridas').where('id_solicitante', isEqualTo: user.uid).where('status', whereIn: ['PENDENTE', 'ACEITO', 'EM_VIAGEM', 'A_CAMINHO_COLETA']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query?.snapshots(),
      builder: (context, snapshot) {
        List<Marker> marcadores = [];
        bool clienteEstaAguardando = false; 

        // --- 1. ADICIONA MARCADORES DO SUPABASE (NEXT.JS) ---
        if (souMotoboyTrabalhando) {
          marcadores.addAll(_marcadoresSupabase);
        }

        // --- 2. ADICIONA MARCADORES DO FIREBASE ---
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final String status = data['status'] ?? 'PENDENTE';
            if (data['id_solicitante'] == user?.uid && status == 'PENDENTE') clienteEstaAguardando = true;
            
            if (souMotoboyTrabalhando && status == 'PENDENTE' && data['lat_origem'] != null) {
               marcadores.add(Marker(point: LatLng(data['lat_origem'], data['long_origem']), width: 180, height: 180, child: GestureDetector(onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DetalhesCorridaSheet(pedido: doc)), child: MarcadorPulo(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(height: 120, width: 120, child: Lottie.asset('assets/box.json', fit: BoxFit.contain)), Text("PEDIDO APP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white))])))));
            }
          }
        }

        // Marcador do Usuário
        marcadores.add(Marker(point: _localizacaoAtual!, width: 120, height: 120, child: Column(children: [_iconeDoUsuario(clienteEstaAguardando, tipoConta), Text("Eu", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white))])));

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _localizacaoAtual!, initialZoom: 15.0),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            MarkerLayer(markers: marcadores),
          ],
        );
      },
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
  const MarcadorPulo({required this.child});
  @override _MarcadorPuloState createState() => _MarcadorPuloState();
}
class _MarcadorPuloState extends State<MarcadorPulo> with SingleTickerProviderStateMixin {
  late AnimationController _controller; late Animation<double> _animation;
  @override void initState() { super.initState(); _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..repeat(reverse: true); _animation = Tween<double>(begin: 0, end: -15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _animation, builder: (context, child) => Transform.translate(offset: Offset(0, _animation.value), child: widget.child)); }
}