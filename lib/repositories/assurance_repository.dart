import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assurance_model.dart';

class AssuranceRepository {
  final FirebaseFirestore _firestore;

  AssuranceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
    return ContratAssuranceModel.fromFirestore(created.data()!, doc.id);
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
}
