import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../routes.dart';
import '../../models/user_model.dart';
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

  final List<String> _paysList = ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso'];
  final List<String> _secteursList = [
    'Agriculture', 'Énergie renouvelable', 'Recyclage', 'Transport propre', 'Forêt'
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
    await ref.read(authViewModelProvider.notifier).register(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          profile,
        );
    if (mounted && ref.read(authViewModelProvider).isAuthenticated) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
                validator: (v) => v == null || v.length < 8 ? 'Numéro invalide' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _pays,
                decoration: const InputDecoration(labelText: 'Pays'),
                items: _paysList.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _pays = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _secteur,
                decoration: const InputDecoration(labelText: "Secteur d'activité"),
                items: _secteursList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _secteur = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => v == null || v.length < 6 ? 'Minimum 6 caractères' : null,
              ),
              if (authState.error != null) ...[
                const SizedBox(height: 12),
                Text(authState.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _submit,
                child: authState.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("S'inscrire"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
