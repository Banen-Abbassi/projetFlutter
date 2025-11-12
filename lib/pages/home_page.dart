import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../services/friend_service.dart';
import '../services/message_service.dart';
import 'profile_page.dart';
import 'friend_requests_page.dart';
import 'chat_page.dart';
import 'visit_profile_page.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'loading_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService();
  final MessageService _messageService = MessageService();
  final TextEditingController _searchCtrl = TextEditingController();
  final AuthService _authService = AuthService();

  late TabController _tabController;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Timer? _debounce;
  int _requestCount = 0;
  StreamSubscription<int>? _requestCountSubscription;

  // Central listener for all pop-up notifications
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  // Listener for the badge count on the bell icon
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _unreadNotificationSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(_onSearchChanged);
    _listenToFriendRequests();
    _listenForNewNotifications();
    _listenToUnreadNotifications();
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
    super.dispose();
  }

  // --- Notification Listeners ---

  /// Central listener for all real-time pop-up notifications.
  void _listenForNewNotifications() {
    _notificationSubscription = _friendService
        .getNewNotificationsStream()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notificationData = change.doc.data() as Map<String, dynamic>?;
          if (notificationData == null) continue;

          final String type = notificationData['type'] ?? '';

          if (type == 'friend_request') {
            final fromUid = notificationData['senderId'];
            if (fromUid != null) {
              final userDoc = await _friendService.getUserDetails(fromUid);
              final senderName = userDoc.data() != null ? (userDoc.data()! as Map)['name'] ?? 'Someone' : 'Someone';
              
              NotificationService.showInAppNotification(
                title: "New Friend Request",
                body: "$senderName sent you a friend request.",
                onTap: () => _navigateToWithLoadingIndicator(FriendRequestsPage()),
              );
            }
          } else if (type == 'new_message') {
            final String senderName = notificationData['title'] ?? 'New Message';
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
    _unreadNotificationSubscription =
        _friendService.getUnreadNotificationCountStream().listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    });
  }

  // --- Other Handlers & Methods ---
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
    _requestCountSubscription =
        _friendService.getIncomingRequestsCountStream().listen((count) {
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
                title: const Text("Sign Out", style: TextStyle(color: Colors.red)),
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

  void _navigateToChat(String chatId, String receiverId, String receiverName,
      {String? receiverImageUrl}) {
    _navigateToWithLoadingIndicator(
      ChatPage(
        chatId: chatId,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverImageUrl: receiverImageUrl,
      ),
    );
  }

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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("You have no notifications.",
                          style: TextStyle(fontSize: 16)),
                    ),
                  );
                }
                final notifications = snapshot.data!.docs;
                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text("Notifications",
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            final data =
                                notification.data() as Map<String, dynamic>;
                            final bool isRead = data['read'] ?? false;
                            return ListTile(
                              leading: Icon(
                                isRead
                                    ? Icons.notifications_none
                                    : Icons.notifications_active,
                                color: isRead
                                    ? Colors.grey
                                    : Theme.of(context).primaryColor,
                              ),
                              title: Text(data['title'] ?? 'No Title'),
                              subtitle: Text(data['body'] ?? 'No Body'),
                              onTap: () async {
                                if (!isRead) {
                                  await notification.reference
                                      .update({'read': true});
                                }
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

  // --- UI Builders ---
  Widget _buildDiscussionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messageService.getUserChats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final chatDocs = snapshot.data?.docs ?? [];
        if (chatDocs.isEmpty) {
          return const Center(
              child: Text("Start a discussion by searching for a friend!"));
        }
        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, i) {
            final chat = chatDocs[i].data() as Map<String, dynamic>;
            final chatId = chatDocs[i].id;
            final currentUserId = _messageService.getCurrentUserId();
            final participants = List<String>.from(chat['participants']);
            final receiverId = participants.firstWhere(
                (id) => id != currentUserId,
                orElse: () => currentUserId);
            return FutureBuilder<DocumentSnapshot>(
              future: _friendService.getUserDetails(receiverId),
              builder: (context, userSnapshot) {
                String name = "Loading...";
                String? imageUrl;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  name = userData['name'] ?? 'Unknown User';
                  imageUrl = userData['imageUrl'];
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: _messageService.getLastMessage(chatId),
                  builder: (context, messageSnapshot) {
                    String subtitle = "No messages yet";
                    if (messageSnapshot.hasData &&
                        messageSnapshot.data!.docs.isNotEmpty) {
                      final lastMessage = messageSnapshot.data!.docs.first
                          .data() as Map<String, dynamic>;
                      final String messageContent =
                          lastMessage["text"] ?? "Message unavailable";
                      final String? senderId =
                          lastMessage["senderId"] as String?;
                      subtitle = (senderId != null && senderId == currentUserId)
                          ? "You: $messageContent"
                          : messageContent;
                    }
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.purple.shade700,
                        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                            ? NetworkImage(imageUrl)
                            : null,
                        child: (imageUrl == null || imageUrl.isEmpty)
                            ? const Icon(Icons.person,
                                size: 25, color: Colors.white)
                            : null,
                      ),
                      title: Text(name),
                      subtitle: Text(subtitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        _navigateToChat(chatId, receiverId, name,
                            receiverImageUrl: imageUrl);
                      },
                    );
                  },
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
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade300,
              backgroundImage: user['imageUrl'] != null && user['imageUrl'] != ''
                  ? NetworkImage(user['imageUrl'])
                  : null,
              child: user['imageUrl'] == null || user['imageUrl'] == ''
                  ? const Icon(Icons.person)
                  : null,
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
                    GestureDetector(
                      onTap: _openProfileMenu,
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Colors.purple),
                      ),
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
                          icon: const Icon(Icons.notifications,
                              color: Colors.white),
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
                      // contentPadding: const EdgeInsets.only(top: 10),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade600),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              color: Colors.grey.shade600,
                              onPressed: () {
                                _searchCtrl.clear();
                              },
                            )
                          : null,
                      hintText: "Search friends or chats",
                      hintStyle:
                          TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
                      _buildDiscussionsList(),
                      FriendRequestsPage(showAppBar: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}