import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import '../services/call_data.dart';
import '../services/call_manager.dart';
import 'call_page.dart';

class IncomingCallScreen extends StatelessWidget {
  final CallData callData;
  final String currentUserId; 

  const IncomingCallScreen({
    Key? key, 
    required this.callData,
    required this.currentUserId, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_downward, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Call info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Incoming Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 30),
                  
                  // StreamBuilder to get caller's profile photo
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(callData.callerId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingAvatar();
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return _buildDefaultAvatar(callData.callerName);
                      }

                      final userData = snapshot.data!.data() as Map<String, dynamic>;
                      final String profileImage = userData['profileImageBase64'] ?? '';
                      
                      return _buildUserAvatar(profileImage, callData.callerName);
                    },
                  ),
                  
                  SizedBox(height: 20),
                  
                  Text(
                    '${callData.callerName} is calling', 
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  SizedBox(height: 10),
                  
                  Text(
                    'Audio Call',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button
                  _buildActionButton(
                    icon: Icons.call_end,
                    backgroundColor: Colors.red,
                    onPressed: () => _rejectCall(context),
                  ),
                  
                  // Accept button
                  _buildActionButton(
                    icon: Icons.call,
                    backgroundColor: Colors.green,
                    onPressed: () => _acceptCall(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String profileImage, String userName) {
    if (profileImage.isNotEmpty) {
      // Show actual profile photo
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: MemoryImage(base64Decode(profileImage)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Show default avatar
      return _buildDefaultAvatar(userName);
    }
  }

  Widget _buildDefaultAvatar(String userName) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey[800],
      child: Icon(Icons.person, size: 50, color: Colors.white),
    );
  }

  Widget _buildLoadingAvatar() {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey[800],
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildActionButton({
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

  void _acceptCall(BuildContext context) {
  CallManager().acceptCall(callData.callId);
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (context) => CallScreen(
        callData: callData,
        isIncoming: true,
        currentUserId: currentUserId, 
      ),
    ),
  );
}

  void _rejectCall(BuildContext context) {
    CallManager().rejectCall(callData.callId);
    Navigator.of(context).pop();
  }
}