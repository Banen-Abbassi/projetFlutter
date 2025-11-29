import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'call_data.dart';
import 'call_result.dart';
import 'call_service.dart';
import 'signaling_service.dart';
import 'webRTC_service.dart';

class UnifiedCallService {
  final CallService _callService = CallService();
  final WebRTCService _webRTCService = WebRTCService();
  final SignalingService _signalingService = SignalingService();

  String? _currentCallId;
  String? _currentUserId;
  String? _otherUserId;
  bool _isInCall = false;
  CallData? _currentCallData;


  /// Start a new call
  Future<CallResult> startCall({
    required String callerId,
    required String receiverId,
    required String callerName,
    required String receiverName,
    required CallType callType,
  }) async {
    try {
      _currentUserId = callerId;
      _otherUserId = receiverId;

      print(' Starting call from $callerId to $receiverId');

      // 1. Create call in Firestore
      final result = await _callService.startCall(
        callerId: callerId,
        receiverId: receiverId,
        callerName: callerName,
        receiverName: receiverName,
        callType: callType,
      );

      if (!result.success) {
        throw Exception('Failed to create call: ${result.errorMessage}');
      }

      _currentCallId = result.callId;
      print('Call created: $_currentCallId');

      // 2. Initialize WebRTC
      await _webRTCService.initialize();
      print(' WebRTC initialized');

      // 3. Setup signaling and callbacks
      _setupSignaling();
      _setupWebRTCCallbacks();

      // 4. Create and send offer
      final offer = await _webRTCService.createOffer();
      await _signalingService.sendOffer(
        from: callerId,
        to: receiverId,
        offer: offer,
      );

      _isInCall = true;

      return CallResult(success: true, callId: result.callId);
    } catch (e) {
      await _cleanupFailedCall();
      return CallResult(success: false, errorMessage: e.toString());
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall(String callId) async {
    try {
      _currentCallId = callId;

      // Get call data
      _currentCallData = await _callService.getCall(callId);
      if (_currentCallData == null) {
        throw Exception('Call not found');
      }

      _currentUserId = _currentCallData!.receiverId;
      _otherUserId = _currentCallData!.callerId;


      // 1. Initialize WebRTC
      await _webRTCService.initialize();

      // 2. Setup signaling and callbacks
      _setupSignaling();
      _setupWebRTCCallbacks();

      // 3. Mark call as accepted in Firestore
      await _callService.acceptCall(callId);

      _isInCall = true;
    } catch (e) {
      await _cleanupFailedCall();
      rethrow;
    }
  }

Future<void> endCall() async {
  try {
    print('Ending call for both users...');
    
    if (_currentCallId != null) {
      // Get current call data first to determine call status
      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(_currentCallId!)
          .get();
      
      if (callDoc.exists) {
        final callData = CallData.fromMap(callDoc.data()!);
        final callStatus = callData.status;
        final answeredAt = callData.answeredAt;
        final endedAt = callData.endedAt;
        
        print(' DEBUG: Call status: ${callStatus.toString().split('.').last}');
        print(' DEBUG: answeredAt: $answeredAt, endedAt: $endedAt');

        // Calculate call duration if call was answered
        int duration = 0;
        if (answeredAt != null) {
          final end = endedAt ?? DateTime.now();
          duration = end.difference(answeredAt).inSeconds;
          print('DEBUG: Call duration: ${duration}s');
        }

        // Save to chat based on call status
        if (callStatus == CallStatus.ongoing && duration > 0) {
          await _saveCompletedCallToChat(duration);
        } else if (callStatus == CallStatus.ringing) {
          // Call ended before answer - mark as missed
          await _saveMissedCallToChat();
        } else if (callStatus == CallStatus.ongoing && duration == 0) {
          // Call was answered but ended immediately
          await _saveShortCallToChat();
        } else if (callStatus == CallStatus.missed) {
          // Call was already marked as missed
          await _saveMissedCallToChat();
        }

        // Update call status in Firestore to notify both users
        await _callService.endCall(_currentCallId!);
        
        // Send a signaling message to notify the other user
        await _notifyCallEnded();
      } else {
        print('Call document not found: $_currentCallId');
      }
    }

    await _webRTCService.dispose();
    if (_currentUserId != null) {
      await _signalingService.cleanupSignaling(_currentUserId!);
    }

    _resetState();
  } catch (e) {
    await _cleanupFailedCall();
  }
}

// Fix the Firestore document references by casting to String
Future<void> _saveCompletedCallToChat(int duration) async {
  try {
    if (_currentCallData == null) {
      return;
    }

    final callData = _currentCallData!;
    final participants = [callData.callerId, callData.receiverId];
    participants.sort();
    final chatId = participants.join('_');

    final callMessage = {
      'id': 'call_${callData.callId}_${DateTime.now().millisecondsSinceEpoch}',
      'text': '📞 Appel audio (${duration}s)',
      'senderId': callData.callerId,
      'senderName': callData.callerName,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
      'callDuration': duration,
      'callStatus': 'completed',
      'isCall': true,
      'extraData': {
        'callId': callData.callId,
        'callDuration': duration,
        'isCall': true,
        'callStatus': 'completed',
      },
    };

    final messageId = callMessage['id'] as String;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId) 
        .set(callMessage);

    // Update last message in chat
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set({
          'lastMessage': callMessage['text'] as String, 
          'lastMessageTime': FieldValue.serverTimestamp(),
          'participants': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

  } catch (e) {
    print(' Error saving completed call to chat: $e');
  }
}

Future<void> _saveMissedCallToChat() async {
  try {
    if (_currentCallData == null) {
      return;
    }

    final callData = _currentCallData!;
    final participants = [callData.callerId, callData.receiverId];
    participants.sort();
    final chatId = participants.join('_');

    final callMessage = {
      'id': 'call_${callData.callId}_${DateTime.now().millisecondsSinceEpoch}',
      'text': '📞 Appel manqué',
      'senderId': callData.callerId,
      'senderName': callData.callerName,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
      'callDuration': 0,
      'callStatus': 'missed',
      'isCall': true,
      'isMissedCall': true,
      'extraData': {
        'callId': callData.callId,
        'callDuration': 0,
        'isCall': true,
        'isMissedCall': true,
        'callStatus': 'missed',
      },
    };

    // FIX: Cast to String explicitly
    final messageId = callMessage['id'] as String;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId) 
        .set(callMessage);

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set({
          'lastMessage': callMessage['text'] as String, 
          'lastMessageTime': FieldValue.serverTimestamp(),
          'participants': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

  } catch (e) {
    print('Error saving missed call to chat: $e');
  }
}

Future<void> _saveShortCallToChat() async {
  try {
    if (_currentCallData == null) return;

    final callData = _currentCallData!;
    final participants = [callData.callerId, callData.receiverId];
    participants.sort();
    final chatId = participants.join('_');

    final callMessage = {
      'id': 'call_${callData.callId}_${DateTime.now().millisecondsSinceEpoch}',
      'text': '📞 Appel audio (raccroché)',
      'senderId': callData.callerId,
      'senderName': callData.callerName,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
      'callDuration': 0,
      'callStatus': 'short',
      'isCall': true,
      'extraData': {
        'callId': callData.callId,
        'callDuration': 0,
        'isCall': true,
        'callStatus': 'short',
      },
    };

    // FIX: Cast to String explicitly
    final messageId = callMessage['id'] as String;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId) 
        .set(callMessage);

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set({
          'lastMessage': callMessage['text'] as String, 
          'lastMessageTime': FieldValue.serverTimestamp(),
          'participants': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

  } catch (e) {
    print('Error saving short call to chat: $e');
  }
}

  String _getCallSummary(CallData callData) {
    final duration = _getCallDuration(callData);
    final status = callData.status == CallStatus.ended ? 'ended' : 'missed';
    
    if (duration > 0) {
      return '📞 Audio call (${duration}s)';
    } else {
      return '📞 Call $status';
    }
  }

  int _getCallDuration(CallData callData) {
    if (callData.answeredAt == null || callData.endedAt == null) return 0;
    
    final start = callData.answeredAt!;
    final end = callData.endedAt!;
    return end.difference(start).inSeconds;
  }


  Future<void> _notifyCallEnded() async {
    if (_otherUserId != null && _currentUserId != null && _currentCallId != null) {
      try {
        await _signalingService.sendCallEnded(
          from: _currentUserId!,
          to: _otherUserId!,
          callId: _currentCallId!,
        );
      } catch (e) {
        print('Error notifying call end: $e');
      }
    }
  }


  /// Reject an incoming call
  Future<void> rejectCall(String callId) async {
    try {
      await _callService.markCallAsMissed(callId);
    } catch (e) {
      print('Error rejecting call: $e');
    }
  }

  /// Setup UI callbacks
  void setupCallbacks({
    Function(MediaStream)? onRemoteStream,
    Function(String)? onConnectionState,
    Function(bool)? onMuteState,
    Function(String)? onError,
  }) {
    _webRTCService.onRemoteStream = onRemoteStream;
    _webRTCService.onConnectionState = onConnectionState;
    _webRTCService.onMuteState = onMuteState;
    _webRTCService.onError = onError;
  }

  /// Audio controls
  Future<void> toggleMute() => _webRTCService.toggleMute();
  Future<void> toggleSpeaker() => _webRTCService.toggleSpeaker();

  // Private methods

  void _setupSignaling() {
    if (_currentUserId == null) return;

    // Listen for answers (when we are caller)
    _signalingService.listenForAnswers(_currentUserId!).listen((data) async {
      if (data.isNotEmpty) {
        try {
          final answer = RTCSessionDescription(data['sdp'], data['type']);
          await _webRTCService.handleAnswer(answer);
        } catch (e) {
          print('Error handling answer: $e');
        }
      }
    });

    // Listen for offers (when we are callee)
    _signalingService.listenForOffers(_currentUserId!).listen((data) async {
      if (data.isNotEmpty) {
        try {
          _otherUserId = data['from'];
          final offer = RTCSessionDescription(data['sdp'], data['type']);
          await _webRTCService.handleOffer(offer);
          
          // Create and send answer
          final answer = await _webRTCService.createAnswer();
          await _signalingService.sendAnswer(
            from: _currentUserId!,
            to: _otherUserId!,
            answer: answer,
          );
        } catch (e) {
          print('Error handling offer: $e');
        }
      }
    });

    // Listen for ICE candidates
    _signalingService.listenForIceCandidates(_currentUserId!).listen((data) async {
      if (data.isNotEmpty) {
        try {
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'] ?? '',
            data['sdpMLineIndex'] ?? 0,
          );
          await _webRTCService.addIceCandidate(candidate);
        } catch (e) {
          print('Error handling ICE candidate: $e');
        }
      }
    });

    // Send local ICE candidates to remote
    _webRTCService.onIceCandidate = (candidate) {
      if (_otherUserId != null && _currentUserId != null) {
        _signalingService.sendIceCandidate(
          from: _currentUserId!,
          to: _otherUserId!,
          candidate: candidate,
        );
      }
    };
  }

  void _setupWebRTCCallbacks() {
    _webRTCService.onConnectionState = (state) {
      print('🔗 Connection state: $state');
      
      // Auto-end call if connection fails
      if (state == 'failed' || state == 'disconnected') {
        endCall();
      }
    };

    _webRTCService.onError = (error) {
      endCall();
    };
  }

  Future<void> _cleanupFailedCall() async {
    if (_currentCallId != null) {
      await _callService.markCallAsMissed(_currentCallId!);
    }
    await _webRTCService.dispose();
    _resetState();
  }

  void _resetState() {
    _currentCallId = null;
    _currentUserId = null;
    _otherUserId = null;
    _isInCall = false;
    _currentCallData = null;
  }

  // Getters
  bool get isInCall => _isInCall;
  String? get currentCallId => _currentCallId;
  bool get isMuted => _webRTCService.isMuted;
  bool get isSpeakerOn => _webRTCService.isSpeakerOn;
  CallData? get currentCallData => _currentCallData;

  Future<void> dispose() async {
    await endCall();
  }
}