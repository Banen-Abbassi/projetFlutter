import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Sets up the listeners for the current user's presence.
  void setupPresence() {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userStatusRef = _database.ref('status/$uid');

    final onlineData = {
      'state': 'online',
      'last_changed': ServerValue.timestamp,
    };

    final offlineData = {
      'state': 'offline',
      'last_changed': ServerValue.timestamp,
    };

    // Listen for connection state changes to RTDB.
    _database.ref('.info/connected').onValue.listen((event) {
      if (event.snapshot.value == false) {
        // We are not connected to the RTDB server, do nothing.
        return;
      }

      // If we are connected, we set our 'onDisconnect' handler.
      // This is the "last will and testament" that the server will execute if we disconnect.
      userStatusRef.onDisconnect().set(offlineData).then((_) {
        // Once the onDisconnect is set, we can safely set our current state to online.
        userStatusRef.set(onlineData);
      });
    });
  }

  /// Manually sets the user's state to offline.
  /// This is useful when the user explicitly logs out.
  void goOffline() {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final offlineData = {
      'state': 'offline',
      'last_changed': ServerValue.timestamp,
    };

    _database.ref('status/${user.uid}').set(offlineData);
  }
}