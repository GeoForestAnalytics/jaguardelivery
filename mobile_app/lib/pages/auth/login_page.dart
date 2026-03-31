import 'package:appdeliverymoto/pages/home/cadastro_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Modo: 'email' ou 'telefone'
  String _modo = 'email';

  // Email/senha
  final _emailController = TextEditingController();
  final _senhaController  = TextEditingController();

  // Telefone OTP
  final _telefoneController = TextEditingController();
  final _otpController      = TextEditingController();
  bool _otpEnviado = false;

  bool _isLoading        = false;
  bool _obscurePassword  = true;

  final Color _corFundo   = const Color.fromARGB(235, 1, 29, 66);
  final Color _corLaranja = Colors.orange[800]!;
  final Color _corIcones  = const Color.fromARGB(235, 1, 55, 156);

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _telefoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double largura = constraints.maxWidth > 600 ? 450 : constraints.maxWidth;
              bool isWeb = constraints.maxWidth > 600;

              return Container(
                width: largura,
                decoration: isWeb
                    ? BoxDecoration(
                        color: const Color.fromARGB(235, 255, 209, 149),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
                      )
                    : null,
                padding: isWeb ? EdgeInsets.all(32) : EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(-40, 0),
                      child: SizedBox(
                        height: 260,
                        child: Lottie.asset('assets/delivery.json', fit: BoxFit.contain),
                      ),
                    ),
                    Text(
                      "Jaguar Delivery",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isWeb ? _corFundo : Colors.white,
                      ),
                    ),
                    Text(
                      "Entre e peça agora 🐆",
                      style: TextStyle(color: Colors.grey[isWeb ? 700 : 400]),
                    ),
                    SizedBox(height: 24),

                    // ── Toggle email / telefone ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          _tabBtn('email',    Icons.email_outlined,  'E-mail'),
                          _tabBtn('telefone', Icons.phone_android,   'Telefone'),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // ── Formulário ───────────────────────────────────────────
                    if (_modo == 'email') ..._formEmail(isWeb),
                    if (_modo == 'telefone') ..._formTelefone(isWeb),

                    SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: Divider(color: Colors.grey[isWeb ? 400 : 600])),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text("ou", style: TextStyle(color: Colors.grey[isWeb ? 600 : 400])),
                      ),
                      Expanded(child: Divider(color: Colors.grey[isWeb ? 400 : 600])),
                    ]),
                    SizedBox(height: 10),

                    TextButton(
                      onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => CadastroPage())),
                      child: RichText(
                        text: TextSpan(
                          text: "Não tem uma conta? ",
                          style: TextStyle(color: isWeb ? Colors.grey[700] : Colors.grey[400]),
                          children: [
                            TextSpan(
                              text: "Cadastre-se",
                              style: TextStyle(color: _corLaranja, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String modo, IconData icon, String label) {
    bool ativo = _modo == modo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _modo = modo;
          _otpEnviado = false;
        }),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: ativo ? _corLaranja : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: ativo ? Colors.white : Colors.grey[400]),
              SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: ativo ? Colors.white : Colors.grey[400],
                fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              )),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _formEmail(bool isWeb) => [
    _campo(
      controller: _emailController,
      label: 'Email',
      icon: Icons.email_outlined,
      type: TextInputType.emailAddress,
    ),
    SizedBox(height: 14),
    _campo(
      controller: _senhaController,
      label: 'Senha',
      icon: Icons.lock_outline,
      obscure: _obscurePassword,
      sufixo: IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      onSubmit: (_) => _loginEmail(),
    ),
    SizedBox(height: 24),
    _botao(
      label: 'ACESSAR CONTA',
      onTap: _loginEmail,
    ),
  ];

  List<Widget> _formTelefone(bool isWeb) => [
    _campo(
      controller: _telefoneController,
      label: 'WhatsApp (ex: 11999999999)',
      icon: Icons.phone_android,
      type: TextInputType.phone,
      enabled: !_otpEnviado,
    ),
    if (_otpEnviado) ...[
      SizedBox(height: 14),
      _campo(
        controller: _otpController,
        label: 'Código recebido por SMS',
        icon: Icons.pin_outlined,
        type: TextInputType.number,
        onSubmit: (_) => _verificarOtp(),
      ),
      SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() {
          _otpEnviado = false;
          _otpController.clear();
        }),
        child: Text('Reenviar código', style: TextStyle(color: _corLaranja)),
      ),
    ],
    SizedBox(height: 24),
    _botao(
      label: _otpEnviado ? 'VERIFICAR CÓDIGO' : 'ENVIAR CÓDIGO SMS',
      onTap: _otpEnviado ? _verificarOtp : _enviarOtp,
    ),
  ];

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    bool enabled = true,
    Widget? sufixo,
    ValueChanged<String>? onSubmit,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      enabled: enabled,
      onSubmitted: onSubmit,
      style: TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _corIcones),
        suffixIcon: sufixo,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }

  Widget _botao({required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _corLaranja,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: _isLoading ? null : onTap,
        child: _isLoading
            ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── Lógica Email ──────────────────────────────────────────────────────────

  void _loginEmail() async {
    if (_emailController.text.isEmpty || _senhaController.text.isEmpty) {
      _snack('Preencha email e senha!', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email:    _emailController.text.trim(),
        password: _senhaController.text,
      );
    } on AuthException catch (e) {
      String msg = 'Erro ao logar.';
      if (e.message.contains('Invalid login')) msg = 'Email ou senha incorretos.';
      if (e.message.contains('Email not confirmed')) msg = 'Confirme seu email antes de entrar.';
      if (e.message.contains('too many requests')) msg = 'Muitas tentativas. Tente mais tarde.';
      _snack(msg, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Lógica OTP Telefone ───────────────────────────────────────────────────

  void _enviarOtp() async {
    final tel = _telefoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (tel.length < 10) {
      _snack('Informe o número com DDD (ex: 11999999999)', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: '+55$tel',
      );
      if (mounted) setState(() => _otpEnviado = true);
      _snack('Código enviado por SMS! ✅', Colors.green);
    } on AuthException catch (e) {
      _snack(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verificarOtp() async {
    final tel = _telefoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      _snack('Digite o código recebido por SMS', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        phone: '+55$tel',
        token: otp,
        type:  OtpType.sms,
      );
      // StreamBuilder no main.dart detecta o login automaticamente
    } on AuthException catch (e) {
      _snack('Código inválido ou expirado: ${e.message}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
