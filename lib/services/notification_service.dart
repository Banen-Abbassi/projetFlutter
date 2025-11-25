import 'package:flutter/material.dart';

class NotificationService {
  // Use a GlobalKey to access the ScaffoldMessenger from anywhere in the app.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showInAppNotification(
      {required String title, required String body, VoidCallback? onTap}) {
    // Ensure the key is attached to the widget tree.
    if (scaffoldMessengerKey.currentState == null) {
      debugPrint("ScaffoldMessengerKey not available.");
      return;
    }

    // Define the interactive content of the SnackBar.
    final snackBarContent = GestureDetector(
      onTap: () {
        // When tapped, immediately hide the SnackBar and execute the callback.
        scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // A dark, semi-translucent color for a modern look.
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    // Create the SnackBar with a transparent background to let our custom container shine.
    final snackBar = SnackBar(
      content: snackBarContent,
      backgroundColor: Colors.transparent, // Important for custom container style.
      elevation: 0, // No shadow.
      duration: const Duration(seconds: 5), // How long it stays on screen if not dismissed.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );

    // Hide any currently visible SnackBar and then show the new one.
    scaffoldMessengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
/*
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import 'profile_service.dart';

// 1. Créer une instance de FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 2. Définir un gestionnaire de messages d'arrière-plan (Top-level function)
// Ce gestionnaire est exécuté lorsque l'application est en arrière-plan ou terminée.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Si vous utilisez d'autres services Firebase en arrière-plan, vous devez les initialiser ici.
  // Par exemple: await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint("Notification: ${message.notification?.title}");
}

class NotificationService {
  // Clé pour le ScaffoldMessenger (pour les notifications in-app)
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Fonction pour initialiser les notifications locales et FCM
  Future<void> initializeNotifications() async {
    // --- 1. Initialisation des notifications locales (pour les messages au premier plan) ---
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Gérer le tap sur la notification ici
        debugPrint('Notification tapped with payload: ${response.payload}');
      },
    );

    // --- 2. Configuration de Firebase Cloud Messaging (FCM) ---

    // Demander la permission pour les notifications (iOS et Web)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Définir le gestionnaire de messages d'arrière-plan
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Gérer les messages reçus lorsque l'application est ouverte (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      final notification = message.notification;
      if (notification != null) {
        // Afficher la notification locale pour les messages au premier plan
        showLocalNotification(
          title: notification.title ?? 'Nouvelle notification',
          body: notification.body ?? 'Vous avez un nouveau message.',
          payload: message.data.toString(),
        );
        // Optionnel: Afficher une notification in-app (SnackBar)
        showInAppNotification(
          title: notification.title ?? 'Nouvelle notification',
          body: notification.body ?? 'Vous avez un nouveau message.',
          onTap: () {
            // Logique de navigation si l'utilisateur tape sur la SnackBar
            debugPrint('In-app notification tapped');
          },
        );
      }
    });

    // Gérer le tap sur une notification lorsque l'application est en arrière-plan ou terminée
 FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  debugPrint('A new onMessageOpenedApp event was published!');

  // Exemple navigation :
  navigatorKey.currentState?.pushNamed(
    "/chat",
    arguments: message.data,
  );
});


    // Récupérer le token FCM (utile pour l'envoi ciblé)
    String? token = await FirebaseMessaging.instance.getToken();
    debugPrint("FCM Token: $token");

    // Enregistrer le token dans Firestore
    await ProfileSercice().saveFCMToken(token);

    // Écouter les changements de token
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      ProfileSercice().saveFCMToken(newToken);
    });
  }

  // Fonction pour afficher une notification locale (utilisée pour les messages au premier plan)
  static void showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // ID du canal
      'Notifications de Chat', // Nom du canal
      channelDescription: 'Ce canal est utilisé pour les notifications de chat.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails, iOS: iOSDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // ID de la notification
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Fonction existante pour les notifications in-app (SnackBar)
  static void showInAppNotification(
      {required String title, required String body, VoidCallback? onTap}) {
    // Ensure the key is attached to the widget tree.
    if (scaffoldMessengerKey.currentState == null) {
      debugPrint("ScaffoldMessengerKey not available.");
      return;
    }

    // Define the interactive content of the SnackBar.
    final snackBarContent = GestureDetector(
      onTap: () {
        // When tapped, immediately hide the SnackBar and execute the callback.
        scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // A dark, semi-translucent color for a modern look.
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    // Create the SnackBar with a transparent background to let our custom container shine.
    final snackBar = SnackBar(
      content: snackBarContent,
      backgroundColor: Colors.transparent, // Important for custom container style.
      elevation: 0, // No shadow.
      duration: const Duration(seconds: 5), // How long it stays on screen if not dismissed.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );

    // Hide any currently visible SnackBar and then show the new one.
    scaffoldMessengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
*/