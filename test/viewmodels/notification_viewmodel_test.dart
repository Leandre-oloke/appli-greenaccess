// Tests unitaires de NotificationViewModel (J2.26) — centre de
// notifications : fusion des flux broadcast + personnel, tri, décompte non
// lu, persistance de la date de dernière lecture, suppression.
//
// Contrairement aux autres ViewModels de ce dossier, le constructeur de
// NotificationViewModel a un effet de bord réel (_init() s'abonne à deux
// streams Firestore immédiatement) : on utilise donc le VRAI
// NotificationRepository, backé par un FakeFirebaseFirestore semé au préalable,
// plutôt qu'un fake avec des retours contrôlés — comme dans
// widgets/dashboard_screen_test.dart.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:greenaccess/repositories/notification_repository.dart';
import 'package:greenaccess/viewmodels/notification_viewmodel.dart';

const _userId = 'user_test';

// Les listeners de snapshots() de fake_cloud_firestore émettent de façon
// asynchrone (pas dans le même microtask que l'abonnement) : on laisse
// s'écouler quelques tours de boucle d'événements avant de lire l'état.
Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 50));

Future<FakeFirebaseFirestore> _seededDb({
  List<Map<String, dynamic>> broadcast = const [],
  List<Map<String, dynamic>> personnelles = const [],
}) async {
  final db = FakeFirebaseFirestore();
  for (final n in broadcast) {
    await db.collection('notifications').add(n);
  }
  for (final n in personnelles) {
    await db.collection('users').doc(_userId).collection('notifications').add(n);
  }
  return db;
}

Map<String, dynamic> _notif(String titre, DateTime createdAt, {String type = 'info'}) => {
      'titre': titre,
      'message': 'Message pour $titre',
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
    };

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

