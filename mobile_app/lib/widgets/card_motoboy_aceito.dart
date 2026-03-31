import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card exibido ao cliente quando o motoboy aceitou a corrida.
/// Mostra foto, nome, veículo, placa, avaliação média e botão de ligar.
class CardMotoboyAceito extends StatelessWidget {
  final Map<String, dynamic> motoboy;

  const CardMotoboyAceito({required this.motoboy, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final nome     = motoboy['nome']         as String? ?? 'Motoboy';
    final modelo   = motoboy['moto_modelo']  as String? ?? '';
    final placa    = motoboy['moto_placa']   as String? ?? '';
    final fotoUrl  = motoboy['foto_url']     as String?;
    final telefone = motoboy['telefone']     as String? ?? '';
    final media    = (motoboy['avaliacao_media'] as num?)?.toDouble() ?? 0.0;
    final total    = (motoboy['total_avaliacoes'] as num?)?.toInt() ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Row(
        children: [
          // Foto
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.green[50],
            backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
            child: fotoUrl == null
                ? Icon(Icons.two_wheeler, size: 32, color: Colors.green[700])
                : null,
          ),
          SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (modelo.isNotEmpty || placa.isNotEmpty)
                  Text(
                    [modelo, placa].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                    SizedBox(width: 3),
                    Text(
                      media > 0
                          ? '${media.toStringAsFixed(1)} ($total aval.)'
                          : 'Sem avaliações',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botão ligar
          if (telefone.isNotEmpty)
            IconButton(
              onPressed: () => _ligar(telefone),
              icon: Icon(Icons.phone, color: Colors.green[700]),
              tooltip: 'Ligar para o motoboy',
              style: IconButton.styleFrom(
                backgroundColor: Colors.green[50],
                padding: EdgeInsets.all(10),
              ),
            ),
        ],
      ),
    );
  }

  void _ligar(String tel) async {
    final numero = tel.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('tel:+55$numero');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }
}
