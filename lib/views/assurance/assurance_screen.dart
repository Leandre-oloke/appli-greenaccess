import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../models/assurance_model.dart';
import '../../viewmodels/assurance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AssuranceScreen extends ConsumerStatefulWidget {
  const AssuranceScreen({super.key});

  @override
  ConsumerState<AssuranceScreen> createState() => _AssuranceScreenState();
}

class _AssuranceScreenState extends ConsumerState<AssuranceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      if (uid.isEmpty) return;
      ref.read(assuranceViewModelProvider(uid).notifier).loadProduitsParZone('');
      ref.read(assuranceViewModelProvider(uid).notifier).loadContrats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(assuranceViewModelProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(assuranceViewModelProvider(uid)),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('Assurance Climatique'),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1F5C3D), Color(0xFF2E7D52)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.shield, size: 60, color: Colors.white24),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QuickActionsGrid(),
                    const SizedBox(height: 20),
                    if (state.contratActif != null) ...[
                      const _SectionTitle('Contrat actif'),
                      const SizedBox(height: 8),
                      _ContratActifCard(contrat: state.contratActif!),
                      const SizedBox(height: 20),
                    ],
                    const _SectionTitle('Zones à risque climatique'),
                    const SizedBox(height: 8),
                    state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.zonesAlea.isEmpty
                            ? const _EmptyZones()
                            : _ZonesList(zones: state.zonesAlea),
                    const SizedBox(height: 20),
                    const _SectionTitle('Nos produits'),
                    const SizedBox(height: 8),
                    state.produits.isEmpty
                        ? OutlinedButton.icon(
                            onPressed: () => context.push(AppRoutes.fichesProduit),
                            icon: const Icon(Icons.grid_view),
                            label: const Text('Voir tous les produits'),
                          )
                        : _ProduitsPreview(produits: state.produits.take(3).toList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _ActionTile(
          icon: Icons.map_outlined,
          label: 'Carte des aléas',
          color: AppColors.error,
          onTap: () => context.push(AppRoutes.fichesProduit),
        ),
        _ActionTile(
          icon: Icons.grid_view_outlined,
          label: 'Nos produits',
          color: AppColors.primary,
          onTap: () => context.push(AppRoutes.fichesProduit),
        ),
        _ActionTile(
          icon: Icons.calculate_outlined,
          label: 'Simulateur',
          color: AppColors.info,
          onTap: () => context.push(AppRoutes.simulateurAssurance),
        ),
        _ActionTile(
          icon: Icons.folder_outlined,
          label: 'Mes contrats',
          color: AppColors.success,
          onTap: () => context.push(AppRoutes.mesContrats),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) =>
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
}

class _ContratActifCard extends StatelessWidget {
  final ContratAssuranceModel contrat;
  const _ContratActifCard({required this.contrat});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.success.withValues(alpha: 0.08),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.success,
          child: Icon(Icons.shield_outlined, color: Colors.white),
        ),
        title: const Text('Contrat actif', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
        subtitle: Text(
          'Zone: ${contrat.zoneRisque}  ·  Prime: ${contrat.primeMensuelle.toStringAsFixed(0)} FCFA/mois',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.success),
        onTap: () => context.push(AppRoutes.mesContrats),
      ),
    );
  }
}

class _ZonesList extends StatelessWidget {
  final List<ZoneAleaModel> zones;
  const _ZonesList({required this.zones});

  Color _riskColor(String niveau) => switch (niveau) {
        'eleve' || 'très élevé' => AppColors.error,
        'moyen' => AppColors.warning,
        _ => AppColors.scoreBon,
      };

  IconData _riskIcon(String type) => switch (type) {
        'secheresse' => Icons.wb_sunny_outlined,
        'inondation' => Icons.water_outlined,
        'chaleur' => Icons.thermostat_outlined,
        _ => Icons.warning_amber_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: zones
          .take(4)
          .map((z) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_riskIcon(z.typeAlea), color: _riskColor(z.niveauRisque)),
                  title: Text(z.nom, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('${z.typeAlea}  ·  Risque ${z.niveauRisque}'),
                  trailing: OutlinedButton(
                    onPressed: () => context.push(AppRoutes.simulateurAssurance),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Se protéger'),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _ProduitsPreview extends StatelessWidget {
  final List<ProduitAssuranceModel> produits;
  const _ProduitsPreview({required this.produits});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...produits.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.shield_outlined, color: AppColors.primary),
                ),
                title: Text(p.libelle, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                subtitle: Text('${p.primeMin.toStringAsFixed(0)} – ${p.primeMax.toStringAsFixed(0)} FCFA/mois'),
                onTap: () => context.push(AppRoutes.fichesProduit),
              ),
            )),
        TextButton(
          onPressed: () => context.push(AppRoutes.fichesProduit),
          child: const Text('Voir tous les produits →'),
        ),
      ],
    );
  }
}

class _EmptyZones extends StatelessWidget {
  const _EmptyZones();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text('Aucune zone à risque disponible', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
