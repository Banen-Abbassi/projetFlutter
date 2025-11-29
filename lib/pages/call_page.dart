import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import '../services/call_data.dart';
import '../services/call_manager.dart'; 

class CallScreen extends StatefulWidget {
  final CallData? callData;
  final bool isIncoming;
  final String currentUserId; 
  const CallScreen({
    Key? key,
    this.callData,
    this.isIncoming = false,
    required this.currentUserId, 
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallManager _callManager = CallManager();
  bool _isConnected = false;
  String _connectionState = 'Connecting...';
  late RTCVideoRenderer _remoteRenderer;

  @override
  void initState() {
    super.initState();
    _remoteRenderer = RTCVideoRenderer();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _remoteRenderer.initialize();
      
      // Setup callbacks
      _callManager.setupCallbacks(
        onRemoteStream: _onRemoteStream,
        onConnectionState: _onConnectionState,
        onMuteState: _onMuteState,
        onError: _onError,
      );

      // Listen for remote call end
      _listenForRemoteCallEnd();

      // If incoming call, we need to accept it
      if (widget.isIncoming && widget.callData != null) {
        await _callManager.acceptCall(widget.callData!.callId);
      }
    } catch (e) {
      print('Error initializing call screen: $e');
      _showError('Failed to initialize call: $e');
    }
  }

  void _listenForRemoteCallEnd() {
    _callManager.listenForCallEnded().listen((data) {
      if (data.isNotEmpty && mounted) {
        print('Remote user ended the call');
        _showCallEndedByRemote();
      }
    });
  }

  void _showCallEndedByRemote() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Call ended by other user'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // Navigate back after a short delay
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _onRemoteStream(MediaStream stream) {
    print('🎧 Remote stream received');
    if (mounted) {
      setState(() {
        _remoteRenderer.srcObject = stream;
        _isConnected = true;
      });
    }
  }

  void _onConnectionState(String state) {
    if (mounted) {
      setState(() {
        _connectionState = state;
      });
    }
  }

  void _onMuteState(bool isMuted) {
    if (mounted) {
      setState(() {});
    }
  }

  void _onError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Call error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Get the other user's ID
  String? _getOtherUserId() {
    if (widget.callData == null) return null;
    
    // If current user is the caller, the other user is the receiver
    // If current user is the receiver, the other user is the caller
    if (widget.currentUserId == widget.callData!.callerId) {
      return widget.callData!.receiverId;
    } else {
      return widget.callData!.callerId;
    }
  }

  // Get the other user's name
  String? _getOtherUserName() {
    if (widget.callData == null) return null;
    
    if (widget.currentUserId == widget.callData!.callerId) {
      return widget.callData!.receiverName;
    } else {
      return widget.callData!.callerName;
    }
  }

  // Determine what text to display
  String _getCallDisplayText(String userName) {
    if (widget.isIncoming) {
      return '$userName is calling';
    } else {
      return userName;
    }
  }

  // Check if we should show detailed info
  bool get _shouldShowDetailedInfo {
    if (widget.callData == null) return true;
    
    // Always show detailed info for both users
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Call info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildUserInfo(),
                  
                  _buildConnectionStatus(),
                  
                  _buildRemoteVideo(),
                ],
              ),
            ),
            
            // Call controls
            _buildCallControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_downward, color: Colors.white),
            onPressed: _minimizeCall,
          ),
          Expanded(
            child: Text(
              'Audio Call',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          SizedBox(width: 48), // For balance
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    // Determine who the other user is
    final otherUserId = _getOtherUserId();
    final otherUserName = _getOtherUserName();

    if (!_shouldShowDetailedInfo) {
      return _buildDefaultUserInfo('Unknown');
    }

    if (otherUserId == null) {
      return _buildDefaultUserInfo(otherUserName ?? 'Unknown');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingUserInfo(otherUserName ?? 'Unknown');
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildDefaultUserInfo(otherUserName ?? 'Unknown');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String profileImage = userData['profileImageBase64'] ?? '';
        final String userName = userData['name'] ?? otherUserName ?? 'Unknown';

        return Column(
          children: [
            // Profile Avatar with Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: profileImage.isEmpty 
                    ? LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      )
                    : null,
                image: profileImage.isNotEmpty
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(profileImage)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profileImage.isEmpty
                  ? Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
            ),
            SizedBox(height: 20),
            Text(
              _getCallDisplayText(userName),
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              widget.isIncoming ? 'Incoming Call' : 'Outgoing Call',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingUserInfo(String name) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[800],
          child: CircularProgressIndicator(color: Colors.white),
        ),
        SizedBox(height: 20),
        Text(
          _getCallDisplayText(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultUserInfo(String name) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[800],
          child: Icon(Icons.person, size: 40, color: Colors.white),
        ),
        SizedBox(height: 20),
        Text(
          _getCallDisplayText(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        _isConnected ? 'Connected' : _connectionState,
        style: TextStyle(
          color: _isConnected ? Colors.green : Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.mic, size: 40, color: Colors.white),
      ),
    );
  }

  Widget _buildCallControls() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: _callManager.isMuted ? Icons.mic_off : Icons.mic,
            backgroundColor: _callManager.isMuted ? Colors.red : Colors.grey[700]!,
            onPressed: _callManager.toggleMute,
          ),
          
          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            onPressed: _endCall,
          ),
          
          // Speaker button
          _buildControlButton(
            icon: _callManager.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            backgroundColor: _callManager.isSpeakerOn ? Colors.green : Colors.grey[700]!,
            onPressed: _callManager.toggleSpeaker,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: backgroundColor,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  void _endCall() async {
    try {
      await _callManager.endCall();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Error ending call: $e');
      if (mounted) {
        _showError('Error ending call: $e');
      }
    }
  }

  void _minimizeCall() {
    // Implement call minimization logic here
    // For now, just navigate back
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _callManager.dispose();
    super.dispose();
  }
}