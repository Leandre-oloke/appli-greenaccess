import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';
import '../../routes.dart';
import '../../ui/ui.dart';
import '../../viewmodels/auth_viewmodel.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _pays = 'Sénégal';
  String _secteur = 'Agriculture';

  final List<String> _paysList = [
    'Sénégal',
    'Bénin',
    'Côte d\'Ivoire',
    'Mali',
    'Burkina Faso',
  ];
  static const _secteurs = <(String, String)>[
    ('Agriculture', '🌾'),
    ('Énergie renouvelable', '☀️'),
    ('Recyclage', '♻️'),
    ('Transport propre', '🚲'),
    ('Forêt', '🌳'),
  ];

  @override
  void dispose() {
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = UserModel(
      id: '',
      nom: _nomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      telephone: _telCtrl.text.trim(),
      pays: _pays,
      region: '',
      secteur: _secteur,
      dateInscription: DateTime.now(),
      profilComplet: false,
      role: UserRole.user,
    );
    await ref
        .read(authViewModelProvider.notifier)
        .register(_emailCtrl.text.trim(), _passwordCtrl.text, profile);
    if (mounted && ref.read(authViewModelProvider).isAuthenticated) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    return GaScaffold(
      appBar: const GaAppBar(title: 'Créer un compte'),
      scrollable: true,
      maxContentWidth: GaBreakpoints.maxForm,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: gaStagger([
            const SizedBox(height: GaSpacing.sm),
            GaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Vous', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: GaSpacing.lg),
                  GaTextField(
                    controller: _nomCtrl,
                    label: 'Nom complet',
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: GaSpacing.md),
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
                    controller: _telCtrl,
                    label: 'Téléphone',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || v.length < 8 ? 'Numéro invalide' : null,
                  ),
                  const SizedBox(height: GaSpacing.md),
                  GaTextField(
                    controller: _passwordCtrl,
                    label: 'Mot de passe',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    helperText: 'Minimum 6 caractères',
                    validator: (v) => v == null || v.length < 6
                        ? 'Minimum 6 caractères'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: GaSpacing.lg),
            GaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Votre activité',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: GaSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue: _pays,
                    decoration: const InputDecoration(
                      labelText: 'Pays',
                      prefixIcon: Icon(Icons.public_rounded, size: 20),
                    ),
                    items: _paysList
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() => _pays = v ?? _pays),
                  ),
                  const SizedBox(height: GaSpacing.lg),
                  Text("Secteur d'activité",
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: GaSpacing.sm),
                  GaChoiceGroup<String>(
                    options: [
                      for (final (name, emoji) in _secteurs)
                        GaChoiceOption(value: name, label: name, emoji: emoji),
                    ],
                    selected: {_secteur},
                    onChanged: (s) =>
                        setState(() => _secteur = s.first),
                  ),
                ],
              ),
            ),
            if (authState.error != null) ...[
              const SizedBox(height: GaSpacing.lg),
              GaInfoBanner(
                  message: authState.error!, kind: GaBannerKind.error),
            ],
            const SizedBox(height: GaSpacing.xl),
            GaPrimaryButton(
              label: "S'inscrire",
              loading: authState.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: GaSpacing.xl),
          ]),
        ),
      ),
    );
  }
}
