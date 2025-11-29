import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'call_data.dart';
import 'call_result.dart';
import 'unified_call_service.dart';

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  final UnifiedCallService _callService = UnifiedCallService();
  String? _currentUserId;

  // Initialize with current user ID
  void initialize(String userId) {
    _currentUserId = userId;
  }

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  // Listen for incoming calls
  Stream<CallData> listenForIncomingCalls() {
    if (_currentUserId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .asyncMap((snapshot) async {
          final calls = <CallData>[];
          for (final doc in snapshot.docs) {
            try {
              final callData = CallData.fromMap(doc.data());
              calls.add(callData);
            } catch (e) {
              print('Error parsing call data: $e');
            }
          }
          return calls;
        })
        .expand((calls) => calls);
  }

  // Listen for call ended events
  Stream<Map<String, dynamic>> listenForCallEnded() {
    try {
      if (_callService.currentCallId == null) {
        return const Stream.empty();
      }
      
      return FirebaseFirestore.instance
          .collection('calls')
          .doc(_callService.currentCallId)
          .snapshots()
          .where((snapshot) => snapshot.exists)
          .map((snapshot) => snapshot.data() ?? {})
          .where((data) {
            final status = data['status'] as String?;
            final shouldEnd = status == 'ended' || status == 'rejected' || status == 'missed';
            return shouldEnd;
          });
    } catch (e) {
      return const Stream.empty();
    }
  }

  // Listen for call acceptance (for caller)
  Stream<Map<String, dynamic>> listenForCallAccepted() {
    try {
      if (_callService.currentCallId == null) {
        return const Stream.empty();
      }

      return FirebaseFirestore.instance
          .collection('calls')
          .doc(_callService.currentCallId)
          .snapshots()
          .where((snapshot) => snapshot.exists)
          .map((snapshot) => snapshot.data() ?? {})
          .where((data) => data['status'] == 'accepted');
    } catch (e) {
      return const Stream.empty();
    }
  }

  // Start a new call
Future<CallResult> startCall({
  required String callerId,
  required String receiverId,
  required String callerName,
  required String receiverName,
  required CallType callType,
}) async {
  print('DEBUG: CallManager.startCall() CALLED');
  print(' DEBUG: Parameters - callerId: $callerId, receiverId: $receiverId');
  print(' DEBUG: Parameters - callerName: $callerName, receiverName: $receiverName');
  
  if (_currentUserId == null) {
    print('DEBUG: CallManager not initialized - _currentUserId is null');
    return CallResult(
      success: false,
      callId: null,
      errorMessage: 'CallManager not initialized. Call initialize() first.',
    );
  }

  print('DEBUG: _currentUserId: $_currentUserId');
  print('DEBUG: Calling _callService.startCall...');

  try {
    final result = await _callService.startCall(
      callerId: callerId,
      receiverId: receiverId,
      callerName: callerName,
      receiverName: receiverName,
      callType: callType,
    );

    print(' DEBUG: _callService.startCall result: ${result.success}');
    print('DEBUG: Call ID from service: ${result.callId}');
    print(' DEBUG: Error from service: ${result.errorMessage}');

    if (result.success) {        
      // Set current call ID for listeners
      setCurrentCallId(result.callId!);
      print('DEBUG: Current call ID set to: ${result.callId}');
    } else {
      print('DEBUG: Call service returned failure');
    }

    return result;
  } catch (e) {
    print('DEBUG: Exception in CallManager.startCall: $e');
    print('DEBUG: Stack trace: ${e.toString()}');
    return CallResult(
      success: false,
      callId: null,
      errorMessage: 'Failed to start call: $e',
    );
  }
}

  // Accept an incoming call
  Future<void> acceptCall(String callId) async {
    try {      
      // Set current call ID before accepting
      setCurrentCallId(callId);
      
      await _callService.acceptCall(callId);
    } catch (e) {
      rethrow;
    }
  }

  // End the current call
  Future<void> endCall() async {
    try {
      await _callService.endCall();
    } catch (e) {
      rethrow;
    }
  }

  // Reject an incoming call
  Future<void> rejectCall(String callId) async {
    try {
      await _callService.rejectCall(callId);
    } catch (e) {
      rethrow;
    }
  }

  // Set current call ID (for CallScreen initialization)
  void setCurrentCallId(String callId) {
    // Store the call ID in the UnifiedCallService
    // Since UnifiedCallService doesn't have setCurrentCallId, we'll manage it here
    // and the UnifiedCallService will set it when acceptCall/startCall is called
    print('CallManager: Current call ID set to $callId');
  }

  // Setup callbacks for UI updates
  void setupCallbacks({
    Function(MediaStream)? onRemoteStream,
    Function(String)? onConnectionState,
    Function(bool)? onMuteState,
    Function(String)? onError,
  }) {
    _callService.setupCallbacks(
      onRemoteStream: onRemoteStream,
      onConnectionState: onConnectionState,
      onMuteState: onMuteState,
      onError: onError,
    );
  }

  // Audio controls
  Future<void> toggleMute() async {
    try {
      await _callService.toggleMute();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleSpeaker() async {
    try {
      await _callService.toggleSpeaker();
    } catch (e) {
      rethrow;
    }
  }

  // Update call status in Firestore
  Future<void> updateCallStatus(String status, {String? endedBy}) async {
    try {
      if (_callService.currentCallId != null) {
        final updateData = {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (endedBy != null) {
          updateData['endedBy'] = endedBy;
        }

        await FirebaseFirestore.instance
            .collection('calls')
            .doc(_callService.currentCallId)
            .update(updateData);
      }
    } catch (e) {
      print('CallManager: Error updating call status: $e');
    }
  }

  // Get current call data from Firestore
  Future<CallData?> getCurrentCallData() async {
    if (_callService.currentCallId == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(_callService.currentCallId)
          .get();

      if (doc.exists) {
        return CallData.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Clean up abandoned calls 
  Future<void> cleanupAbandonedCalls() async {
    if (_currentUserId == null) return;

    try {
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(Duration(minutes: 5));

      // Find calls that are still active but older than 5 minutes
      final abandonedCalls = await FirebaseFirestore.instance
          .collection('calls')
          .where('status', whereIn: ['ringing', 'accepted'])
          .where('createdAt', isLessThan: Timestamp.fromDate(fiveMinutesAgo))
          .get();

      for (final doc in abandonedCalls.docs) {
        await doc.reference.update({
          'status': 'missed',
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': 'system',
        });
      }
    } catch (e) {
      print('CallManager: Error cleaning up abandoned calls: $e');
    }
  }

  // Get call history for a user
  Stream<List<CallData>> getCallHistory() {
    if (_currentUserId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('calls')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CallData.fromMap(doc.data()))
            .toList());
  }

  // Getters
  bool get isInCall => _callService.isInCall;
  String? get currentCallId => _callService.currentCallId;
  bool get isMuted => _callService.isMuted;
  bool get isSpeakerOn => _callService.isSpeakerOn;
  CallData? get currentCallData => _callService.currentCallData;
  String? get currentUserId => _currentUserId;

  // Check if user can make calls (is online, etc.)
  Future<bool> canMakeCall(String targetUserId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final isOnline = userData['isOnline'] ?? false;
      final lastSeen = userData['lastSeen'];

      // User is considered online if they were active in the last 2 minutes
      if (lastSeen != null) {
        final lastSeenTime = lastSeen is Timestamp 
            ? lastSeen.toDate() 
            : DateTime.fromMillisecondsSinceEpoch(lastSeen);
        final difference = DateTime.now().difference(lastSeenTime);
        return difference.inMinutes < 2;
      }

      return isOnline;
    } catch (e) {
      return false;
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    try {
      await _callService.dispose();
      _currentUserId = null;
    } catch (e) {
      print('CallManager: Error during dispose: $e');
    }
  }
}