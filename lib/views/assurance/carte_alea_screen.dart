import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../models/assurance_model.dart';
import '../../routes.dart';
import '../../viewmodels/assurance_viewmodel.dart';

/// Carte interactive des zones à risque climatique (J4.4-J4.9, CDC §3 M4) —
/// fond OpenStreetMap, un marqueur + un cercle de risque par zone (couleur
/// selon le niveau, icône selon le type d'aléa), position GPS optionnelle de
/// l'utilisateur, et une feuille de produits d'assurance éligibles au tap
/// sur une zone.
class CarteAleaScreen extends ConsumerStatefulWidget {
  const CarteAleaScreen({super.key});

  @override
  ConsumerState<CarteAleaScreen> createState() => _CarteAleaScreenState();
}

class _CarteAleaScreenState extends ConsumerState<CarteAleaScreen> {
  // Centre approximatif de la zone UEMOA couverte par assets/data/zones_alea.json.
  static const _centreDefaut = LatLng(12.0, -5.0);
  static const _zoomDefaut = 4.5;
  static const _zoomLocalise = 8.0;

  final _mapController = MapController();
  LatLng? _position;
  bool _gpsLoading = false;
  String? _gpsError;

  Future<void> _localiser() async {
    setState(() {
      _gpsLoading = true;
      _gpsError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsError = 'Permission de localisation refusée.';
          _gpsLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final position = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _position = position;
        _gpsLoading = false;
      });
      _mapController.move(position, _zoomLocalise);
    } catch (e) {
      setState(() {
        _gpsError = 'Erreur GPS. Réessayez.';
        _gpsLoading = false;
      });
    }
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

  void _ouvrirProduitsZone(ZoneAleaModel zone) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ZoneProduitsSheet(
        zone: zone,
        riskColor: _riskColor,
        typeLabel: _typeLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesAleaProvider);
    final zones = zonesAsync.valueOrNull ?? const <ZoneAleaModel>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Carte des aléas climatiques')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _centreDefaut,
              initialZoom: _zoomDefaut,
              minZoom: 3,
              maxZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.greenaccess.greenaccess',
              ),
              CircleLayer(
                circles: zones
                    .map((z) => CircleMarker(
                          point: LatLng(z.latitude, z.longitude),
                          radius: z.rayon * 1000, // km → m
                          useRadiusInMeter: true,
                          color: _riskColor(z.niveauRisque).withValues(alpha: 0.18),
                          borderColor: _riskColor(z.niveauRisque),
                          borderStrokeWidth: 2,
                        ))
                    .toList(),
              ),
              MarkerLayer(
                markers: [
                  ...zones.map(
                    (z) => Marker(
                      point: LatLng(z.latitude, z.longitude),
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => _ouvrirProduitsZone(z),
                        child: Tooltip(
                          message: '${z.nom} — ${_typeLabel(z.typeAlea)}',
                          child: Icon(_typeIcon(z.typeAlea),
                              color: _riskColor(z.niveauRisque), size: 28),
                        ),
                      ),
                    ),
                  ),
                  if (_position != null)
                    Marker(
                      point: _position!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle,
                          color: AppColors.primary, size: 36),
                    ),
                ],
              ),
            ],
          ),

          if (zonesAsync.isLoading)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),

          if (_gpsError != null || zonesAsync.hasError)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Material(
                color: AppColors.error.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    _gpsError ?? 'Zones à risque indisponibles. Tirez pour réessayer.',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _Legende(riskColor: _riskColor, typeIcon: _typeIcon, typeLabel: _typeLabel),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _gpsLoading ? null : _localiser,
        tooltip: 'Me localiser',
        child: _gpsLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  final Color Function(String) riskColor;
  final IconData Function(String) typeIcon;
  final String Function(String) typeLabel;

  const _Legende({
    required this.riskColor,
    required this.typeIcon,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    const types = ['secheresse', 'inondation', 'chaleur'];
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 16,
          runSpacing: 6,
          children: types
              .map((t) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon(t), size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(typeLabel(t), style: const TextStyle(fontSize: 12)),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/// Feuille de produits d'assurance éligibles pour une zone tapée sur la
/// carte (J4.9) — relie la carte des aléas à l'offre d'assurance.
class _ZoneProduitsSheet extends ConsumerWidget {
  final ZoneAleaModel zone;
  final Color Function(String) riskColor;
  final String Function(String) typeLabel;

  const _ZoneProduitsSheet({
    required this.zone,
    required this.riskColor,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produitsAsync = ref.watch(produitsParZoneProvider(zone.nom));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: riskColor(zone.niveauRisque)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(zone.nom,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${typeLabel(zone.typeAlea)} · Risque ${zone.niveauRisque}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const Text('Produits d\'assurance éligibles',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            produitsAsync.when(
              data: (produits) => produits.isEmpty
                  ? _AucunProduitEligible(onVoirTous: () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.fichesProduit);
                    })
                  : Column(children: produits.map((p) => _ProduitTile(produit: p)).toList()),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text(
                'Erreur de chargement des produits. Réessayez.',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProduitTile extends StatelessWidget {
  final ProduitAssuranceModel produit;
  const _ProduitTile({required this.produit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(Icons.shield_outlined, color: AppColors.primary),
        ),
        title: Text(produit.libelle, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${produit.primeMin.toStringAsFixed(0)} – ${produit.primeMax.toStringAsFixed(0)} FCFA/mois',
        ),
        trailing: OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push(AppRoutes.simulateurAssurance);
          },
          child: const Text('Simuler'),
        ),
      ),
    );
  }
}

class _AucunProduitEligible extends StatelessWidget {
  final VoidCallback onVoirTous;
  const _AucunProduitEligible({required this.onVoirTous});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aucun produit éligible pour cette zone pour le moment.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onVoirTous,
            icon: const Icon(Icons.grid_view),
            label: const Text('Voir tous les produits'),
          ),
        ],
      ),
    );
  }
}
