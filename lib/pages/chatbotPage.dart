import 'package:flutter/material.dart';
import '../services/ai_service.dart'; // Ensure this path is correct

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final AIService aiService = AIService();
  final TextEditingController controller = TextEditingController();
  final List<Map<String, String>> messages = [];
  final ScrollController _scrollController = ScrollController();

  void sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    // 1. Add user message and scroll
    setState(() {
      messages.add({"sender": "user", "text": text});
    });
    controller.clear();
    _scrollToBottom();

    // 2. Add temporary loading indicator message
    final loadingMessage = {"sender": "assistant", "text": "...", "loading": "true"};
    setState(() {
      messages.add(loadingMessage);
    });
    _scrollToBottom();

    // 3. Get AI response
    final response = await aiService.askAI(text);

    // 4. Update the last message (loading indicator) with the actual response
    setState(() {
      // Find and remove the loading message
      messages.removeLast();
      // Add the final response
      messages.add({"sender": "assistant", "text": response});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    // Wait for the list view to rebuild after setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("+216 Assistant 🤖"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isUser = msg["sender"] == "user";
                final isLoading = msg["loading"] == "true";

                // Use the new MessageBubble widget for consistent design
                return MessageBubble(
                  message: msg["text"] ?? "",
                  isUser: isUser,
                  isLoading: isLoading,
                );
              },
            ),
          ),
          // Use the new MessageInput widget
          MessageInput(
            controller: controller,
            onSend: sendMessage,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }
}

// --- Custom Widget 1: Message Bubble (for the chat messages) ---
class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isLoading;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isUser ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.08);
    final textColor = isUser ? Colors.white : theme.colorScheme.onBackground;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.fromLTRB(
          isUser ? 10 : 10, // Left margin
          4,
          isUser ? 10 : 10, // Right margin
          4,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: isLoading
            ? SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  color: textColor,
                  strokeWidth: 2,
                ),
              )
            : Text(
                message,
                style: TextStyle(color: textColor),
              ),
      ),
    );
  }
}

// --- Custom Widget 2: Message Input (for the text field) ---
class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Color primaryColor;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: "Ask your +216 Assistant...",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: primaryColor),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}