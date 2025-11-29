// pages/home_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:chat_app/services/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../services/call_data.dart';
import '../services/call_manager.dart';
import '../services/friend_service.dart';
import '../services/message_service.dart';
import 'call_page.dart';
import 'incoming_call_screen.dart';
import 'profile_page.dart';
import 'friend_requests_page.dart';
import 'chat_page.dart';
import 'visit_profile_page.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'loading_page.dart';
import 'discussions_list.dart';
import '../services/presence_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AIService ai;

  final FriendService _friendService = FriendService();
  final MessageService _messageService = MessageService();
  final TextEditingController _searchCtrl = TextEditingController();
  final AuthService _authService = AuthService();
  final PresenceService _presenceService = PresenceService();

  late TabController _tabController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  int _requestCount = 0;
  StreamSubscription<int>? _requestCountSubscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _unreadNotificationSubscription;

  final CallManager _callManager = CallManager();
late StreamSubscription<CallData> _incomingCallSubscription;

  @override
  void initState() {
    super.initState();
    ai = AIService();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(_onSearchChanged);
    _listenToFriendRequests();
    _listenForNewNotifications();
    _listenToUnreadNotifications();
    _presenceService.setupPresence();
    _initializeCallManager();
  }

  void _initializeCallManager() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _callManager.initialize(currentUserId);
      _listenToIncomingCalls();
    }
  }



  void _listenToIncomingCalls() {
    _incomingCallSubscription = _callManager.listenForIncomingCalls().listen((callData) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callData: callData,
            currentUserId: _callManager.currentUserId!,
          ),
        ),
      );
    });
  }

