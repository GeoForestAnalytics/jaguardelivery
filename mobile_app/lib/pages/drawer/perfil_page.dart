import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PerfilPage extends StatefulWidget {
  @override
  _PerfilPageState createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _formKey        = GlobalKey<FormState>();
  final _nomeController  = TextEditingController();
  final _modeloController = TextEditingController();
  final _placaController  = TextEditingController();

  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isMotoboy = false;
  String? _urlFotoPerfil;
  DateTime? _validadeAssinatura;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final data = await _supabase
        .from('usuarios')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data != null && mounted) {
      final String tipo = data['tipo']?.toString().toUpperCase() ?? 'CLIENTE';
      setState(() {
        _isMotoboy        = tipo == 'MOTOBOY';
        _nomeController.text = data['nome'] ?? '';
        _urlFotoPerfil    = data['foto_url'];

        if (data['validade_assinatura'] != null) {
          _validadeAssinatura = DateTime.parse(data['validade_assinatura']);
        }
        if (_isMotoboy) {
          _modeloController.text = data['moto_modelo'] ?? '';
          _placaController.text  = data['moto_placa']  ?? '';
        }
      });
    }
  }

  Future<void> _uploadFoto() async {
    final picker = ImagePicker();
    try {
      final XFile? imagem = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 50, maxWidth: 600);
      if (imagem == null) return;

      setState(() => _isLoading = true);

      final userId = _supabase.auth.currentUser!.id;
      final bytes  = await imagem.readAsBytes();
      final path   = 'perfil_fotos/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('fotos-perfil').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final downloadUrl = _supabase.storage.from('fotos-perfil').getPublicUrl(path);

      await _supabase
          .from('usuarios')
          .update({'foto_url': downloadUrl})
          .eq('id', userId);

      if (mounted) {
        setState(() {
          _urlFotoPerfil = downloadUrl;
          _isLoading     = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Foto atualizada!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro no upload."), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final Map<String, dynamic> dados = {'nome': _nomeController.text.trim()};

      if (_isMotoboy) {
        dados['moto_modelo'] = _modeloController.text.trim();
        dados['moto_placa']  = _placaController.text.trim().toUpperCase();
      }

      await _supabase.from('usuarios').update(dados).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Salvo com sucesso!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color corTema = _isMotoboy ? Colors.green[700]! : Colors.blue[700]!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
          title: Text("Meu Perfil"),
          backgroundColor: corTema,
          foregroundColor: Colors.white,
          elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Container(
            constraints: BoxConstraints(maxWidth: 600),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4))
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Foto
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: corTema.withOpacity(0.2), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _urlFotoPerfil != null
                              ? NetworkImage(_urlFotoPerfil!)
                              : null,
                          child: _urlFotoPerfil == null
                              ? Icon(
                                  _isMotoboy ? Icons.two_wheeler : Icons.person,
                                  size: 60,
                                  color: Colors.grey[400])
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Material(
                          color: corTema,
                          shape: CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(50),
                            onTap: _isLoading ? null : _uploadFoto,
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Icon(Icons.camera_alt, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  if (_isMotoboy) ...[
                    _buildStatusAssinatura(),
                    SizedBox(height: 20),
                  ],

                  TextFormField(
                    controller: _nomeController,
                    decoration: _inputDecoration("Nome Completo", Icons.person, corTema),
                    validator: (val) => val!.isEmpty ? 'Informe seu nome' : null,
                  ),

                  if (_isMotoboy) ...[
                    SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("Dados do Veículo",
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _modeloController,
                      decoration: _inputDecoration("Modelo da Moto", Icons.motorcycle, corTema),
                      validator: (val) => val!.isEmpty ? 'Informe o modelo' : null,
                    ),
                    SizedBox(height: 15),
                    TextFormField(
                      controller: _placaController,
                      decoration: _inputDecoration("Placa", Icons.confirmation_number, corTema),
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) => val!.isEmpty ? 'Informe a placa' : null,
                    ),
                  ],

                  SizedBox(height: 30),

                  // BOTÃO SALVAR
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corTema,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _isLoading ? null : _salvarPerfil,
                      child: Text(
                        _isLoading ? "SALVANDO..." : "SALVAR ALTERAÇÕES",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // BOTÃO SUPORTE (WhatsApp)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: corTema),
                        foregroundColor: corTema,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () async {
                        final telSuporte = "5515981409153";
                        final url = "https://wa.me/$telSuporte?text=Olá, preciso de ajuda com o Jaguar Delivery";
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.support_agent),
                      label: const Text("FALAR COM O SUPORTE", 
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusAssinatura() {
    bool ativo = false;
    String texto    = "Assinatura não encontrada";
    Color corFundo  = Colors.grey[100]!;
    Color corTexto  = Colors.grey;

    if (_validadeAssinatura != null) {
      if (_validadeAssinatura!.isAfter(DateTime.now())) {
        ativo    = true;
        texto    = "ASSINATURA ATIVA ATÉ ${DateFormat('dd/MM/yyyy').format(_validadeAssinatura!)}";
        corFundo = Colors.green[50]!;
        corTexto = Colors.green[800]!;
      } else {
        texto    = "ASSINATURA VENCIDA";
        corFundo = Colors.red[50]!;
        corTexto = Colors.red[800]!;
      }
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: corTexto.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ativo ? Icons.check_circle : Icons.warning, color: corTexto),
          SizedBox(width: 8),
          Flexible(
            child: Text(texto,
                style: TextStyle(color: corTexto, fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color cor) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: cor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cor, width: 2)),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );
  }
}