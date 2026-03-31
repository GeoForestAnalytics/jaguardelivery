import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastroPage extends StatefulWidget {
  @override
  _CadastroPageState createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _emailController        = TextEditingController();
  final _senhaController        = TextEditingController();
  final _nomeController         = TextEditingController();
  final _cpfCnpjController      = TextEditingController();
  final _telefoneController     = TextEditingController();
  final _nomeFantasiaController = TextEditingController();
  final _enderecoComController  = TextEditingController();
  final _cidadeController       = TextEditingController();
  final _estadoController       = TextEditingController();

  String _tipoSelecionado = 'CLIENTE';
  bool _isLoading = false;

  final Color _corFundo   = const Color.fromARGB(235, 1, 29, 66);
  final Color _corLaranja = Colors.orange[800]!;
  final Color _corIcones  = const Color.fromARGB(235, 1, 55, 156);

  @override
  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _nomeController.dispose();
    _cpfCnpjController.dispose();
    _telefoneController.dispose();
    _nomeFantasiaController.dispose();
    _enderecoComController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Criar Nova Conta", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double larguraFinal = constraints.maxWidth > 600 ? 500 : constraints.maxWidth;
              bool isWeb = constraints.maxWidth > 600;

              return Container(
                width: larguraFinal,
                padding: isWeb ? EdgeInsets.all(32) : EdgeInsets.zero,
                decoration: isWeb
                    ? BoxDecoration(
                        color: const Color.fromARGB(235, 255, 209, 149),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isWeb) ...[
                      Icon(Icons.person_add, size: 60, color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        "Junte-se ao Jaguar Delivery",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      SizedBox(height: 30),
                    ],
                    if (isWeb) ...[
                      Text(
                        "Preencha seus dados",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _corFundo),
                      ),
                      SizedBox(height: 20),
                    ],

                    _buildTextField(controller: _nomeController, label: "Nome Completo", icon: Icons.person_outline),
                    SizedBox(height: 16),

                    _buildTextField(
                      controller: _cpfCnpjController,
                      label: "CPF ou CNPJ",
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CpfOuCnpjFormatter(),
                      ],
                    ),
                    SizedBox(height: 16),

                    _buildTextField(
                      controller: _telefoneController,
                      label: "WhatsApp",
                      icon: Icons.phone_android,
                      hint: "(11) 99999-9999",
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TelefoneInputFormatter(),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Seleção de tipo de conta
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: RadioGroup<String>(
                        groupValue: _tipoSelecionado,
                        onChanged: (val) => setState(() => _tipoSelecionado = val!),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: Text("Sou Cliente", style: TextStyle(fontWeight: FontWeight.bold, color: _corIcones)),
                              subtitle: Text("Quero solicitar entregas", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              value: 'CLIENTE',
                              activeColor: _corLaranja,
                              secondary: Icon(Icons.shopping_bag_outlined, color: _tipoSelecionado == 'CLIENTE' ? _corLaranja : Colors.grey),
                            ),
                            Divider(height: 1, indent: 20, endIndent: 20),
                            RadioListTile<String>(
                              title: Text("Sou Motoboy", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
                              subtitle: Text("Quero fazer entregas", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              value: 'MOTOBOY',
                              activeColor: Colors.green,
                              secondary: Icon(Icons.two_wheeler, color: _tipoSelecionado == 'MOTOBOY' ? Colors.green : Colors.grey),
                            ),
                            Divider(height: 1, indent: 20, endIndent: 20),
                            RadioListTile<String>(
                              title: Text("Sou Comércio", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[800])),
                              subtitle: Text("Quero enviar pedidos aos clientes", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              value: 'COMERCIO',
                              activeColor: Colors.purple,
                              secondary: Icon(Icons.store_outlined, color: _tipoSelecionado == 'COMERCIO' ? Colors.purple : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Campos extras para comércio
                    if (_tipoSelecionado == 'COMERCIO') ...[
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _nomeFantasiaController,
                        label: "Nome do estabelecimento",
                        icon: Icons.store,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _enderecoComController,
                        label: "Endereço do estabelecimento",
                        icon: Icons.location_on_outlined,
                      ),
                    ],

                    // Campos extras para motoboy
                    if (_tipoSelecionado == 'MOTOBOY') ...[
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _cidadeController,
                        label: "Cidade de trabalho",
                        icon: Icons.location_city_outlined,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _estadoController,
                        label: "Estado (UF)",
                        icon: Icons.map_outlined,
                        hint: "Ex: SP",
                      ),
                    ],

                    SizedBox(height: 20),

                    _buildTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),

                    _buildTextField(
                      controller: _senhaController,
                      label: "Senha",
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),

                    SizedBox(height: 30),

                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _corLaranja,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _isLoading ? null : _realizarCadastro,
                        child: _isLoading
                            ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text("FINALIZAR CADASTRO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _corIcones),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }

  void _realizarCadastro() async {
    final camposObrigatorios = [
      _nomeController.text,
      _cpfCnpjController.text,
      _telefoneController.text,
      _emailController.text,
      _senhaController.text,
    ];
    final comercioVazio = _tipoSelecionado == 'COMERCIO' &&
        (_nomeFantasiaController.text.isEmpty || _enderecoComController.text.isEmpty);
    final motoboyVazio = _tipoSelecionado == 'MOTOBOY' && _cidadeController.text.isEmpty;

    if (camposObrigatorios.any((c) => c.isEmpty) || comercioVazio || motoboyVazio) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Preencha todos os campos!"),
        backgroundColor: _corLaranja,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() { _isLoading = true; });

    final String cpfLimpo  = UtilBrasilFields.removeCaracteres(_cpfCnpjController.text);
    final String telLimpo  = UtilBrasilFields.removeCaracteres(_telefoneController.text);
    final supabase = Supabase.instance.client;

    try {
      // 1. Verificar se CPF/CNPJ já existe
      final cpfExiste = await supabase
          .from('usuarios')
          .select('id')
          .eq('cpf_cnpj', cpfLimpo)
          .maybeSingle();

      if (cpfExiste != null) {
        throw Exception("CPF/CNPJ já possui cadastro.");
      }

      // 2. Criar usuário no Supabase Auth
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );

      final userId = response.user?.id;
      if (userId == null) throw Exception("Erro ao criar conta.");

      // 3. Salvar perfil na tabela usuarios
      final DateTime? validadeAssinatura = _tipoSelecionado == 'MOTOBOY'
          ? DateTime.now().add(Duration(days: 3))
          : null;

      await supabase.from('usuarios').insert({
        'id': userId,
        'nome': _nomeController.text.trim(),
        'email': _emailController.text.trim(),
        'telefone': telLimpo,
        'cpf_cnpj': cpfLimpo,
        'tipo': _tipoSelecionado,
        'validade_assinatura': validadeAssinatura?.toIso8601String(),
        'data_cadastro': DateTime.now().toIso8601String(),
        if (_tipoSelecionado == 'COMERCIO') ...{
          'nome_fantasia': _nomeFantasiaController.text.trim(),
          'endereco_comercio': _enderecoComController.text.trim(),
        },
        if (_tipoSelecionado == 'MOTOBOY') ...{
          'cidade': _cidadeController.text.trim(),
          'estado': _estadoController.text.trim().toUpperCase(),
        },
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      String msg = e.message;
      if (e.message.contains('already registered')) msg = "Este email já está sendo usado.";
      if (e.message.contains('Password should be at least')) msg = "A senha deve ter pelo menos 6 caracteres.";

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
}
