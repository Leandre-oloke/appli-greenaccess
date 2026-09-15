import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/assurance_model.dart';
import '../../repositories/assurance_repository.dart';
import '../../utils/error_mapper.dart';
import '../../viewmodels/assurance_viewmodel.dart';

/// Import/gestion admin des zones d'aléa climatique (J4.15, CDC §4.2) — permet
/// de peupler/rafraîchir la collection Firestore `zones_alea` à partir du
/// jeu de données bundlé (`assets/data/zones_alea.json`) sans redéploiement
/// de l'app, et de retirer une zone au besoin.
class AdminZonesAleaScreen extends ConsumerStatefulWidget {
  const AdminZonesAleaScreen({super.key});

  @override
  ConsumerState<AdminZonesAleaScreen> createState() => _AdminZonesAleaScreenState();
}

class _AdminZonesAleaScreenState extends ConsumerState<AdminZonesAleaScreen> {
  bool _importing = false;

  Future<void> _importer() async {
    setState(() => _importing = true);
    try {
      await AssuranceRepository().importDefaultZonesAlea();
      ref.invalidate(zonesAleaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zones importées avec succès.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mapErrorToMessage(e, fallback: "Échec de l'import. Réessayez.")),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _supprimer(ZoneAleaModel zone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette zone ?'),
        content: Text(
          '« ${zone.nom} » sera retirée de Firestore. Le fichier bundlé dans l\'app reste '
          'inchangé — un nouvel import la recréera.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AssuranceRepository().deleteZoneAlea(zone.id);
    ref.invalidate(zonesAleaProvider);
  }

  Color _riskColor(String niveau) => switch (niveau) {
        'eleve' => AppColors.error,
        'moyen' => AppColors.warning,
        _ => AppColors.scoreBon,
      };

  IconData _typeIcon(String type) => switch (type) {
        'secheresse' => Icons.wb_sunny_outlined,
        'inondation' => Icons.water_outlined,
        'chaleur' => Icons.thermostat_outlined,
        _ => Icons.warning_amber_outlined,
      };

  String _typeLabel(String type) => switch (type) {
        'secheresse' => 'Sécheresse',
        'inondation' => 'Inondation',
        'chaleur' => 'Chaleur',
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesAleaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zones d\'aléa climatique'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _importer,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _importing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.cloud_upload_outlined),
        label: Text(_importing ? 'Import en cours…' : 'Importer les zones par défaut'),
      ),
      body: zonesAsync.when(
        data: (zones) => zones.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aucune zone enregistrée. Importez le jeu de données par défaut '
                    'pour démarrer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: zones.length,
                itemBuilder: (context, i) {
                  final zone = zones[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _riskColor(zone.niveauRisque).withValues(alpha: 0.15),
                      child: Icon(_typeIcon(zone.typeAlea), color: _riskColor(zone.niveauRisque)),
                    ),
                    title: Text('${zone.nom} (${zone.pays})',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${_typeLabel(zone.typeAlea)} · Risque ${zone.niveauRisque} · '
                      'Rayon ${zone.rayon.toStringAsFixed(0)} km',
                    ),
                    trailing: IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => _supprimer(zone),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(mapErrorToMessage(e, fallback: 'Impossible de charger les zones.')),
        ),
      ),
    );
  }
}
