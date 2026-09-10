import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  String? _verificationId;

  Future<void> sendOtpSms(String phoneNumber) async {
    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
        completer.complete();
      },
      verificationFailed: (e) => completer.completeError(e),
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        completer.complete();
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  Future<UserCredential> verifyOtpCode(String smsCode) async {
    if (_verificationId == null) throw Exception('Aucun code OTP en attente');
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Supprime le compte Firebase Auth de l'utilisateur actuellement connecté
  /// quand son profil Firestore a été retiré par un admin (compte orphelin).
  /// L'utilisateur vient juste de s'authentifier → pas de reauthentification requise.
  Future<void> deleteOrphanedAuthAccount() async {
    await _auth.currentUser?.delete();
  }

  Future<void> saveUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Récupère et sauvegarde le token FCM de l'appareil dans le profil Firestore.
  Future<void> saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({'fcm_token': token});
      }
    } catch (_) {
      // Non bloquant — l'app fonctionne sans FCM token
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Non connecté');
    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Utilisateur introuvable');

    // Re-authentification obligatoire avant suppression (exigé par Firebase).
    final credential = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(credential);

    // Suppression des données Firestore (user doc + sous-collections).
    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);

    final batch = _firestore.batch();
    batch.delete(userRef);

    final subCollections = ['progress', 'badges'];
    for (final col in subCollections) {
      final docs = await userRef.collection(col).get();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();

    // Suppression du compte Firebase Auth.
    await user.delete();
  }
}
