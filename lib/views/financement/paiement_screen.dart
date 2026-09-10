import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/paiement_model.dart';
import '../../repositories/paiement_repository.dart';
import '../../viewmodels/auth_viewmodel.dart';

// ── Provider local ────────────────────────────────────────────────────────────

final _paiementRepoProvider = Provider((_) => PaiementRepository());

// ── Écran principal ───────────────────────────────────────────────────────────

class PaiementScreen extends ConsumerStatefulWidget {
  final String demandeId;
  final String echeanceId;
  final int numeroEcheance;
  final double montant;

  const PaiementScreen({
    super.key,
    required this.demandeId,
    required this.echeanceId,
    required this.numeroEcheance,
    required this.montant,
  });

  @override
  ConsumerState<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends ConsumerState<PaiementScreen> {
  OperateurMobileMoney? _operateur;
  PaiementModel? _paiementInitie;
  bool _loading = false;
  bool _confirme = false;

  static const _operateurs = [
    _OperateurInfo(
      operateur: OperateurMobileMoney.wave,
      nom: 'Wave',
      couleur: Color(0xFF1DA0F2),
      description: 'Paiement instantané via l\'app Wave',
      deeplink: 'wave://',
      fallbackUrl: 'https://www.wave.com',
      logo: Icons.waves,
    ),
    _OperateurInfo(
      operateur: OperateurMobileMoney.orangeMoney,
      nom: 'Orange Money',
      couleur: Color(0xFFFF6600),
      description: 'Disponible sur tous les réseaux Orange',
      deeplink: 'orangemoney://',
      fallbackUrl: 'https://www.orange.com/fr/orangemoney',
      logo: Icons.account_balance_wallet,
    ),
    _OperateurInfo(
      operateur: OperateurMobileMoney.mtnMomo,
      nom: 'MTN MoMo',
      couleur: Color(0xFFFFCC00),
      description: 'Mobile Money MTN disponible en zone UEMOA',
      deeplink: 'mtn://',
      fallbackUrl: 'https://mtn.com/momo',
      logo: Icons.mobile_friendly,
    ),
    _OperateurInfo(
      operateur: OperateurMobileMoney.moov,
      nom: 'Moov Money',
      couleur: Color(0xFF0066CC),
      description: 'Paiement mobile Moov Africa',
      deeplink: 'moovmoney://',
      fallbackUrl: 'https://moov-africa.com',
      logo: Icons.phone_android,
    ),
    _OperateurInfo(
      operateur: OperateurMobileMoney.free,
      nom: 'Free Money',
      couleur: Color(0xFFCC0000),
      description: 'Paiement mobile Free Sénégal',
      deeplink: 'freemoney://',
      fallbackUrl: 'https://www.free.sn',
      logo: Icons.sim_card,
    ),
  ];

  Future<void> _initierPaiement() async {
    if (_operateur == null) return;
    setState(() => _loading = true);
    try {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      final paiement = await ref.read(_paiementRepoProvider).initierPaiement(
            demandeId: widget.demandeId,
            echeanceId: widget.echeanceId,
            userId: uid,
            montant: widget.montant,
            operateur: _operateur!,
          );
      setState(() { _paiementInitie = paiement; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _ouvrirAppOperateur(_OperateurInfo info) async {
    // Tente le deeplink vers l'app native
    final deepUri = Uri.tryParse(info.deeplink);
    if (deepUri != null && await canLaunchUrl(deepUri)) {
      await launchUrl(deepUri);
      return;
    }
    // Fallback : ouvre le site web
    final webUri = Uri.tryParse(info.fallbackUrl);
    if (webUri != null) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmerPaiement() async {
    if (_paiementInitie == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(_paiementRepoProvider).confirmerPaiement(
            paiementId: _paiementInitie!.id,
            demandeId: widget.demandeId,
            echeanceId: widget.echeanceId,
          );
      setState(() { _confirme = true; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur confirmation : $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payer une échéance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _confirme ? _SuccessView(montant: widget.montant, reference: _paiementInitie!.reference)
          : _paiementInitie != null ? _InstructionsView(
              paiement: _paiementInitie!,
              info: _operateurs.firstWhere((o) => o.operateur == _operateur),
              onOuvrirApp: _ouvrirAppOperateur,
              onConfirmer: _confirmerPaiement,
              isLoading: _loading,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Résumé paiement
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.primary),
                        const SizedBox(height: 10),
                        Text('Échéance ${widget.numeroEcheance}',
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '${fmt.format(widget.montant)} FCFA',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text('Choisissez votre opérateur',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  ..._operateurs.map((info) => _OperateurTile(
                        info: info,
                        selected: _operateur == info.operateur,
                        onTap: () => setState(() => _operateur = info.operateur),
                      )),

                  const SizedBox(height: 28),

                  ElevatedButton.icon(
                    onPressed: _operateur == null || _loading ? null : _initierPaiement,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward),
                    label: const Text('Continuer vers le paiement'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),
                  const _SecuriteNote(),
                ],
              ),
            ),
    );
  }
}

// ── Tile opérateur ────────────────────────────────────────────────────────────

class _OperateurTile extends StatelessWidget {
  final _OperateurInfo info;
  final bool selected;
  final VoidCallback onTap;
  const _OperateurTile({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? info.couleur.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? info.couleur : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: info.couleur.withValues(alpha: 0.15),
              child: Icon(info.logo, color: info.couleur, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.nom, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: info.couleur)),
                  Text(info.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: info.couleur, size: 22)
            else
              const Icon(Icons.radio_button_unchecked, color: AppColors.divider, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Vue instructions ──────────────────────────────────────────────────────────

class _InstructionsView extends StatelessWidget {
  final PaiementModel paiement;
  final _OperateurInfo info;
  final void Function(_OperateurInfo) onOuvrirApp;
  final VoidCallback onConfirmer;
  final bool isLoading;
  const _InstructionsView({
    required this.paiement,
    required this.info,
    required this.onOuvrirApp,
    required this.onConfirmer,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Référence
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: info.couleur.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: info.couleur.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: info.couleur.withValues(alpha: 0.15),
                  child: Icon(info.logo, color: info.couleur, size: 28),
                ),
                const SizedBox(height: 12),
                Text(info.nom, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: info.couleur)),
                const SizedBox(height: 16),
                const Text('Référence de paiement', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: paiement.reference));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Référence copiée'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: info.couleur.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(paiement.reference,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                color: info.couleur)),
                        const SizedBox(width: 10),
                        const Icon(Icons.copy_outlined, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Appuyez pour copier', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Montant
          _InfoRow(label: 'Montant à payer', value: '${fmt.format(paiement.montant)} FCFA', bold: true),
          _InfoRow(label: 'Opérateur', value: info.nom),
          _InfoRow(label: 'Statut', value: 'En attente de confirmation'),

          const SizedBox(height: 20),

          // Étapes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Comment procéder :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                _Step(numero: '1', texte: 'Ouvrez l\'application ${info.nom} sur votre téléphone'),
                _Step(numero: '2', texte: 'Accédez à « Paiement marchand » ou « Payer une facture »'),
                _Step(numero: '3', texte: 'Entrez la référence : ${paiement.reference}'),
                _Step(numero: '4', texte: 'Confirmez le montant : ${fmt.format(paiement.montant)} FCFA'),
                _Step(numero: '5', texte: 'Validez avec votre code PIN ${info.nom}'),
                _Step(numero: '6', texte: 'Revenez ici et appuyez sur « J\'ai payé »'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bouton ouvrir app
          OutlinedButton.icon(
            onPressed: () => onOuvrirApp(info),
            icon: Icon(info.logo, size: 18),
            label: Text('Ouvrir l\'app ${info.nom}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: info.couleur,
              side: BorderSide(color: info.couleur),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: isLoading ? null : onConfirmer,
            icon: isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
            label: const Text('J\'ai payé — Confirmer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          const _SecuriteNote(),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _InfoRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
              flex: 3,
              child: Text(value,
                  style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: bold ? AppColors.primary : AppColors.textPrimary))),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String numero, texte;
  const _Step({required this.numero, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.primary,
            child: Text(numero, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}

// ── Vue succès ────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final double montant;
  final String reference;
  const _SuccessView({required this.montant, required this.reference});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 90),
            const SizedBox(height: 20),
            const Text('Paiement confirmé !',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success)),
            const SizedBox(height: 8),
            Text('${fmt.format(montant)} FCFA',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Réf : $reference',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour aux remboursements'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Note sécurité ─────────────────────────────────────────────────────────────

class _SecuriteNote extends StatelessWidget {
  const _SecuriteNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Paiement sécurisé. GreenAccess ne stocke jamais vos codes PIN ni vos données bancaires.',
              style: TextStyle(fontSize: 11, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Donnée opérateur ──────────────────────────────────────────────────────────

class _OperateurInfo {
  final OperateurMobileMoney operateur;
  final String nom;
  final Color couleur;
  final String description;
  final String deeplink;
  final String fallbackUrl;
  final IconData logo;

  const _OperateurInfo({
    required this.operateur,
    required this.nom,
    required this.couleur,
    required this.description,
    required this.deeplink,
    required this.fallbackUrl,
    required this.logo,
  });
}
