import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../models/assurance_model.dart';
import '../../viewmodels/assurance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class FichesProduitScreen extends ConsumerStatefulWidget {
  const FichesProduitScreen({super.key});

  @override
  ConsumerState<FichesProduitScreen> createState() => _FichesProduitScreenState();
}

class _FichesProduitScreenState extends ConsumerState<FichesProduitScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      ref.read(assuranceViewModelProvider(uid).notifier).loadProduitsParZone('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(assuranceViewModelProvider(uid));

    // Afficher produits Firestore ou les produits statiques si vide
    final produits = state.produits.isNotEmpty ? state.produits : _staticProduits;

    return Scaffold(
      appBar: AppBar(title: const Text('Produits d\'assurance')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: produits.length,
              itemBuilder: (_, i) => _ProduitCard(produit: produits[i]),
            ),
    );
  }
}

final _staticProduits = [
  ProduitAssuranceModel(
    id: 'secheresse_01',
    libelle: 'Assurance Sécheresse Agricole',
    type: 'secheresse',
    description: 'Couverture contre les épisodes de sécheresse prolongée affectant les rendements agricoles. '
        'Déclenchement automatique basé sur l\'indice de précipitations (< 60% de la normale sur 30 jours).',
    conditions: 'Producteur agricole actif avec 0,5 ha minimum. Score Climat ≥ 50.',
    primeMin: 5000,
    primeMax: 25000,
    zonesEligibles: ['Sahel', 'Sénégal', 'Mali', 'Burkina Faso', 'Niger'],
    indiceDeclencheur: 'Précipitations < 60% normale sur 30j',
  ),
  ProduitAssuranceModel(
    id: 'inondation_01',
    libelle: 'Assurance Inondation & Crues',
    type: 'inondation',
    description: 'Protection contre les inondations et crues soudaines. Indemnisation directe au producteur '
        'sans expertise terrain. Basé sur données pluviométriques satellites.',
    conditions: 'Zone de culture < 5 km d\'un cours d\'eau. Score Climat ≥ 45.',
    primeMin: 4000,
    primeMax: 20000,
    zonesEligibles: ['Bénin', 'Côte d\'Ivoire', 'Guinée', 'Sénégal'],
    indiceDeclencheur: 'Précipitations > 150% normale sur 3j',
  ),
  ProduitAssuranceModel(
    id: 'chaleur_01',
    libelle: 'Assurance Stress Thermique',
    type: 'chaleur',
    description: 'Couverture des pertes liées aux vagues de chaleur extrêmes. '
        'Déclencheur: température maximale > 40°C pendant 5 jours consécutifs.',
    conditions: 'Agriculture pluviale ou maraîchage. Badge "Résilience Thermique" recommandé.',
    primeMin: 3000,
    primeMax: 15000,
    zonesEligibles: ['Burkina Faso', 'Mali', 'Niger', 'Sénégal'],
    indiceDeclencheur: 'Tmax > 40°C pendant 5 jours consécutifs',
  ),
  ProduitAssuranceModel(
    id: 'multirisque_01',
    libelle: 'Multirisques Climatiques Premium',
    type: 'multirisque',
    description: 'Couverture complète : sécheresse + inondation + stress thermique. '
        'Recommandé pour exploitations de + de 2 ha. Score Climat ≥ 60 requis.',
    conditions: 'Exploitation ≥ 2 ha. Score Climat ESG ≥ 60/100. Certifications préférées.',
    primeMin: 10000,
    primeMax: 50000,
    zonesEligibles: ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso'],
    indiceDeclencheur: 'Combiné sécheresse + inondation + chaleur',
  ),
];

class _ProduitCard extends StatelessWidget {
  final ProduitAssuranceModel produit;
  const _ProduitCard({required this.produit});

  Color _typeColor() => switch (produit.type) {
        'secheresse' => const Color(0xFFE65100),
        'inondation' => AppColors.info,
        'chaleur' => const Color(0xFFBF360C),
        _ => const Color(0xFF6A1B9A),
      };

  IconData _typeIcon() => switch (produit.type) {
        'secheresse' => Icons.wb_sunny_outlined,
        'inondation' => Icons.water_outlined,
        'chaleur' => Icons.thermostat_outlined,
        _ => Icons.shield_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final color = _typeColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Icon(_typeIcon(), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(produit.libelle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(produit.type.toUpperCase(),
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produit.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13)),
                const SizedBox(height: 12),
                _InfoChip(Icons.flash_on_outlined, 'Déclencheur', produit.indiceDeclencheur),
                const SizedBox(height: 6),
                _InfoChip(Icons.payments_outlined, 'Prime mensuelle',
                    '${produit.primeMin.toStringAsFixed(0)} – ${produit.primeMax.toStringAsFixed(0)} FCFA'),
                const SizedBox(height: 6),
                _InfoChip(Icons.check_circle_outline, 'Conditions', produit.conditions),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.simulateurAssurance),
                        icon: const Icon(Icons.calculate_outlined, size: 16),
                        label: const Text('Simuler'),
                        style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(AppRoutes.souscription),
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Souscrire'),
                        style: ElevatedButton.styleFrom(backgroundColor: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoChip(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              children: [
                TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
