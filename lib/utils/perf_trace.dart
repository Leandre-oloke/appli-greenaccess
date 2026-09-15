import 'package:firebase_performance/firebase_performance.dart';

/// Trace de performance des écrans/opérations clés (J6.6, CDC §7.1 · T10) —
/// best-effort, ne lève jamais : `FirebasePerformance.instance` exige
/// `Firebase.initializeApp()`, absent des tests unitaires/widgets de ce
/// dépôt (repositories/ViewModels construits directement avec
/// `fake_cloud_firestore`, sans app Firebase réelle). Sans ce garde-fou,
/// instrumenter une méthode de repository casserait tous les tests qui la
/// construisent sans Firebase — même esprit que le reste du code
/// "best-effort" de l'app (`NotificationService.sendBestEffort`, J5.8).
Future<T> tracedOperation<T>(String traceName, Future<T> Function() operation) async {
  Trace? trace;
  try {
    trace = FirebasePerformance.instance.newTrace(traceName);
    await trace.start();
  } catch (_) {
    trace = null;
  }
  try {
    return await operation();
  } finally {
    try {
      await trace?.stop();
    } catch (_) {
      // best-effort : un échec d'arrêt de trace ne doit jamais faire
      // remonter d'erreur à l'appelant.
    }
  }
}
