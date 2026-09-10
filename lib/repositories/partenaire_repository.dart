import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/partenaire_model.dart';

class PartenaireRepository {
  final FirebaseFirestore _firestore;

  PartenaireRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('partenaires');

  Future<List<PartenaireModel>> fetchAll() async {
    final snap = await _col.orderBy('nom').get();
    return snap.docs.map((d) => PartenaireModel.fromFirestore(d.data(), d.id)).toList();
  }

  Future<PartenaireModel> create(PartenaireModel p) async {
    final doc = await _col.add(p.toFirestore());
    final created = await doc.get();
    return PartenaireModel.fromFirestore(created.data()!, created.id);
  }

  Future<void> update(PartenaireModel p) async {
    await _col.doc(p.id).update(p.toFirestore());
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> toggleActif(String id, bool actif) async {
    await _col.doc(id).update({'actif': actif});
  }
}
