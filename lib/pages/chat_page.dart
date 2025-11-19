import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
// --- Imports for Voice Messages ---
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../services/profile_service.dart';
import '../services/message_service.dart';
import 'visit_profile_page.dart';

// +++ Widget for Audio Playback +++
class AudioPlayerWidget extends StatefulWidget {
  final String base64Audio;
  final bool isMe;

  const AudioPlayerWidget({
    Key? key,
    required this.base64Audio,
    required this.isMe,
  }) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlaying = false;
  bool _isPlayerInitialized = false;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Decode Base64 and write to a temporary file
      final tempDir = await getTemporaryDirectory();
      _audioPath = '${tempDir.path}/${const Uuid().v4()}.aac';
      final file = File(_audioPath!);
      await file.writeAsBytes(base64Decode(widget.base64Audio));

      await _player.openPlayer();
      if (mounted) {
        setState(() {
          _isPlayerInitialized = true;
        });
      }
    } catch (e) {
      print("Error initializing audio player: $e");
    }
  }

  @override
  void dispose() {
    _player.closePlayer();
    // Clean up the temporary file
    if (_audioPath != null) {
      final file = File(_audioPath!);
      if (file.existsSync()) {
        file.delete();
      }
    }
    super.dispose();
  }

  void _togglePlayer() async {
    if (!_isPlayerInitialized || _audioPath == null) return;

    if (_player.isPlaying) {
      await _player.pausePlayer();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      await _player.startPlayer(
        fromURI: _audioPath!,
        whenFinished: () {
          if (mounted) setState(() => _isPlaying = false);
        },
      );
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : Colors.black;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: color),
          onPressed: _togglePlayer,
        ),
        Icon(Icons.graphic_eq, color: color), // Placeholder for waveform
      ],
    );
  }
}

class ChatPage extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String receiverName;
  final String? receiverImageUrl;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.receiverName,
    this.receiverImageUrl,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final MessageService _messageService = MessageService();
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // --- Voice Recording State ---
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _controller.dispose();
    super.dispose();
  }

  // --- Voice Recording Methods with Cancel Logic ---

  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print('Microphone permission not granted');
      // Optionally, show a SnackBar to the user
      return;
    }
    await _recorder.openRecorder();
    if (mounted) {
      setState(() => _isRecorderInitialized = true);
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/${const Uuid().v4()}.aac';

    await _recorder.startRecorder(toFile: path, codec: Codec.aacMP4);

    if (mounted) {
      setState(() {
        _isRecording = true;
        _isCancelling = false; // Reset cancel state every time
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecorderInitialized || !_isRecording) return;

    if (_isCancelling) {
      return _cancelRecording();
    }

    final path = await _recorder.stopRecorder();

    if (mounted) setState(() => _isRecording = false);

    if (path == null) return;

    final file = File(path);
    if (await file.exists()) {
      final fileLength = await file.length();
      if (fileLength < 1000) {
        // 1KB threshold
        print('Recording too short, discarding.');
        await file.delete();
      } else {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        _sendMediaMessage(base64String, 'audio', fileName: 'Voice Message');
        await file.delete();
      }
    }
  }

  Future<void> _cancelRecording() async {
    print("--- Cancelling recording ---");
    final path = await _recorder.stopRecorder();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });
    }

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (details.localOffsetFromOrigin.dx < -50) {
      if (!_isCancelling) {
        if (mounted) setState(() => _isCancelling = true);
      }
    } else {
      if (_isCancelling) {
        if (mounted) setState(() => _isCancelling = false);
      }
    }
  }

  // --- Other Methods ---

  ImageProvider? _getImageProvider(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      final Uint8List imageBytes = base64Decode(base64String);
      return MemoryImage(imageBytes);
    } catch (e) {
      print("Erreur de décodage de l'image Base64 dans ChatPage : $e");
      return null;
    }
  }

  void _navigateToUserProfile() async {
    final profileService = ProfileSercice();
    final userData = await profileService.getUserData(widget.receiverId);

    if (!mounted) return;

    if (userData != null) {
      userData['uid'] = widget.receiverId;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VisitProfilePage(user: userData)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load user profile")),
      );
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _messageService.sendMessage(widget.chatId, widget.receiverId, text);
    _controller.clear();
    setState(() {});
  }

  void _startVoiceCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Voice call feature coming soon!")),
    );
  }

  void _startVideoCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Video call feature coming soon!")),
    );
  }

  void _sendMediaMessage(String base64Data, String type, {String? fileName}) {
    String messageText;
    switch (type) {
      case 'image':
        messageText = "Photo";
        break;
      case 'audio':
        messageText = "Voice Message";
        break;
      default:
        messageText = fileName ?? "File";
    }

    _messageService.sendMessage(
      widget.chatId,
      widget.receiverId,
      messageText,
      base64Data: base64Data,
      type: type,
      fileName: fileName,
    );
  }

  Future<void> _pickAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      Uint8List fileBytes = await file.readAsBytes();
      String base64String = base64Encode(fileBytes);
      _sendMediaMessage(
        base64String,
        'file',
        fileName: result.files.single.name,
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      Uint8List imageBytes = await file.readAsBytes();
      String base64String = base64Encode(imageBytes);
      _sendMediaMessage(base64String, 'image', fileName: pickedFile.name);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Widget _buildMessageContent(Map<String, dynamic> msg, bool isMe) {
    final type = msg['type'] ?? 'text';

    switch (type) {
      case 'image':
        final imageProvider = _getImageProvider(msg['base64Data']);
        if (imageProvider != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(image: imageProvider, fit: BoxFit.cover),
          );
        }
        return Text(
          "Impossible de charger l'image",
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        );

      case 'audio':
        final base64Audio = msg['base64Data'];
        if (base64Audio != null) {
          return AudioPlayerWidget(base64Audio: base64Audio, isMe: isMe);
        }
        return Text(
          "Voice message could not be loaded",
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        );

      case 'file':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isMe ? Colors.white : Colors.black54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg['fileName'] ?? 'Fichier',
                style: TextStyle(color: isMe ? Colors.white : Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      default:
        return Text(
          msg['text'] ?? '',
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _getImageProvider(widget.receiverImageUrl);

    String getHintText() {
      if (_isCancelling) return "< Slide to cancel";
      if (_isRecording) return "Recording... Release to send";
      return "Type a message...";
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: GestureDetector(
          onTap: _navigateToUserProfile,
          behavior: HitTestBehavior.translucent,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? const Icon(Icons.person, color: Colors.white, size: 22)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.receiverName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: _startVoiceCall),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _startVideoCall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messageService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == currentUserId;
                    final timestamp = msg['timestamp'] as Timestamp?;
                    final type = msg['type'] ?? 'text';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: IntrinsicWidth(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.85)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildMessageContent(msg, isMe),
                                if (type != 'text' &&
                                    msg['text'] != null &&
                                    msg['text'].isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      msg['text'],
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    _formatTimestamp(timestamp),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (!_isRecording) ...[
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: _pickAttachment,
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_camera, color: Colors.grey),
                    onPressed: _pickImage,
                  ),
                ],
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (text) => setState(() {}),
                    readOnly: _isRecording,
                    decoration: InputDecoration(
                      hintText: getHintText(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                if (_controller.text.isEmpty)
                  GestureDetector(
                    onLongPress: _startRecording,
                    onLongPressEnd: (details) => _stopAndSendRecording(),
                    onLongPressMoveUpdate: _handleLongPressMoveUpdate,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        _isCancelling ? Icons.delete : Icons.mic,
                        color: _isRecording
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: _sendMessage,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
