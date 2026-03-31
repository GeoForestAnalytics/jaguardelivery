import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config.dart';

class WhatsappConectarPage extends StatefulWidget {
  const WhatsappConectarPage({super.key});

  @override
  State<WhatsappConectarPage> createState() => _WhatsappConectarPageState();
}

class _WhatsappConectarPageState extends State<WhatsappConectarPage> {
  final _supabase = Supabase.instance.client;

  String? _qrBase64;
  String  _statusMsg   = 'Iniciando conexão...';
  bool    _conectado   = false;
  bool    _carregando  = true;
  bool    _erro        = false;

  Timer? _pollingTimer;
  late  String _instanceName;

  static const _verde   = Color(0xFF25D366); // cor WhatsApp
  static const _headers = {
    'Content-Type': 'application/json',
    'apikey': EvolutionConfig.apiKey,
  };

  @override
  void initState() {
    super.initState();
    final userId = _supabase.auth.currentUser!.id;
    _instanceName = EvolutionConfig.instanceName(userId);
    _iniciar();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── 1. Cria instância (se não existir) e busca QR ────────────
  Future<void> _iniciar() async {
    setState(() { _carregando = true; _erro = false; _qrBase64 = null; });

    try {
      // Tenta criar — Evolution retorna 400 se já existe (ignoramos)
      await http.post(
        Uri.parse('${EvolutionConfig.baseUrl}/instance/create'),
        headers: _headers,
        body: jsonEncode({
          'instanceName': _instanceName,
          'qrcode': true,
          'integration': 'WHATSAPP-BAILEYS',
        }),
      ).timeout(const Duration(seconds: 10));

      await _buscarQrCode();
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro       = true;
          _statusMsg  = 'Não foi possível conectar ao servidor Evolution.\n'
                        'Verifique a URL e a chave em config.dart.';
        });
      }
    }
  }

  // ── 2. Busca o QR code atual ──────────────────────────────────
  Future<void> _buscarQrCode() async {
    setState(() { _statusMsg = 'Gerando QR Code...'; _carregando = true; });

    try {
      final res = await http.get(
        Uri.parse('${EvolutionConfig.baseUrl}/instance/connect/$_instanceName'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final base64img = data['base64'] as String? ?? data['code'] as String?;

        if (base64img != null) {
          setState(() {
            _qrBase64   = base64img;
            _carregando = false;
            _statusMsg  = 'Escaneie com o WhatsApp do estabelecimento';
          });
          _iniciarPolling();
          return;
        }
      }
      throw Exception('QR não retornado');
    } catch (_) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro       = true;
          _statusMsg  = 'Erro ao gerar QR Code. Tente novamente.';
        });
      }
    }
  }

  // ── 3. Verifica status de conexão a cada 4s ───────────────────
  void _iniciarPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      try {
        final res = await http.get(
          Uri.parse('${EvolutionConfig.baseUrl}/instance/connectionState/$_instanceName'),
          headers: _headers,
        ).timeout(const Duration(seconds: 6));

        if (res.statusCode == 200) {
          final data  = jsonDecode(res.body) as Map<String, dynamic>;
          final state = (data['instance']?['state'] ?? data['state'] ?? '') as String;

          if (state == 'open') {
            _pollingTimer?.cancel();
            await _salvarConexao();
          }
        }
      } catch (_) {}
    });
  }

  // ── 4. Persiste no Supabase e mostra sucesso ──────────────────
  Future<void> _salvarConexao() async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('usuarios').update({
      'whatsapp_instancia': _instanceName,
      'whatsapp_conectado': true,
    }).eq('id', userId);

    if (mounted) {
      setState(() {
        _conectado  = true;
        _qrBase64   = null;
        _statusMsg  = 'WhatsApp conectado com sucesso!';
      });
    }
  }

  // ── 5. Desconecta ─────────────────────────────────────────────
  Future<void> _desconectar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar WhatsApp?'),
        content: const Text(
            'O chatbot de pedidos será desativado para este estabelecimento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desconectar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await http.delete(
      Uri.parse('${EvolutionConfig.baseUrl}/instance/logout/$_instanceName'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('usuarios').update({
      'whatsapp_conectado': false,
    }).eq('id', userId);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Conectar WhatsApp'),
        backgroundColor: _verde,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone WhatsApp
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _verde,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat, color: Colors.white, size: 46),
              ),
              const SizedBox(height: 20),

              if (_conectado) ...[
                const Icon(Icons.check_circle, color: _verde, size: 60),
                const SizedBox(height: 16),
                const Text('WhatsApp Conectado!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Seus clientes já podem fazer pedidos pelo WhatsApp.\n'
                  'O chatbot responderá automaticamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Desconectar',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  onPressed: _desconectar,
                ),
              ] else if (_erro) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                Text(_statusMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                  onPressed: _iniciar,
                ),
              ] else if (_carregando) ...[
                const CircularProgressIndicator(color: _verde),
                const SizedBox(height: 20),
                Text(_statusMsg,
                    style: TextStyle(color: Colors.grey[600])),
              ] else if (_qrBase64 != null) ...[
                Text(_statusMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  'Abra o WhatsApp → Dispositivos conectados → Conectar dispositivo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 20),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Image.memory(
                    _qrBase64!.startsWith('data:')
                        ? base64Decode(_qrBase64!.split(',').last)
                        : base64Decode(_qrBase64!),
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _verde),
                    ),
                    const SizedBox(width: 10),
                    Text('Aguardando escaneio...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Gerar novo QR Code'),
                  onPressed: _buscarQrCode,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
