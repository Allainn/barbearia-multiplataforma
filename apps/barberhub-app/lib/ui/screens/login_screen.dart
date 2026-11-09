import 'package:flutter/material.dart';

import '../../state/auth_controller.dart';
import '../theme/app_theme.dart';

/// Porta de entrada: toda rota do BFF pede token, então o app começa pelo login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _senha = TextEditingController();
  var _senhaVisivel = false;

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.auth.entrar(_usuario.text, _senha.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: widget.auth,
                builder: (context, _) {
                  final entrando = widget.auth.entrando;
                  final erro = widget.auth.erro;
                  return Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: scheme.primary,
                              child: Icon(
                                Icons.content_cut,
                                size: 30,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'BarberHub',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.displaySmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Entre para encontrar uma barbearia e reservar seu horário.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TextFormField(
                            controller: _usuario,
                            enabled: !entrando,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              hintText: 'Usuário',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (valor) => (valor ?? '').trim().isEmpty
                                ? 'Informe o usuário'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _senha,
                            enabled: !entrando,
                            obscureText: !_senhaVisivel,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _entrar(),
                            decoration: InputDecoration(
                              hintText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _senhaVisivel
                                    ? 'Esconder a senha'
                                    : 'Mostrar a senha',
                                onPressed: () => setState(
                                  () => _senhaVisivel = !_senhaVisivel,
                                ),
                                icon: Icon(
                                  _senhaVisivel
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (valor) => (valor ?? '').isEmpty
                                ? 'Informe a senha'
                                : null,
                          ),
                          if (erro != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _AvisoDeErro(mensagem: erro.message),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: entrando ? null : _entrar,
                            child: entrando
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('Entrar'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvisoDeErro extends StatelessWidget {
  const _AvisoDeErro({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        // Fundo só tingido de erro, com borda: avisa sem virar um bloco vermelho na tela.
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.10),
          border: Border.all(color: scheme.error.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                mensagem,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
