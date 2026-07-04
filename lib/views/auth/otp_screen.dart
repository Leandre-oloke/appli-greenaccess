import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../viewmodels/auth_viewmodel.dart';

class OTPScreen extends ConsumerStatefulWidget {
  const OTPScreen({super.key});

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 8) return;
    await ref.read(authViewModelProvider.notifier).sendOtp(phone);
    if (mounted) setState(() => _otpSent = true);
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrls.map((c) => c.text).join();
    if (code.length != 6) return;
    await ref.read(authViewModelProvider.notifier).verifyOtp(code);
    if (mounted && ref.read(authViewModelProvider).isAuthenticated) {
      context.go(AppRoutes.dashboard);
    }
  }

  void _onDigitChanged(String val, int index) {
    if (val.isNotEmpty && index < 5) {
      _otpFocus[index + 1].requestFocus();
    }
    if (val.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }
    if (index == 5 && val.isNotEmpty) _verifyOtp();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification téléphone'),
        leading: BackButton(onPressed: () {
          if (_otpSent) {
            setState(() => _otpSent = false);
          } else {
            context.pop();
          }
        }),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.sms_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                _otpSent ? 'Entrez le code reçu' : 'Votre numéro de téléphone',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Un code à 6 chiffres a été envoyé au ${_phoneCtrl.text}'
                    : 'Recevez un code SMS pour sécuriser votre compte',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              if (!_otpSent) ...[
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '+221 77 000 0000',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: state.isLoading ? null : _sendOtp,
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Envoyer le code'),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (i) => SizedBox(
                      width: 44,
                      child: TextFormField(
                        controller: _otpCtrls[i],
                        focusNode: _otpFocus[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (v) => _onDigitChanged(v, i),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: state.isLoading ? null : _verifyOtp,
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Vérifier le code'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _sendOtp,
                  child: const Text('Renvoyer le code'),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
