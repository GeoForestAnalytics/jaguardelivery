import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SelecionarDestinoPage extends StatefulWidget {
  final double latInicial;
  final double longInicial;

  const SelecionarDestinoPage({required this.latInicial, required this.longInicial});

  @override
  _SelecionarDestinoPageState createState() => _SelecionarDestinoPageState();
}

class _SelecionarDestinoPageState extends State<SelecionarDestinoPage> {
  late LatLng _centroMapa;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _centroMapa = LatLng(widget.latInicial, widget.longInicial);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Arraste até o local"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroMapa,
              initialZoom: 16.0,
              onPositionChanged: (posicao, hasGesture) {
                // CORREÇÃO AQUI: Removemos o if e o !
                _centroMapa = posicao.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.app.delivery',
              ),
              RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors', onTap: () {})],
              ),
            ],
          ),

          // O PINO FIXO NO CENTRO DA TELA
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0), // Levanta um pouco pra ponta do pino ficar no centro exato
              child: Icon(Icons.location_on, color: Colors.red, size: 50),
            ),
          ),

          // BOTÃO DE CONFIRMAR (AGORA RESPONSIVO PARA WEB)
          Positioned(
            bottom: 30,
            left: 0, 
            right: 0,
            child: Center(
              child: Container(
                // TRAVA A LARGURA PARA NÃO FICAR GIGANTE NO PC
                constraints: BoxConstraints(maxWidth: 400),
                width: MediaQuery.of(context).size.width * 0.9, // No celular usa 90% da tela
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, 
                    foregroundColor: Colors.white,
                    elevation: 5,
                  ),
                  onPressed: () {
                    // Retorna a coordenada escolhida para a tela anterior
                    Navigator.pop(context, _centroMapa);
                  },
                  child: Text("CONFIRMAR ESTE LOCAL"),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}