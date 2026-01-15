import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroPage extends StatefulWidget {
  @override
  _CadastroPageState createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cpfCnpjController = TextEditingController();
  final _telefoneController = TextEditingController();
  
  String _tipoSelecionado = 'CLIENTE'; 
  bool _isLoading = false;

  // Mesmas cores da Login Page para consistência
  final Color _corFundo = const Color.fromARGB(235, 1, 29, 66);
  final Color _corLaranja = Colors.orange[800]!;
  final Color _corIcones = const Color.fromARGB(235, 1, 55, 156);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo, // Fundo Azul Premium
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparente para integrar ao fundo
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
              // Lógica Responsiva (igual ao Login)
              double larguraFinal = constraints.maxWidth > 600 ? 500 : constraints.maxWidth;
              bool isWeb = constraints.maxWidth > 600;

              return Container(
                width: larguraFinal,
                padding: isWeb ? EdgeInsets.all(32) : EdgeInsets.zero,
                decoration: isWeb 
                  ? BoxDecoration(
                      color: const Color.fromARGB(235, 255, 209, 149), // Fundo claro no PC
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))
                      ],
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

                    // 1. Campo Nome
                    _buildTextField(
                      controller: _nomeController,
                      label: "Nome Completo",
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: 16),

                    // 2. Campo CPF ou CNPJ
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

                    // 3. Campo WhatsApp
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
                    
                    // 4. Seleção de Tipo de Conta (Estilizado)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Text("Sou Cliente", style: TextStyle(fontWeight: FontWeight.bold, color: _corIcones)),
                            subtitle: Text("Quero solicitar entregas", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            value: 'CLIENTE',
                            groupValue: _tipoSelecionado,
                            activeColor: _corLaranja,
                            secondary: Icon(Icons.shopping_bag_outlined, color: _tipoSelecionado == 'CLIENTE' ? _corLaranja : Colors.grey),
                            onChanged: (val) => setState(() => _tipoSelecionado = val!),
                          ),
                          Divider(height: 1, indent: 20, endIndent: 20),
                          RadioListTile<String>(
                            title: Text("Sou Motoboy", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
                            subtitle: Text("Quero fazer entregas", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            value: 'MOTOBOY',
                            groupValue: _tipoSelecionado,
                            activeColor: Colors.green,
                            secondary: Icon(Icons.two_wheeler, color: _tipoSelecionado == 'MOTOBOY' ? Colors.green : Colors.grey),
                            onChanged: (val) => setState(() => _tipoSelecionado = val!),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // 5. Email
                    _buildTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),
                    
                    // 6. Senha
                    _buildTextField(
                      controller: _senhaController,
                      label: "Senha",
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    
                    SizedBox(height: 30),
                    
                    // Botão de Cadastro (Estilo Laranja Arredondado)
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
            }
          ),
        ),
      ),
    );
  }

  // Widget auxiliar atualizado para o estilo "Pílula" (Round 30)
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }

  void _realizarCadastro() async {
    if (_nomeController.text.isEmpty || _cpfCnpjController.text.isEmpty || 
        _telefoneController.text.isEmpty || _emailController.text.isEmpty || _senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Preencha todos os campos!"), 
        backgroundColor: _corLaranja,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() { _isLoading = true; });

    String cpfLimpo = UtilBrasilFields.removeCaracteres(_cpfCnpjController.text);
    String telLimpo = UtilBrasilFields.removeCaracteres(_telefoneController.text);

    try {
      // Verifica se CPF já existe antes de criar Auth
      final querySnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('cpf_cnpj', isEqualTo: cpfLimpo)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        throw FirebaseAuthException(code: 'cpf-already-in-use', message: 'CPF/CNPJ já cadastrado.');
      }

      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );

      // Salva no Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(userCred.user!.uid).set({
        'uid': userCred.user!.uid,
        'nome': _nomeController.text.trim(),
        'email': _emailController.text.trim(),
        'telefone': telLimpo,
        'cpf_cnpj': cpfLimpo, 
        'tipo': _tipoSelecionado,
        'data_cadastro': FieldValue.serverTimestamp(),
        // Se for motoboy, podemos dar 3 dias grátis de teste
        'validade_assinatura': _tipoSelecionado == 'MOTOBOY' 
            ? Timestamp.fromDate(DateTime.now().add(Duration(days: 3))) 
            : null,
      });
      
      if (mounted) {
        Navigator.of(context).pop(); // Volta para o Login (o StreamBuilder vai logar automático)
      }

    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "Erro ao cadastrar";
      if (e.code == 'email-already-in-use') msg = "Este email já está sendo usado.";
      if (e.code == 'weak-password') msg = "A senha deve ter pelo menos 6 caracteres.";
      if (e.code == 'cpf-already-in-use') msg = "CPF/CNPJ já possui cadastro.";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
}