import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvaliacaoSheet extends StatefulWidget {
  final String corridaId;
  final String idAvaliado; // id do motoboy (cliente avalia) ou do cliente (motoboy avalia)
  final bool avaliadoPeloCliente; // true = cliente avalia motoboy

  const AvaliacaoSheet({
    required this.corridaId,
    required this.idAvaliado,
    required this.avaliadoPeloCliente,
    Key? key,
  }) : super(key: key);

  @override
  State<AvaliacaoSheet> createState() => _AvaliacaoSheetState();
}

class _AvaliacaoSheetState extends State<AvaliacaoSheet> {
  int _nota = 0;
  final _comentarioController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_nota == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecione uma nota!'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _enviando = true);
    final supabase = Supabase.instance.client;
    try {
      // Salva avaliação na corrida
      final campo = widget.avaliadoPeloCliente
          ? 'avaliacao_nota_motoboy'
          : 'avaliacao_nota_cliente';
      final campoCom = widget.avaliadoPeloCliente
          ? 'avaliacao_comentario_motoboy'
          : 'avaliacao_comentario_cliente';

      await supabase.from('corridas').update({
        campo:    _nota,
        campoCom: _comentarioController.text.trim(),
      }).eq('id', widget.corridaId);

      // Recalcula média do avaliado
      final rows = await supabase
          .from('corridas')
          .select(campo)
          .eq(widget.avaliadoPeloCliente ? 'id_motoboy' : 'id_solicitante',
              widget.idAvaliado)
          .not(campo, 'is', null);

      final notas = (rows as List).map((r) => (r[campo] as num).toDouble()).toList();
      if (notas.isNotEmpty) {
        final media = notas.reduce((a, b) => a + b) / notas.length;
        await supabase.from('usuarios').update({
          'avaliacao_media':    double.parse(media.toStringAsFixed(1)),
          'total_avaliacoes':   notas.length,
        }).eq('id', widget.idAvaliado);
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar avaliação.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),

          Icon(Icons.star_rounded, color: Colors.amber, size: 48),
          SizedBox(height: 8),
          Text(
            widget.avaliadoPeloCliente
                ? 'Como foi o motoboy?' : 'Como foi o cliente?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text('Avalie a experiência', style: TextStyle(color: Colors.grey[600])),
          SizedBox(height: 24),

          // Estrelas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final estrela = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _nota = estrela),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    estrela <= _nota ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: estrela <= _nota ? Colors.amber : Colors.grey[300],
                    size: 48,
                  ),
                ),
              );
            }),
          ),

          if (_nota > 0) ...[
            SizedBox(height: 8),
            Text(
              ['', '😞 Ruim', '😐 Regular', '😊 Bom', '😃 Ótimo', '🤩 Excelente!'][_nota],
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: [Colors.transparent, Colors.red, Colors.orange,
                    Colors.blue, Colors.green, Colors.green[800]!][_nota]),
            ),
          ],

          SizedBox(height: 20),

          TextField(
            controller: _comentarioController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Deixe um comentário (opcional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Pular'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _enviando
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('AVALIAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
