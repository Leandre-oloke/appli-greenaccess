import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../models/assurance_model.dart';
import '../../viewmodels/assurance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Carte interactive des zones à risque climatique (J4.4-J4.6, CDC §3 M4) —
/// fond OpenStreetMap, un marqueur + un cercle de risque par zone (couleur
/// selon le niveau, icône selon le type d'aléa), position GPS optionnelle de
/// l'utilisateur.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      if (uid.isNotEmpty) {
        ref.read(assuranceViewModelProvider(uid).notifier).loadZonesAlea();
      }
    });
  }

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

  void _afficherZone(ZoneAleaModel zone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${zone.nom} — ${_typeLabel(zone.typeAlea)} (risque ${zone.niveauRisque})',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(assuranceViewModelProvider(uid));
    final zones = state.zonesAlea;

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
                        onTap: () => _afficherZone(z),
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

          if (state.isLoading)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),

          if (_gpsError != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Material(
                color: AppColors.error.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(_gpsError!, style: const TextStyle(color: Colors.white)),
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
