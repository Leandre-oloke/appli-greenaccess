import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/assurance_model.dart';
import 'cours_repository.dart';

class AssuranceRepository {
  final FirebaseFirestore _firestore;

  // Lazy pour éviter FirebaseStorage.instance en test quand le repo est sous-classé.
  final FirebaseStorage? _storageOverride;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  AssuranceRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storageOverride = storage;

  Future<List<ProduitAssuranceModel>> getProduitsParZone(String zone) async {
    final snapshot = await _firestore
        .collection('produits_assurance')
        .where('zones_eligibles', arrayContains: zone)
        .get();
    return snapshot.docs
        .map((doc) => ProduitAssuranceModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<List<ProduitAssuranceModel>> getAllProduits() async {
    final snapshot = await _firestore.collection('produits_assurance').get();
    return snapshot.docs
        .map((doc) => ProduitAssuranceModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<ContratAssuranceModel> soumettreDossier(Map<String, dynamic> dossier) async {
    final doc = await _firestore.collection('contrats_assurance').add({
      ...dossier,
      'statut': StatutContrat.soumis.name,
      'date_debut': FieldValue.serverTimestamp(),
    });
    final created = await doc.get();
    final contrat = ContratAssuranceModel.fromFirestore(created.data()!, doc.id);

    // Badge "Assuré Climat" à la première souscription
    await CoursRepository(firestore: _firestore)
        .triggerAssureClimatBadge(contrat.userId);

    return contrat;
  }

  Future<List<ContratAssuranceModel>> getContrats(String userId) async {
    final snapshot = await _firestore
        .collection('contrats_assurance')
        .where('userId', isEqualTo: userId)
        .get();
    final contrats = snapshot.docs
        .map((doc) => ContratAssuranceModel.fromFirestore(doc.data(), doc.id))
        .toList();
    contrats.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
    return contrats;
  }

  Future<List<ZoneAleaModel>> getZonesAlea() async {
    final snapshot = await _firestore.collection('zones_alea').get();
    return snapshot.docs
        .map((doc) => ZoneAleaModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Upload un document de souscription vers Firebase Storage.
  /// Retourne l'URL de téléchargement publique.
  Future<String> uploadDocument({
    required String userId,
    required String contratId,
    required File file,
    required String nomDocument,
  }) async {
    final ext = file.path.split('.').last;
    final ref = _storage
        .ref()
        .child('contrats/$userId/$contratId/$nomDocument.$ext');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// Met à jour la liste des URLs de documents d'un contrat dans Firestore.
  Future<void> ajouterDocumentUrl(String contratId, String url) async {
    await _firestore.collection('contrats_assurance').doc(contratId).update({
      'docs_url': FieldValue.arrayUnion([url]),
    });
  }

  /// Soumet une déclaration de sinistre et uploade les photos vers Storage.
  /// Retourne l'ID du sinistre créé.
  Future<String> declarerSinistre({
    required String userId,
    required String contratId,
    required String typeSinistre,
    required String description,
    required DateTime dateSinistre,
    List<File> photos = const [],
  }) async {
    // Upload des photos en parallèle
    final photoUrls = <String>[];
    if (photos.isNotEmpty) {
      final urls = await Future.wait(photos.asMap().entries.map((e) async {
        final ext = e.value.path.split('.').last;
        final ref = _storage
            .ref()
            .child('sinistres/$userId/$contratId/photo_${e.key}.$ext');
        final task = await ref.putFile(e.value);
        return task.ref.getDownloadURL();
      }));
      photoUrls.addAll(urls);
    }

    // Création du document sinistre
    final doc = await _firestore.collection('sinistres').add({
      'userId': userId,
      'contratId': contratId,
      'typeSinistre': typeSinistre,
      'description': description,
      'dateSinistre': Timestamp.fromDate(dateSinistre),
      'photoUrls': photoUrls,
      'statut': 'en_attente',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mise à jour du statut du contrat
    await _firestore
        .collection('contrats_assurance')
        .doc(contratId)
        .update({'statut': StatutContrat.sinistre.name});

    return doc.id;
  }

  /// Sinistres déclarés par un utilisateur (toutes zones/contrats confondus)
  /// — utilisé par l'export RGPD (J3.4), pas encore exposé ailleurs dans l'app.
  Future<List<SinistreModel>> getSinistres(String userId) async {
    final snapshot = await _firestore
        .collection('sinistres')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => SinistreModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }
}
