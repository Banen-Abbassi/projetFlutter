// lib/services/call_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallService {
  final _firestore = FirebaseFirestore.instance;
 String get _currentUserId => FirebaseAuth.instance.currentUser!.uid;


  // Fixed document ID for the single active call within the chat
  static const String CALL_DOC_ID = 'active_call';

  // --- Utility Function to get the correct Document Reference ---
  // Path: chats/{chatId}/call/active_call
  DocumentReference _getCallDocRef(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('call') // <-- CORRECT SUB-COLLECTION
        .doc(CALL_DOC_ID);
  }

Future<void> makeCall({
  required String chatId,
  required String receiverId,
  required String channelName,
  required String type,
}) async {

  final callDocRef = _getCallDocRef(chatId);

  print("CALLING makeCall WITH CHAT ID = $chatId");
  print("Writing to: chats/$chatId/call/active_call");

  try {
    // WRITE CALL DOCUMENT
    await callDocRef.set({
      'callerId': _currentUserId,
      'receiverId': receiverId,
      'channelName': channelName,
      'type': type,
      'status': 'ringing',
      'startTime': FieldValue.serverTimestamp(),
    });

    print("CALL SAVED SUCCESSFULLY");

    // READ BACK TO CONFIRM
    final doc = await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("call")
        .doc("active_call")
        .get();

    print("EXISTS = ${doc.exists}");
    print("DATA = ${doc.data()}");

  } catch (e) {
    print("🔥 FIRESTORE ERROR: $e");
  }
}


  // --- 2. Receiver and Caller: Update the call status ---
  Future<void> updateCallStatus({
    required String chatId,
    required String status, // 'accepted', 'rejected', 'ended'
  }) async {
    // When the call is 'ended' or 'rejected', we add the end time.
    final Map<String, dynamic> updateData = {'status': status};
    if (status == 'ended' || status == 'rejected') {
      updateData['endTime'] = FieldValue.serverTimestamp();
    }
    
    await _getCallDocRef(chatId).update(updateData);
  }

  // --- 3. Clean-up: Delete the call document ---
  Future<void> endCall({required String chatId}) async {
    await _getCallDocRef(chatId).delete();
  }

  // --- 4. Incoming Call Listener (GLOBAL LISTENER - THIS METHOD IS REMOVED/IMPOSSIBLE) ---
  /*
  The original implementation of getIncomingCallStream was inefficient and impossible
  with the new sub-collection structure because it tried to query all chats globally.
  
  Since the call state is now hidden inside a sub-collection of a specific chat, 
  you cannot easily query ALL chats where you are the receiver and the status is 'ringing'. 
  
  The reliable way to check for an incoming call is to monitor the status 
  ONLY when the user is already on that specific chat screen, using the next method.
  
  If you need a GLOBAL banner (on the Home Screen), you MUST use a separate 
  top-level 'calls' collection or a 'user_notifications' collection. 
  
  For this integrated model, we remove this method.
  */

  // --- 5. Call Status Listener (Used by both Caller and Receiver) ---
  // This correctly listens to the signaling document within the specific chat.
  Stream<DocumentSnapshot> getCallStatusStream({required String chatId}) {
    // Correctly uses the helper function to point to: chats/{chatId}/call/active_call
    return _getCallDocRef(chatId).snapshots();
  }
}