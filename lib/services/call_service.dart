import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'call_data.dart';
import 'call_result.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Start a call
  Future<CallResult> startCall({
    required String callerId,
    required String receiverId,
    required String callerName,
    required String receiverName,
    required CallType callType,
  }) async {
    try {
      final callRef = _firestore.collection('calls').doc();
      
      final callData = CallData(
        callId: callRef.id,
        callerId: callerId,
        receiverId: receiverId,
        callerName: callerName,
        receiverName: receiverName,
        callType: callType,
        status: CallStatus.ringing,
        startedAt: DateTime.now(),
        answeredAt: null,
        endedAt: null,
      );

      await callRef.set(callData.toMap());

      return CallResult(
        success: true,
        callId: callRef.id,
      );
    } catch (e) {
      return CallResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Accept call
  Future<void> acceptCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ongoing.toString().split('.').last,
        'answeredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }


Future<void> endCall(String callId) async {
  try {
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .update({
          'status': CallStatus.ended.toString().split('.').last,
          'endedAt': FieldValue.serverTimestamp(),
        });
  } catch (e) {
    print('Error ending call in Firestore: $e');
    rethrow;
  }
}

  // Mark as missed
  Future<void> markCallAsMissed(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.missed.toString().split('.').last,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking call as missed: $e');
    }
  }

  Future<CallData?> getCall(String callId) async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      return doc.exists ? CallData.fromMap(doc.data()!) : null;
    } catch (e) {
      return null;
    }
  }

  Stream<CallData> listenForIncomingCalls(String userId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', whereIn: ['ringing', 'ongoing'])
        .snapshots()
        .asyncMap((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || 
            change.type == DocumentChangeType.modified) {
          return CallData.fromMap(change.doc.data()!);
        }
      }
      throw Exception('No incoming calls');
    });
  }

  // Get call stream
  Stream<CallData> getCallStream(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((snapshot) => CallData.fromMap(snapshot.data()!));
  }

  // Get call history
  Stream<List<CallData>> getCallHistory(String userId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CallData.fromMap(doc.data()))
            .toList());
  }
}