ProviderContainer _makeContainer(NotificationRepository repo, SharedPreferences prefs) {
  final container = ProviderContainer(
    overrides: [
      notificationViewModelProvider(_userId).overrideWith(
        (ref) => NotificationViewModel(repo, prefs, _userId),
      ),
    ],
  );
  // StateNotifierProvider est paresseux : sans ce read immédiat, le
  // constructeur de NotificationViewModel (et donc l'abonnement aux streams
  // Firestore fait par _init()) ne démarre qu'au premier accès — trop tard
  // pour que _flush() laisse le temps aux données déjà semées d'arriver.
  container.read(notificationViewModelProvider(_userId));
  return container;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('NotificationViewModel — fusion et tri', () {
    test('fusionne les notifications globales et personnelles, triées par date décroissante',
        () async {
      final now = DateTime.now();
      final db = await _seededDb(
        broadcast: [
          _notif('Ancienne alerte globale', now.subtract(const Duration(days: 2))),
          _notif('Alerte globale récente', now.subtract(const Duration(minutes: 5))),
        ],
        personnelles: [
          _notif('Contrat à renouveler', now.subtract(const Duration(hours: 1))),
        ],
      );
      final container = _makeContainer(NotificationRepository(db: db), await _prefs());
      addTearDown(container.dispose);
      await _flush();

      final state = container.read(notificationViewModelProvider(_userId));
      expect(state.notifications, hasLength(3));
      expect(state.notifications.map((n) => n.titre), [
        'Alerte globale récente',
        'Contrat à renouveler',
        'Ancienne alerte globale',
      ]);
      expect(state.isLoading, isFalse);
    });

    test('limite le nombre de notifications fusionnées à 50', () async {
      final now = DateTime.now();
      final broadcast = List.generate(
        40,
        (i) => _notif('Globale $i', now.subtract(Duration(minutes: i))),
      );
      final personnelles = List.generate(
        20,
        (i) => _notif('Perso $i', now.subtract(Duration(minutes: i))),
      );
      final db = await _seededDb(broadcast: broadcast, personnelles: personnelles);
      final container = _makeContainer(NotificationRepository(db: db), await _prefs());
      addTearDown(container.dispose);
      await _flush();

      final state = container.read(notificationViewModelProvider(_userId));
      expect(state.notifications, hasLength(50));
    });
  });

  group('NotificationViewModel — unreadCount', () {
    test('toutes les notifications sont non lues quand aucune lecture n\'a encore eu lieu',
        () async {
      final now = DateTime.now();
      final db = await _seededDb(broadcast: [
        _notif('A', now.subtract(const Duration(minutes: 10))),
        _notif('B', now.subtract(const Duration(minutes: 5))),
      ]);
      final container = _makeContainer(NotificationRepository(db: db), await _prefs());
      addTearDown(container.dispose);
      await _flush();

      expect(container.read(notificationViewModelProvider(_userId)).unreadCount, 2);
    });

    test('markAllRead() ramène unreadCount à 0 pour les notifications existantes', () async {
      final now = DateTime.now();
      final db = await _seededDb(broadcast: [
        _notif('A', now.subtract(const Duration(minutes: 10))),
        _notif('B', now.subtract(const Duration(minutes: 5))),
      ]);
      final container = _makeContainer(NotificationRepository(db: db), await _prefs());
      addTearDown(container.dispose);
      await _flush();

      await container.read(notificationViewModelProvider(_userId).notifier).markAllRead();

      expect(container.read(notificationViewModelProvider(_userId)).unreadCount, 0);
    });

    test('une notification arrivée après markAllRead() redevient non lue', () async {
      final now = DateTime.now();
      final db = await _seededDb(broadcast: [
        _notif('Avant lecture', now.subtract(const Duration(minutes: 10))),
      ]);
      final container = _makeContainer(NotificationRepository(db: db), await _prefs());
      addTearDown(container.dispose);
      await _flush();

      await container.read(notificationViewModelProvider(_userId).notifier).markAllRead();
      expect(container.read(notificationViewModelProvider(_userId)).unreadCount, 0);

      await db.collection('notifications').add(_notif('Après lecture', DateTime.now().add(const Duration(seconds: 1))));
      await _flush();

      expect(container.read(notificationViewModelProvider(_userId)).unreadCount, 1);
    });

    test('la date de dernière lecture persiste entre deux instances via SharedPreferences',
        () async {
      final now = DateTime.now();
      final db = await _seededDb(broadcast: [
        _notif('A', now.subtract(const Duration(minutes: 10))),
      ]);
      final prefs = await _prefs();
      final repo = NotificationRepository(db: db);

      final vm1 = NotificationViewModel(repo, prefs, _userId);
      await _flush();
      await vm1.markAllRead();
      vm1.dispose();

      // Nouvelle instance (simule un redémarrage de l'app) partageant les
      // mêmes prefs : la notification déjà lue ne doit pas redevenir non lue.
      final vm2 = NotificationViewModel(repo, prefs, _userId);
      await _flush();

      expect(vm2.state.unreadCount, 0);
      vm2.dispose();
    });
  });

  group('NotificationViewModel — delete', () {
    test('delete() supprime bien le document du repository', () async {
      final now = DateTime.now();
      final db = await _seededDb(broadcast: [_notif('À supprimer', now)]);
      final id = (await db.collection('notifications').get()).docs.first.id;
      final container = _makeContainer(NotificationRepository(db: db), await _prefs());
      addTearDown(container.dispose);
      await _flush();
      expect(container.read(notificationViewModelProvider(_userId)).notifications, hasLength(1));

      await container.read(notificationViewModelProvider(_userId).notifier).delete(id);
      await _flush();

      expect(container.read(notificationViewModelProvider(_userId)).notifications, isEmpty);
    });

    test('delete() n\'expose jamais l\'exception du repository (silencieusement ignorée)',
        () async {
      final db = await _seededDb();
      final container = _makeContainer(NotificationRepository(db: db), await _prefs());
      addTearDown(container.dispose);
      await _flush();

      // Aucun document 'inexistant' : fake_cloud_firestore ne lève pas sur un
      // delete() d'id absent, mais le code de NotificationViewModel.delete()
      // avale explicitement toute exception (try { } catch (_) {}) — on
      // vérifie donc simplement l'absence d'exception propagée à l'appelant.
      await expectLater(
        container.read(notificationViewModelProvider(_userId).notifier).delete('id_inexistant'),
        completes,
      );
    });
  });
}
