import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes.dart';
import '../../ui/ui.dart';
import '../../viewmodels/auth_viewmodel.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authViewModelProvider.notifier)
        .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (mounted && ref.read(authViewModelProvider).isAuthenticated) {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _submitGoogle() async {
    await ref.read(authViewModelProvider.notifier).signInWithGoogle();
    if (mounted && ref.read(authViewModelProvider).isAuthenticated) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Bandeau héros ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: GaGradients.of(brightness).header,
                borderRadius: GaRadii.brHeaderBottom,
              ),
              padding: const EdgeInsets.fromLTRB(
                  GaSpacing.xl, GaSpacing.xxl, GaSpacing.xl, GaSpacing.xxxl),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'brand-mark',
                      child: Container(
                        padding: const EdgeInsets.all(GaSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 44,
                          height: 44,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.eco_rounded,
                              color: Colors.white,
                              size: 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: GaSpacing.lg),
                    Text(
                      'Bon retour',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: GaSpacing.xs),
                    Text(
                      'Finance verte · Éducation climatique · Assurance inclusive',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Carte de connexion ────────────────────────────────────────
            Transform.translate(
              offset: const Offset(0, -GaSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: GaBreakpoints.maxForm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: GaSpacing.screenH),
                    child: GaCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: gaStagger([
                            GaTextField(
                              controller: _emailCtrl,
                              label: 'Email',
                              prefixIcon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Email invalide'
                                  : null,
                            ),
                            const SizedBox(height: GaSpacing.md),
                            GaTextField(
                              controller: _passwordCtrl,
                              label: 'Mot de passe',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: (v) => v == null || v.length < 6
                                  ? 'Minimum 6 caractères'
                                  : null,
                            ),
                            if (authState.error != null) ...[
                              const SizedBox(height: GaSpacing.md),
                              GaInfoBanner(
                                message: authState.error!,
                                kind: GaBannerKind.error,
                              ),
                            ],
                            const SizedBox(height: GaSpacing.xl),
                            GaPrimaryButton(
                              label: 'Se connecter',
                              loading: authState.isLoading,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: GaSpacing.md),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: GaSpacing.sm),
                                  child: Text('ou',
                                      style:
                                          Theme.of(context).textTheme.bodySmall),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: GaSpacing.md),
                            GaSecondaryButton.outlined(
                              label: 'Continuer avec Google',
                              icon: Icons.g_mobiledata_rounded,
                              expand: true,
                              loading: authState.isLoading,
                              onPressed: _submitGoogle,
                            ),
                            const SizedBox(height: GaSpacing.xs),
                            GaSecondaryButton.ghost(
                              label: "Pas encore de compte ? S'inscrire",
                              expand: true,
                              onPressed: () => context.push(AppRoutes.register),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: GaSpacing.xl),
          ],
        ),
      ),
    );
  }
}
