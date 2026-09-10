import 'dart:async';
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
  String _countryCode = '+221'; // Sénégal par défaut
  int _resendCountdown = 0;
  Timer? _resendTimer;

  static const _countries = [
    ('+221', '🇸🇳 Sénégal'),
    ('+229', '🇧🇯 Bénin'),
    ('+225', '🇨🇮 Côte d\'Ivoire'),
    ('+223', '🇲🇱 Mali'),
    ('+226', '🇧🇫 Burkina Faso'),
    ('+224', '🇬🇳 Guinée'),
    ('+227', '🇳🇪 Niger'),
    ('+228', '🇹🇬 Togo'),
    ('+237', '🇨🇲 Cameroun'),
    ('+242', '🇨🇬 Congo'),
    ('+243', '🇨🇩 RD Congo'),
    ('+225', '🇨🇮 Côte d\'Ivoire'),
    ('+33',  '🇫🇷 France'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _resendTimer?.cancel();
    for (final c in _otpCtrls) { c.dispose(); }
    for (final f in _otpFocus) { f.dispose(); }
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 0) {
        t.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    final fullNumber = '$_countryCode${phone.startsWith('0') ? phone.substring(1) : phone}';
    await ref.read(authViewModelProvider.notifier).sendOtp(fullNumber);
    if (!mounted) return;

    final error = ref.read(authViewModelProvider).error;
    if (error == null) {
      setState(() => _otpSent = true);
      _startResendTimer();
    }
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
            _resendTimer?.cancel();
            setState(() { _otpSent = false; _resendCountdown = 0; });
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
              // Icône animée
              Container(
                width: 90,
                height: 90,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _otpSent ? Icons.mark_chat_read_outlined : Icons.sms_outlined,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),

              Text(
                _otpSent ? 'Entrez le code reçu' : 'Votre numéro de téléphone',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Code à 6 chiffres envoyé au $_countryCode ${_phoneCtrl.text}'
                    : 'Recevez un code SMS pour sécuriser votre compte',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),

              if (!_otpSent) ...[
                // ── Saisie du numéro ──────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélecteur indicatif
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.surface,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _countryCode,
                          items: _countries
                              .map((c) => DropdownMenuItem(
                                    value: c.$1,
                                    child: Text('${c.$2}  ${c.$1}',
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _countryCode = v!),
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Numéro de téléphone',
                          hintText: '77 000 0000',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez le numéro sans l\'indicatif ni le 0 initial.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Envoyer le code SMS'),
                  onPressed: state.isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

              ] else ...[
                // ── Saisie du code OTP ────────────────────────────────────
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        onChanged: (v) => _onDigitChanged(v, i),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Vérifier le code'),
                  onPressed: state.isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                const SizedBox(height: 16),

                // ── Renvoi avec minuteur ──────────────────────────────────
                _resendCountdown > 0
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Renvoyer dans $_resendCountdown s',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      )
                    : TextButton.icon(
                        onPressed: state.isLoading ? null : _sendOtp,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Renvoyer le code'),
                      ),

                const SizedBox(height: 16),
                // Indicateur de progression
                if (state.isLoading)
                  const LinearProgressIndicator(
                    backgroundColor: AppColors.primarySoft,
                    color: AppColors.primary,
                  ),
              ],

              // ── Message d'erreur ──────────────────────────────────────────
              if (state.error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mapPhoneError(state.error!),
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Info sécurité ─────────────────────────────────────────────
              if (!_otpSent) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Votre numéro est utilisé uniquement pour la vérification. Il ne sera jamais partagé.',
                          style: TextStyle(fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _mapPhoneError(String error) {
    if (error.contains('invalid-phone-number') || error.contains('InvalidPhoneNumber')) {
      return 'Numéro de téléphone invalide. Vérifiez le format.';
    }
    if (error.contains('too-many-requests') || error.contains('quota')) {
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }
    if (error.contains('invalid-verification-code') || error.contains('InvalidCode')) {
      return 'Code incorrect. Vérifiez le SMS et réessayez.';
    }
    if (error.contains('session-expired') || error.contains('expired')) {
      return 'Le code a expiré. Demandez un nouveau code.';
    }
    if (error.contains('network')) {
      return 'Erreur réseau. Vérifiez votre connexion et réessayez.';
    }
    return error;
  }
}
