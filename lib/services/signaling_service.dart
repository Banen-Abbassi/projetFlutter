import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send offer to receiver
  Future<void> sendOffer({
    required String from,
    required String to,
    required RTCSessionDescription offer,
  }) async {
    try {
      await _firestore
          .collection('signaling')
          .doc(to)
          .collection('offers')
          .add({
        'from': from,
        'to': to,
        'sdp': offer.sdp,
        'type': offer.type,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending offer: $e');
      rethrow;
    }
  }

  // Send answer to caller
  Future<void> sendAnswer({
    required String from,
    required String to,
    required RTCSessionDescription answer,
  }) async {
    try {
      await _firestore
          .collection('signaling')
          .doc(to)
          .collection('answers')
          .add({
        'from': from,
        'to': to,
        'sdp': answer.sdp,
        'type': answer.type,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending answer: $e');
      rethrow;
    }
  }

  // Send ICE candidate
  Future<void> sendIceCandidate({
    required String from,
    required String to,
    required RTCIceCandidate candidate,
  }) async {
    try {
      await _firestore
          .collection('signaling')
          .doc(to)
          .collection('candidates')
          .add({
        'from': from,
        'to': to,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending ICE candidate: $e');
    }
  }

  // Send call ended notification
  Future<void> sendCallEnded({
    required String from,
    required String to,
    required String callId,
  }) async {
    try {
      await _firestore
          .collection('signaling')
          .doc(to)
          .collection('call_ended')
          .add({
        'from': from,
        'to': to,
        'callId': callId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending call ended: $e');
      rethrow;
    }
  }

  // Listen for incoming offers
  Stream<Map<String, dynamic>> listenForOffers(String userId) {
    return _firestore
        .collection('signaling')
        .doc(userId)
        .collection('offers')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .handleError((error) => print('Error listening for offers: $error'))
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return {};
      final doc = snapshot.docs.first;
      return {
        'from': doc['from'],
        'sdp': doc['sdp'],
        'type': doc['type'],
      };
    });
  }

  // Listen for answers
  Stream<Map<String, dynamic>> listenForAnswers(String userId) {
    return _firestore
        .collection('signaling')
        .doc(userId)
        .collection('answers')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .handleError((error) => print('Error listening for answers: $error'))
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return {};
      final doc = snapshot.docs.first;
      return {
        'from': doc['from'],
        'sdp': doc['sdp'],
        'type': doc['type'],
      };
    });
  }

  // Listen for ICE candidates
  Stream<Map<String, dynamic>> listenForIceCandidates(String userId) {
    return _firestore
        .collection('signaling')
        .doc(userId)
        .collection('candidates')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((error) => print('Error listening for ICE candidates: $error'))
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return {};
      final doc = snapshot.docs.first;
      return {
        'from': doc['from'],
        'candidate': doc['candidate'],
        'sdpMid': doc['sdpMid'],
        'sdpMLineIndex': doc['sdpMLineIndex'],
      };
    });
  }

  // Listen for call ended events
  Stream<Map<String, dynamic>> listenForCallEnded(String userId) {
    return _firestore
        .collection('signaling')
        .doc(userId)
        .collection('call_ended')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .handleError((error) => print('Error listening for call ended: $error'))
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return {};
      final doc = snapshot.docs.first;
      return {
        'from': doc['from'],
        'callId': doc['callId'],
      };
    });
  }

  // Cleanup signaling data
  Future<void> cleanupSignaling(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Get all collections to clean up
      final collections = ['offers', 'answers', 'candidates', 'call_ended'];
      
      for (final collection in collections) {
        final docs = await _firestore
            .collection('signaling')
            .doc(userId)
            .collection(collection)
            .get();
        
        for (var doc in docs.docs) {
          batch.delete(doc.reference);
        }
      }
      
      await batch.commit();
    } catch (e) {
      print('Error cleaning up signaling data: $e');
    }
  }
}