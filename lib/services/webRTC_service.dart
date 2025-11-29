import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  // Configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ]
      },
    ],
  };

  final Map<String, dynamic> _mediaConstraints = {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
      'channelCount': 1,
    },
    'video': false
  };

  // Callbacks
  Function(MediaStream)? onRemoteStream;
  Function(String)? onConnectionState;
  Function(bool)? onMuteState;
  Function(String)? onError;
  Function(RTCIceCandidate)? onIceCandidate;

  Future<void> initialize() async {
    try {
      print('🎧 Initializing WebRTC...');
      
      // Request microphone permission
      await _requestPermissions();
      
      // Get local media stream
      _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);
      
      // Create peer connection
      _peerConnection = await createPeerConnection(_configuration);
      
      // Add local tracks
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      
      // Set up event listeners
      _setupEventListeners();
      
      
    } catch (e) {
      print('WebRTC initialization failed: $e');
      onError?.call('Failed to initialize audio: $e');
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    final microphoneStatus = await Permission.microphone.request();
    if (!microphoneStatus.isGranted) {
      throw Exception('Microphone permission denied');
    }
  }

  void _setupEventListeners() {
    // ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate != null) {
        onIceCandidate?.call(candidate);
      }
    };

    // Remote stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        onRemoteStream?.call(_remoteStream!);
      }
    };

    // ICE connection state
    _peerConnection!.onIceConnectionState = (state) {
      if (state != null) {
        onConnectionState?.call(state.toString());
      }
    };
  }

  // Create offer
  Future<RTCSessionDescription> createOffer() async {
    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      return offer;
    } catch (e) {
      print('Error creating offer: $e');
      rethrow;
    }
  }

  // Handle offer
  Future<void> handleOffer(RTCSessionDescription offer) async {
    try {
      await _peerConnection!.setRemoteDescription(offer);
    } catch (e) {
      print('Error handling offer: $e');
      rethrow;
    }
  }

  // Create answer
  Future<RTCSessionDescription> createAnswer() async {
    try {
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      return answer;
    } catch (e) {
      print('Error creating answer: $e');
      rethrow;
    }
  }

  // Handle answer
  Future<void> handleAnswer(RTCSessionDescription answer) async {
    try {
      await _peerConnection!.setRemoteDescription(answer);
    } catch (e) {
      print(' Error handling answer: $e');
      rethrow;
    }
  }

  // Add ICE candidate
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }

  // Audio controls
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
    onMuteState?.call(_isMuted);
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    // Note: Speaker control might need platform-specific implementation
  }

  // Cleanup
  Future<void> dispose() async {
    
    await _peerConnection?.close();
    _localStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.getTracks().forEach((track) => track.stop());
    
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    
  }

  // Getters
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
}