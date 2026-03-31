import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../providers/user_provider.dart';
import '../home/selecionar_destino_page.dart';

class NovaEntregaPage extends ConsumerStatefulWidget {
  const NovaEntregaPage({super.key});

  @override
  ConsumerState<NovaEntregaPage> createState() => _NovaEntregaPageState();
}

class _NovaEntregaPageState extends ConsumerState<NovaEntregaPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _clienteNomeController = TextEditingController();
  final _clienteTelController  = TextEditingController();
  final _descricaoController   = TextEditingController();
  final _valorController       = TextEditingController();

  String? _enderecoDestino;

  String _formaPagamento = 'DINHEIRO';
  bool _isLoading = false;

  double? _latDestino;
  double? _longDestino;
  double? _latAtual;
  double? _longAtual;
  double? _valorFrete;
  double? _distanciaKm;
  static const double _tarifaBaseKm = 1.50;
  static const double _freteMinimo   = 5.00;

  static const _corTema = Color(0xFF6A1B9A);

  @override
  void initState() {
    super.initState();
    _obterLocalizacao();
  }

  Future<void> _obterLocalizacao() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() { _latAtual = pos.latitude; _longAtual = pos.longitude; });
    } catch (_) {}
  }

  void _abrirMapaDestino() async {
    final lat = _latAtual ?? -15.7942;
    final lng = _longAtual ?? -47.8822;
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelecionarDestinoPage(latInicial: lat, longInicial: lng),
      ),
    );
    if (resultado != null && mounted) {
      final ponto    = resultado['ponto'];
      final endereco = (resultado['endereco'] as String? ?? '').isNotEmpty
          ? resultado['endereco'] as String
          : 'Destino selecionado no mapa';
      setState(() {
        _latDestino      = (ponto.latitude  as num).toDouble();
        _longDestino     = (ponto.longitude as num).toDouble();
        _enderecoDestino = endereco;
      });
      _calcularFrete();
    }
  }

  void _calcularFrete() {
    if (_latAtual == null || _longAtual == null ||
        _latDestino == null || _longDestino == null) return;
    const R = 6371.0;
    final dLat = (_latDestino! - _latAtual!) * math.pi / 180;
    final dLon = (_longDestino! - _longAtual!) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_latAtual! * math.pi / 180) *
            math.cos(_latDestino! * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distKm = R * c;
    final frete = (distKm * _tarifaBaseKm).clamp(_freteMinimo, double.infinity);
    setState(() {
      _distanciaKm = distKm;
      _valorFrete  = frete;
    });
  }

  @override
  void dispose() {
    _clienteNomeController.dispose();
    _clienteTelController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(userProfileProvider);
    final enderecoOrigem = perfilAsync.valueOrNull?['endereco_comercio'] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Nova Entrega',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _corTema,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Origem (somente leitura — vem do perfil)
              if (enderecoOrigem.isNotEmpty) ...[
                _SectionHeader(label: 'Origem'),
                _InfoCard(
                  icone: Icons.store,
                  label: 'Endereço do estabelecimento',
                  valor: enderecoOrigem,
                ),
                const SizedBox(height: 16),
              ],

              // Dados do cliente
              _SectionHeader(label: 'Dados do cliente'),
              const SizedBox(height: 8),
              _buildField(
                controller: _clienteNomeController,
                label: 'Nome do cliente',
                icone: Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _clienteTelController,
                label: 'WhatsApp do cliente',
                icone: Icons.phone_android,
                hint: '(11) 99999-9999',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TelefoneInputFormatter(),
                ],
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o telefone' : null,
              ),
              const SizedBox(height: 16),

              // Destino
              _SectionHeader(label: 'Destino'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _abrirMapaDestino,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _latDestino != null ? Colors.green[700]! : Colors.grey[300]!,
                      width: _latDestino != null ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _latDestino != null ? Icons.location_on : Icons.add_location_alt_outlined,
                        color: _latDestino != null ? Colors.green[700] : _corTema,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _enderecoDestino ?? 'Toque para selecionar o destino no mapa',
                          style: TextStyle(
                            color: _enderecoDestino != null ? Colors.black87 : Colors.grey[500],
                          ),
                        ),
                      ),
                      if (_latDestino != null)
                        Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_valorFrete != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Distância estimada',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          Text('${_distanciaKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Frete (R\$ ${_tarifaBaseKm.toStringAsFixed(2)}/km)',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          Text('R\$ ${_valorFrete!.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                  fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Pedido
              _SectionHeader(label: 'Pedido'),
              const SizedBox(height: 8),
              _buildField(
                controller: _descricaoController,
                label: 'Descrição do pedido',
                icone: Icons.description_outlined,
                maxLines: 3,
                hint: 'Ex: 1 pizza calabresa, 1 refrigerante 2L',
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _valorController,
                label: 'Valor total (R\$)',
                icone: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o valor';
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Forma de pagamento
              _SectionHeader(label: 'Forma de pagamento'),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    for (final forma in ['DINHEIRO', 'CARTÃO', 'PIX'])
                      RadioListTile<String>(
                        title: Text(forma),
                        value: forma,
                        groupValue: _formaPagamento,
                        onChanged: (v) => setState(() => _formaPagamento = v!),
                        activeColor: _corTema,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corTema,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isLoading ? 'Publicando...' : 'PUBLICAR ENTREGA',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _isLoading ? null : _publicar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icone,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icone, color: _corTema),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _corTema, width: 2),
        ),
      ),
    );
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latDestino == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione o destino no mapa'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isLoading = true);

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final valorStr = _valorController.text.trim().replaceAll(',', '.');
      final valor = double.parse(valorStr);
      final telLimpo = UtilBrasilFields.removeCaracteres(_clienteTelController.text);

      await _supabase.from('pedidos').insert({
        'comercio_id':      userId,
        'cliente_nome':     _clienteNomeController.text.trim(),
        'cliente_tel':      telLimpo,
        'endereco_destino': _enderecoDestino ?? '',
        'descricao':        _descricaoController.text.trim(),
        'valor_total':      valor,
        'forma_pagamento':  _formaPagamento,
        'status':           'PENDENTE',
        'criado_em':        DateTime.now().toIso8601String(),
        if (_latDestino != null)  'lat_destino':  _latDestino,
        if (_longDestino != null) 'long_destino': _longDestino,
        if (_latAtual != null)    'lat_origem':   _latAtual,
        if (_longAtual != null)   'long_origem':  _longAtual,
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao publicar entrega: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF6A1B9A),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valor;
  const _InfoCard({required this.icone, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icone, color: const Color(0xFF6A1B9A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text(valor, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
