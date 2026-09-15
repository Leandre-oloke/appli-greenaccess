import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../models/assurance_model.dart';
import '../../viewmodels/assurance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class SimulateurAssuranceScreen extends ConsumerStatefulWidget {
  const SimulateurAssuranceScreen({super.key});

  @override
  ConsumerState<SimulateurAssuranceScreen> createState() => _SimulateurAssuranceScreenState();
}

class _SimulateurAssuranceScreenState extends ConsumerState<SimulateurAssuranceScreen> {
  String _zone = 'Sénégal';
  String _typeAlea = 'secheresse';
  double _superficieCultivee = 1.0;
  double _valeurAssurable = 500000;
  bool _simulated = false;
  bool _zonePreremplieParGps = false;

  static const _zones = ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso', 'Niger', 'Togo', 'Guinée'];
  static const _typeAleaList = ['secheresse', 'inondation', 'chaleur', 'multirisque'];
  static const _typeLabels = {
    'secheresse': 'Sécheresse',
    'inondation': 'Inondation',
    'chaleur': 'Stress thermique',
    'multirisque': 'Multirisques',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preremplirZoneDepuisGps());
  }

  /// Ciblage GPS automatique (J4.10) : ne pré-remplit que si la permission
  /// de localisation a déjà été accordée ailleurs dans l'app — ne déclenche
  /// jamais de demande de permission depuis cet écran, pour ne pas
  /// surprendre l'utilisateur avec une invite qu'il n'a pas demandée ici.
  Future<void> _preremplirZoneDepuisGps() async {
    try {
      final permission = await Geolocator.checkPermission();
      final autorise =
          permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      if (!autorise) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final zones = await ref.read(zonesAleaProvider.future);
      if (!mounted || zones.isEmpty) return;

      final proche = _zonePlusProche(pos.latitude, pos.longitude, zones);
      if (proche != null && _zones.contains(proche.pays)) {
        setState(() {
          _zone = proche.pays;
          _zonePreremplieParGps = true;
        });
      }
    } catch (_) {
      // Non bloquant — le simulateur reste utilisable avec la zone par défaut.
    }
  }

  ZoneAleaModel? _zonePlusProche(double lat, double lng, List<ZoneAleaModel> zones) {
    ZoneAleaModel? plusProche;
    double? distMin;
    for (final z in zones) {
      final dLat = lat - z.latitude;
      final dLng = lng - z.longitude;
      final dist = dLat * dLat + dLng * dLng; // distance approx. suffisante pour classer
      if (distMin == null || dist < distMin) {
        distMin = dist;
        plusProche = z;
      }
    }
    return plusProche;
  }

  void _simulate() {
    final uid = ref.read(authViewModelProvider).user?.id ?? '';
    final scoreClimat =
        ref.read(scoringViewModelProvider(uid)).currentScore?.scoreTotal;
    ref.read(assuranceViewModelProvider(uid).notifier).simulerPrime(
      zone: _zone,
      typeAlea: _typeAlea,
      superficieCultivee: _superficieCultivee,
      valeurAssurable: _valeurAssurable,
      scoreClimat: scoreClimat,
    );
    setState(() => _simulated = true);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(assuranceViewModelProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Simulateur d\'assurance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InputCard(
              zone: _zone,
              typeAlea: _typeAlea,
              superficie: _superficieCultivee,
              valeur: _valeurAssurable,
              zones: _zones,
              typeList: _typeAleaList,
              typeLabels: _typeLabels,
              zonePreremplieParGps: _zonePreremplieParGps,
              onZone: (v) => setState(() {
                _zone = v!;
                _zonePreremplieParGps = false; // choix manuel : le badge GPS ne s'applique plus
              }),
              onType: (v) => setState(() => _typeAlea = v!),
              onSuperficie: (v) => setState(() => _superficieCultivee = v),
              onValeur: (v) => setState(() => _valeurAssurable = v),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _simulate,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Calculer ma prime'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
            ),
            if (_simulated && state.simulation != null) ...[
              const SizedBox(height: 20),
              _ResultCard(
                simulation: state.simulation!,
                onSouscrire: () => context.push(AppRoutes.souscription),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final String zone, typeAlea;
  final double superficie, valeur;
  final List<String> zones, typeList;
  final Map<String, String> typeLabels;
  final bool zonePreremplieParGps;
  final void Function(String?) onZone, onType;
  final void Function(double) onSuperficie, onValeur;

  const _InputCard({
    required this.zone, required this.typeAlea, required this.superficie,
    required this.valeur, required this.zones, required this.typeList,
    required this.typeLabels, required this.zonePreremplieParGps,
    required this.onZone, required this.onType,
    required this.onSuperficie, required this.onValeur,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paramètres de simulation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: zone,
              decoration: const InputDecoration(labelText: 'Zone géographique'),
              items: zones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
              onChanged: onZone,
            ),
            if (zonePreremplieParGps) ...[
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.my_location, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text('Détectée via votre position',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: typeAlea,
              decoration: const InputDecoration(labelText: 'Type de risque à couvrir'),
              items: typeList.map((t) => DropdownMenuItem(
                value: t,
                child: Text(typeLabels[t] ?? t),
              )).toList(),
              onChanged: onType,
            ),
            const SizedBox(height: 16),
            Text('Superficie cultivée : ${superficie.toStringAsFixed(1)} ha',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(value: superficie, min: 0.5, max: 20, divisions: 39,
                label: '${superficie.toStringAsFixed(1)} ha', onChanged: onSuperficie),
            const SizedBox(height: 8),
            Text('Valeur assurable : ${valeur.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(value: valeur, min: 100000, max: 5000000, divisions: 49,
                label: '${(valeur / 1000).toStringAsFixed(0)}k', onChanged: onValeur),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SimulationAssuranceResult simulation;
  final VoidCallback onSouscrire;
  const _ResultCard({required this.simulation, required this.onSouscrire});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF6A1B9A).withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF6A1B9A)),
                SizedBox(width: 8),
                Text('Résultat de simulation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 20),
            _ResultRow('Produit recommandé', simulation.produitRecommande.libelle),
            const SizedBox(height: 8),
            _ResultRow('Prime mensuelle estimée', '${simulation.primeEstimee.toStringAsFixed(0)} FCFA/mois'),
            if (simulation.remiseScorePct > 0) ...[
              const SizedBox(height: 6),
              _ResultRow('Réduction Score Climat', '-${simulation.remiseScorePct} %',
                  valeurColor: AppColors.success),
            ],
            const SizedBox(height: 6),
            _ResultRow('Indemnisation maximale', '${simulation.indemnisationEstimee.toStringAsFixed(0)} FCFA'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                simulation.raisonRecommandation,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSouscrire,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Souscrire à ce produit'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String k, v;
  final Color? valeurColor;
  const _ResultRow(this.k, this.v, {this.valeurColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        Expanded(
          flex: 3,
          child: Text(v,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: valeurColor)),
        ),
      ],
    );
  }
}
