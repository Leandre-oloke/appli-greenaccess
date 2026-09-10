import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes.dart';
import '../../ui/ui.dart';
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
  String _countryCode = '+221';
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
    ('+33', '🇫🇷 France'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _resendTimer?.cancel();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
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
    final fullNumber =
        '$_countryCode${phone.startsWith('0') ? phone.substring(1) : phone}';
    await ref.read(authViewModelProvider.notifier).sendOtp(fullNumber);
    if (!mounted) return;
    if (ref.read(authViewModelProvider).error == null) {
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
    if (val.isNotEmpty && index < 5) _otpFocus[index + 1].requestFocus();
    if (val.isEmpty && index > 0) _otpFocus[index - 1].requestFocus();
    if (index == 5 && val.isNotEmpty) _verifyOtp();
  }

  void _back() {
    if (_otpSent) {
      _resendTimer?.cancel();
      setState(() {
        _otpSent = false;
        _resendCountdown = 0;
      });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: GaGradients.of(brightness).header,
                borderRadius: GaRadii.brHeaderBottom,
              ),
              padding: const EdgeInsets.fromLTRB(
                  GaSpacing.lg, GaSpacing.sm, GaSpacing.lg, GaSpacing.xxl),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(height: GaSpacing.sm),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _otpSent
                            ? Icons.mark_chat_read_rounded
                            : Icons.sms_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: GaSpacing.lg),
                    Text(
                      _otpSent
                          ? 'Entrez le code reçu'
                          : 'Vérifions votre numéro',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: GaSpacing.xs),
                    Text(
                      _otpSent
                          ? 'Code à 6 chiffres envoyé au $_countryCode ${_phoneCtrl.text}'
                          : 'Recevez un code SMS pour sécuriser votre compte',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: GaBreakpoints.maxForm),
                child: Padding(
                  padding: const EdgeInsets.all(GaSpacing.screenH),
                  child: AnimatedSwitcher(
                    duration: GaMotion.base,
                    child: _otpSent ? _codeView(state) : _phoneView(state),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneView(AuthState state) {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _countryCode,
                decoration: const InputDecoration(labelText: 'Pays'),
                items: _countries
                    .map((c) => DropdownMenuItem(
                        value: c.$1, child: Text('${c.$2}  ${c.$1}')))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _countryCode = v ?? _countryCode),
              ),
              const SizedBox(height: GaSpacing.md),
              GaTextField(
                controller: _phoneCtrl,
                label: 'Numéro de téléphone',
                hint: '77 000 0000',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                helperText: 'Sans l\'indicatif ni le 0 initial',
              ),
            ],
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: GaSpacing.md),
          GaInfoBanner(
              message: _mapPhoneError(state.error!),
              kind: GaBannerKind.error),
        ],
        const SizedBox(height: GaSpacing.lg),
        GaPrimaryButton(
          label: 'Envoyer le code SMS',
          icon: Icons.send_rounded,
          loading: state.isLoading,
          onPressed: _sendOtp,
        ),
        const SizedBox(height: GaSpacing.lg),
        const GaInfoBanner(
          message:
              'Votre numéro sert uniquement à la vérification. Il ne sera jamais partagé.',
          kind: GaBannerKind.neutral,
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }

  Widget _codeView(AuthState state) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (i) => SizedBox(
              width: 46,
              child: TextField(
                controller: _otpCtrls[i],
                focusNode: _otpFocus[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontFamily: GaTypography.display),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: GaRadii.brSm,
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: GaRadii.brSm,
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                ),
                onChanged: (v) => _onDigitChanged(v, i),
              ),
            ),
          ),
        )
            .animate(target: state.error != null ? 1 : 0)
            .shakeX(hz: 4, amount: 3),
        if (state.error != null) ...[
          const SizedBox(height: GaSpacing.md),
          GaInfoBanner(
              message: _mapPhoneError(state.error!),
              kind: GaBannerKind.error),
        ],
        const SizedBox(height: GaSpacing.xl),
        GaPrimaryButton(
          label: 'Vérifier le code',
          icon: Icons.check_circle_outline_rounded,
          loading: state.isLoading,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: GaSpacing.md),
        Center(
          child: _resendCountdown > 0
              ? GaBadgePill(
                  label: 'Renvoyer dans $_resendCountdown s',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  icon: Icons.timer_outlined,
                )
              : GaSecondaryButton.ghost(
                  label: 'Renvoyer le code',
                  icon: Icons.refresh_rounded,
                  onPressed: state.isLoading ? null : _sendOtp,
                ),
        ),
      ],
    );
  }

  String _mapPhoneError(String error) {
    if (error.contains('invalid-phone-number') ||
        error.contains('InvalidPhoneNumber')) {
      return 'Numéro de téléphone invalide. Vérifiez le format.';
    }
    if (error.contains('too-many-requests') || error.contains('quota')) {
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }
    if (error.contains('invalid-verification-code') ||
        error.contains('InvalidCode')) {
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
