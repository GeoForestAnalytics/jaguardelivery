import 'package:appdeliverymoto/pages/home/cadastro_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart'; // Importante para a animação

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true; // Para controlar o "olhinho" da senha

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(235, 1, 29, 66), // Fundo verde bem clarinho (Premium)
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Limita largura no PC para não ficar esticado
              double larguraFinal = constraints.maxWidth > 600 ? 450 : constraints.maxWidth;

              return Container(
                width: larguraFinal,
                decoration: constraints.maxWidth > 600
                    ? BoxDecoration(
                        color: const Color.fromARGB(235, 255, 209, 149),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
                      )
                    : null, // No celular fica transparente para integrar com o fundo
                padding: constraints.maxWidth > 600 ? EdgeInsets.all(32) : EdgeInsets.zero,
                
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. ANIMAÇÃO (LOTTIE)
                    Transform.translate(
                      offset: Offset(-40, 0), // X = -40 (Esquerda), Y = 0 (Não mexe na altura)
                      child: Container( 
                      height: 300, 
                      child: Lottie.asset(
                      'assets/delivery.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                    SizedBox(height: 10),
                    
                    Text(
                      "Jaguar Delivery",
                      style: TextStyle(
                        fontSize: 28, 
                        fontWeight: FontWeight.bold, 
                        color: const Color.fromARGB(235, 0, 31, 49),
                        fontFamily: 'Roboto', // Se tiver, senão usa padrão
                      ),
                    ),
                    Text(
                      "Entre e peça agora 🐆", 
                      style: TextStyle(color: Colors.grey[600])
                    ),
                    
                    SizedBox(height: 30),

                    // 2. EMAIL
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email_outlined, color: const Color.fromARGB(235, 1, 55, 156)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30), // Borda redonda
                          borderSide: BorderSide.none, // Sem linha preta
                        ),
                        filled: true,
                        fillColor: Colors.white, // No celular destaca do fundo verde
                        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 3. SENHA
                    TextField(
                      controller: _senhaController,
                      obscureText: _obscurePassword,
                      onSubmitted: (_) => _fazerLogin(),
                      decoration: InputDecoration(
                        labelText: "Senha",
                        prefixIcon: Icon(Icons.lock_outline, color: const Color.fromARGB(235, 1, 55, 156)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility, 
                            color: Colors.grey
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      ),
                    ),

                    SizedBox(height: 24),

                    // 4. BOTÃO ENTRAR (LARANJA PARA CHAMAR ATENÇÃO)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800], // Laranja forte
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _isLoading ? null : _fazerLogin,
                        child: _isLoading 
                          ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                          : Text("ACESSAR CONTA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    SizedBox(height: 20),
                    
                    // Divisor bonito
                    Row(children: [Expanded(child: Divider()), Text(" ou ", style: TextStyle(color: Colors.grey)), Expanded(child: Divider())]),
                    SizedBox(height: 10),

                    // 5. LINK CADASTRO
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CadastroPage()));
                      },
                      child: RichText(
                        text: TextSpan(
                          text: "Não tem uma conta? ",
                          style: TextStyle(color: Colors.grey[700]),
                          children: [
                            TextSpan(
                              text: "Cadastre-se",
                              style: TextStyle(color: const Color.fromARGB(235, 1, 55, 156), fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _fazerLogin() async {
    if (_emailController.text.isEmpty || _senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Preencha email e senha!"),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() { _isLoading = true; });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );
      // O StreamBuilder no main.dart vai detectar o login e mudar a tela sozinho
    } on FirebaseAuthException catch (e) {
      String msg = "Erro ao logar.";
      if (e.code == 'user-not-found') msg = "Usuário não encontrado. Cadastre-se!";
      if (e.code == 'wrong-password') msg = "Senha incorreta.";
      if (e.code == 'invalid-email') msg = "Email inválido.";
      if (e.code == 'too-many-requests') msg = "Muitas tentativas. Tente mais tarde.";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), 
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
}