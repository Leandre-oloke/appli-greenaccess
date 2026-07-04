import 'package:equatable/equatable.dart';

enum UserRole { user, partenaireAssureur, partenaireFinanceur, admin }

class UserModel extends Equatable {
  final String id;
  final String nom;
  final String email;
  final String telephone;
  final String pays;
  final String region;
  final String secteur;
  final String? gpsZone;
  final DateTime dateInscription;
  final bool profilComplet;
  final UserRole role;

  const UserModel({
    required this.id,
    required this.nom,
    required this.email,
    required this.telephone,
    required this.pays,
    required this.region,
    required this.secteur,
    this.gpsZone,
    required this.dateInscription,
    required this.profilComplet,
    required this.role,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      nom: data['nom'] ?? '',
      email: data['email'] ?? '',
      telephone: data['telephone'] ?? '',
      pays: data['pays'] ?? '',
      region: data['region'] ?? '',
      secteur: data['secteur'] ?? '',
      gpsZone: data['gps_zone'],
      dateInscription: (data['date_inscription'] as dynamic).toDate(),
      profilComplet: data['profil_complet'] ?? false,
      role: UserRole.values.firstWhere(
        (r) => r.name == (data['role'] ?? 'user'),
        orElse: () => UserRole.user,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nom': nom,
        'email': email,
        'telephone': telephone,
        'pays': pays,
        'region': region,
        'secteur': secteur,
        'gps_zone': gpsZone,
        'date_inscription': dateInscription,
        'profil_complet': profilComplet,
        'role': role.name,
      };

  UserModel copyWith({
    String? nom,
    String? telephone,
    String? pays,
    String? region,
    String? secteur,
    String? gpsZone,
    bool? profilComplet,
  }) {
    return UserModel(
      id: id,
      nom: nom ?? this.nom,
      email: email,
      telephone: telephone ?? this.telephone,
      pays: pays ?? this.pays,
      region: region ?? this.region,
      secteur: secteur ?? this.secteur,
      gpsZone: gpsZone ?? this.gpsZone,
      dateInscription: dateInscription,
      profilComplet: profilComplet ?? this.profilComplet,
      role: role,
    );
  }

  @override
  List<Object?> get props => [id, nom, email, telephone, pays, region, secteur, gpsZone, profilComplet, role];
}