void _startCall(String receiverId, String receiverName) async {
  final currentUserId = _callManager.currentUserId;
  if (currentUserId == null) return;

  final result = await _callManager.startCall(
    callerId: currentUserId,
    callerName: 'Your Name',
    receiverId: receiverId,
    receiverName: receiverName,
    callType: CallType.voice,
  );

  if (!mounted) return;

  if (result.success && result.callId != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callData: CallData(
            callId: result.callId!,
            callerId: currentUserId,
            callerName: 'Your Name',
            receiverId: receiverId,
            receiverName: receiverName,
            status: CallStatus.ringing,
            callType: CallType.voice,
            startedAt: DateTime.now(),

          ),
          isIncoming: false,
          currentUserId: currentUserId,
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to start call: ${result.errorMessage}')),
    );
  }
}




  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    _requestCountSubscription?.cancel();
    _notificationSubscription?.cancel();
    _unreadNotificationSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _callManager.dispose();

    super.dispose();
  }

  ImageProvider? _getImageProvider(String base64String) {
    if (base64String.isEmpty) return null;
    try {
      final Uint8List imageBytes = base64Decode(base64String);
      return MemoryImage(imageBytes);
    } catch (e) {
      print("Erreur de décodage de l'image Base64 sur HomePage : $e");
      return null;
    }
  }

  void _listenForNewNotifications() {
    _notificationSubscription = _friendService
        .getNewNotificationsStream()
        .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final notificationData =
                  change.doc.data() as Map<String, dynamic>?;
              if (notificationData == null) continue;

              final String type = notificationData['type'] ?? '';

              if (type == 'friend_request') {
                final fromUid = notificationData['senderId'];
                if (fromUid != null) {
                  final userDoc = await _friendService.getUserDetails(fromUid);
                  final senderName = userDoc.data() != null
                      ? (userDoc.data()! as Map)['name'] ?? 'Someone'
                      : 'Someone';

                  NotificationService.showInAppNotification(
                    title: "New Friend Request",
                    body: "$senderName sent you a friend request.",
                    onTap: () =>
                        _navigateToWithLoadingIndicator(FriendRequestsPage()),
                  );
                }
              } else if (type == 'new_message') {
                final String senderName =
                    notificationData['title'] ?? 'New Message';
                final String messageBody = notificationData['body'] ?? '...';
                final String chatId = notificationData['chatId'] ?? '';
                final String senderId = notificationData['senderId'] ?? '';

                if (chatId.isNotEmpty && senderId.isNotEmpty) {
                  NotificationService.showInAppNotification(
                    title: senderName,
                    body: messageBody,
                    onTap: () => _navigateToChat(chatId, senderId, senderName),
                  );
                }
              }
            }
          }
        });
  }

  void _listenToUnreadNotifications() {
    _unreadNotificationSubscription = _friendService
        .getUnreadNotificationCountStream()
        .listen((count) {
          if (mounted) {
            setState(() {
              _unreadNotificationCount = count;
            });
          }
        });
  }

  void _navigateToWithLoadingIndicator(Widget page) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadingPage()),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _listenToFriendRequests() {
    _requestCountSubscription = _friendService
        .getIncomingRequestsCountStream()
        .listen((count) {
          if (mounted) {
            setState(() {
              _requestCount = count;
            });
          }
        });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(_searchCtrl.text.trim());
    });
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    final res = await _friendService.searchUsersCaseInsensitive(query);
    if (mounted) {
      setState(() {
        _searchResults = res;
        _isSearching = false;
      });
    }
  }

  void _openProfileMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("My Profile"),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToWithLoadingIndicator(const ProfilePage());
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text("Friend Requests"),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToWithLoadingIndicator(FriendRequestsPage());
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  "Sign Out",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _authService.signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _visitUser(Map<String, dynamic> user) {
    _navigateToWithLoadingIndicator(VisitProfilePage(user: user));
  }

  void _navigateToChat(
    String chatId,
    String receiverId,
    String receiverName, {
    String? receiverImageUrl,
  }) {
    _navigateToWithLoadingIndicator(
      ChatPage(
        chatId: chatId,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverImageUrl: receiverImageUrl,
      ),
    );
  }

  // --- NEW FUNCTION: Deletes all notifications from Firestore ---
  Future<void> _clearAllNotifications() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications');

    final snapshots = await collection.get();

    if (snapshots.docs.isEmpty) return;

    // Use a batch to delete all at once (more efficient)
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // --- UPDATED PANEL: Includes "Clear All" button in the header ---
  void _showNotificationsPanel() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (_, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data?.docs ?? [];

                // If empty, show simplified empty view
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.notifications_off,
                          size: 50,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "You have no notifications.",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      // --- HEADER ROW ---
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Notifications",
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            // Button to delete all
                            TextButton.icon(
                              onPressed: () {
                                // Calls the function to delete from DB
                                _clearAllNotifications();
                              },
                              icon: const Icon(
                                Icons.delete_sweep,
                                color: Colors.red,
                                size: 20,
                              ),
                              label: const Text(
                                "Clear All",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // ------------------
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            final data =
                                notification.data() as Map<String, dynamic>;
                            // final bool isRead = data['read'] ?? false;

                            return ListTile(
                              leading: Icon(
                                Icons.notifications_active,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(data['title'] ?? 'No Title'),
                              subtitle: Text(data['body'] ?? 'No Body'),
                              onTap: () async {
                                // Delete single notification
                                await notification.reference.delete();

                                // Close panel if you want, or just let it update
                                // if (mounted) Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    } else if (_searchResults.isEmpty) {
      return const Center(child: Text("No users found matching your search."));
    } else {
      return ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, i) {
          final user = _searchResults[i];
          final String imageBase64 = user['imageUrlBase64'] ?? '';
          final imageProvider = _getImageProvider(imageBase64);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade300,
              backgroundImage: imageProvider,
              child: imageProvider == null ? const Icon(Icons.person) : null,
            ),
            title: Text(user['name'] ?? 'User'),
            subtitle: Text(user['email'] ?? ''),
            onTap: () => _visitUser(user),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showSearchResults = _searchCtrl.text.isNotEmpty;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 5,
              left: 20,
              right: 20,
              bottom: 0,
            ),
            color: primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        ImageProvider? imageProvider;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final imageBase64 = data['imageUrlBase64'] ?? '';
                          imageProvider = _getImageProvider(imageBase64);
                        }
                        return GestureDetector(
                          onTap: _openProfileMenu,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white,
                            backgroundImage: imageProvider,
                            child: imageProvider == null
                                ? const Icon(Icons.person, color: Colors.purple)
                                : null,
                          ),
                        );
                      },
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "+➋➊➏",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications,
                            color: Colors.white,
                          ),
                          onPressed: _showNotificationsPanel,
                        ),
                        if (_unreadNotificationCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$_unreadNotificationCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade600,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              color: Colors.grey.shade600,
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      hintText: "Search friends or chats",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                  ),
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.white,
                  tabs: [
                    const Tab(text: "Discussions"),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Requests"),
                          if (_requestCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: CircleAvatar(
                                radius: 7,
                                backgroundColor: Colors.red,
                                child: Text(
                                  '$_requestCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            child: showSearchResults
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      const DiscussionsList(),
                      FriendRequestsPage(showAppBar: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
