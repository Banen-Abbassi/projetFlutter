// lib/pages/voice_call_page.dart

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/call_service.dart';

// Your constants
const String AGORA_APP_ID = "b124b6e00d774751aa74eb0f1b2cce87"; 
const String AGORA_TOKEN = "9196a109bc924fbc81f8c6660d9591c7"; 

class VoiceCallPage extends StatefulWidget {
  final String channelName;
  final bool isCaller;
  final String chatId;

  const VoiceCallPage({
    Key? key,
    required this.channelName,
    required this.isCaller,
    required this.chatId,
  }) : super(key: key);

  @override
  _VoiceCallPageState createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  final CallService _callService = CallService();
  late RtcEngine _engine;
  int? _remoteUid;
  bool _isJoined = false;
  String _callStatus = 'Connecting...';
  
  // New State Variables for Controls
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    // Setting initial speaker state based on common call practice
    // Often, speaker is off by default for voice calls.
    _isSpeakerOn = false; 
    _initializeAgora();

    // 1. Caller Logic: Monitor receiver's action (accept/reject)
    if (widget.isCaller) {
      _monitorReceiverStatus();
    }
  }

  // --- Agora Initialization and Setup (Updated) ---
  Future<void> _initializeAgora() async {
    // 1. Setup Agora engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: AGORA_APP_ID));
    
    // Set up the voice profile
    await _engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
    await _engine.enableAudio(); // Enable audio for voice call

    // Set the default audio route (speaker off, earpiece/phone speaker on)
  //  await _engine.setEnableSpeakerphone(_isSpeakerOn);

    // 2. Set up event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (mounted) setState(() => _isJoined = true);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) {
            setState(() {
            _remoteUid = remoteUid;
            _callStatus = 'In Call';
          });
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User left the call.')),
            );
          }
          _leaveCall(); // Remote user disconnected
        },
        onLeaveChannel: (connection, stats) {
          if (mounted) setState(() => _isJoined = false);
        },
      ),
    );

    // 3. Join logic
    if (!widget.isCaller) {
      // Receiver joins immediately after accepting the call signal
      _joinChannel();
    }
  }

  Future<void> _joinChannel() async {
    await _engine.setEnableSpeakerphone(_isSpeakerOn);
    await _engine.joinChannel(
      token: AGORA_TOKEN,
      channelId: widget.channelName,
      uid: 0, // Agora automatically assigns one
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
    if (mounted) setState(() => _callStatus = 'Waiting for user...');
  }

  // --- Call Status Monitoring for Caller ---
  void _monitorReceiverStatus() {
    // Listen for status changes (accepted/rejected/ended)
    _callService.getCallStatusStream(chatId: widget.chatId).listen((doc) {
      if (!doc.exists) {
        // Call document was deleted (receiver ended/rejected)
        _leaveCall();
        return;
      }
      final status = doc.get('status');
      
      if (status == 'accepted' && !_isJoined) {
        _joinChannel();
        if (mounted) setState(() => _callStatus = 'Connecting...');
      } else if (status == 'rejected') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call rejected by the recipient.')),
          );
        }
        _leaveCall();
      } else if (status == 'ended') {
        _leaveCall();
      }
    });
  }
  
  // --- New Control Methods ---

  Future<void> _toggleMute() async {
    // Toggle the state locally
    final newMutedState = !_isMuted;
    
    // Call Agora API to enable/disable the local audio stream
    await _engine.muteLocalAudioStream(newMutedState);

    if (mounted) setState(() {
      _isMuted = newMutedState;
    });
  }

  Future<void> _toggleSpeaker() async {
    // Toggle the state locally
    final newSpeakerState = !_isSpeakerOn;
    
    // Call Agora API to switch between earpiece and speakerphone
    await _engine.setEnableSpeakerphone(newSpeakerState);

    if (mounted) setState(() {
      _isSpeakerOn = newSpeakerState;
    });
  }


  // --- Call Cleanup ---
  void _leaveCall() async {
    await _engine.leaveChannel();
    // Only the caller should delete the document to prevent conflicts
    // The receiver should only update the status, and the caller will delete it.
    if (widget.isCaller) {
      await _callService.endCall(chatId: widget.chatId);
    } else {
       // Receiver updates the status in case the caller is still waiting
       await _callService.updateCallStatus(chatId: widget.chatId, status: 'ended');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    // Ensure cleanup even if the user manually closes the screen
    _engine.release();
    super.dispose();
  }

  // --- Build the Controls Widget ---
  Widget _buildCallControls() {
    // Only show controls when successfully joined (and connection established)
    final bool showControls = _isJoined && _remoteUid != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Mute Button
        FloatingActionButton(
          heroTag: 'mute_btn',
          onPressed: showControls ? _toggleMute : null,
          backgroundColor: _isMuted ? Colors.redAccent : Colors.grey.shade700,
          child: Icon(
            _isMuted ? Icons.mic_off : Icons.mic,
            color: Colors.white,
          ),
        ),
        
        // 2. Hang Up Button (Available anytime)
        FloatingActionButton(
          heroTag: 'hangup_btn',
          onPressed: _leaveCall,
          backgroundColor: Colors.red,
          child: const Icon(Icons.call_end, color: Colors.white, size: 30),
        ),

        // 3. Speaker Button
        FloatingActionButton(
          heroTag: 'speaker_btn',
          onPressed: showControls ? _toggleSpeaker : null,
          backgroundColor: _isSpeakerOn ? Colors.green : Colors.grey.shade700,
          child: Icon(
            _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display Status Icon and Name (You can fetch receiver/caller name here)
              Icon(
                _isJoined && _remoteUid != null ? Icons.phone_in_talk : Icons.person, 
                color: Colors.white, 
                size: 80
              ),
              const SizedBox(height: 20),
              
              // Call Type Status
              Text(
                widget.isCaller ? "Calling..." : "Incoming Call...",
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 10),
              
              // Connection Status
              Text(
                _callStatus,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 50),
              
              // Call Controls
              _buildCallControls(),
            ],
          ),
        ),
      ),
    );
  }
}