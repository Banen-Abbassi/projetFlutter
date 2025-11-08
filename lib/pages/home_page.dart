import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../services/friend_service.dart';
import '../services/message_service.dart';
import 'profile_page.dart';
import 'friend_requests_page.dart';
import 'chat_page.dart';
import 'visit_profile_page'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(_onSearchChanged);
    _listenToFriendRequests();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    _requestCountSubscription?.cancel();
    super.dispose();
  }

  // --- Handlers ---
  void _listenToFriendRequests() {
    _requestCountSubscription = _friendService.getIncomingRequestsCountStream().listen((count) {
      setState(() {
        _requestCount = count;
      });
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
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() => _isSearching = true);
    final res = await _friendService.searchUsersCaseInsensitive(query);
    
    setState(() {
      _searchResults = res;
      _isSearching = false;
    });
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())); 
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text("Friend Requests"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FriendRequestsPage()));
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VisitProfilePage(user: user)),
    );
  }

  void _navigateToChat(String chatId, String receiverId, String receiverName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          receiverId: receiverId,
          receiverName: receiverName,
        ),
      ),
    );
  }

  // --- UI Builders ---

  Widget _buildChatTile(
      BuildContext context, 
      String chatId, 
      String name, 
      String subtitle, 
      String receiverId,
      {String? imageUrl}) {
      
    final NetworkImage? networkImage = 
        (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null;
        
    return ListTile(
      leading: CircleAvatar(
        radius: 25, 
        backgroundColor: Colors.purple.shade700, 
        backgroundImage: networkImage,
        child: networkImage == null 
            ? const Icon(Icons.person, size: 25, color: Colors.white)
            : null,
      ),
      title: Text(name),
      subtitle: Text(subtitle),
      trailing: const Text('...'),
      onTap: () {
        _navigateToChat(chatId, receiverId, name);
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

  Widget _buildDiscussionsList() {
    // Stream chats for the current user
    return StreamBuilder<QuerySnapshot>(
      stream: _messageService.getUserChats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        
        final chatDocs = snapshot.data!.docs;
        if (chatDocs.isEmpty) {
          return const Center(child: Text("Start a discussion by searching for a friend!"));
        }

        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, i) {
            final chat = chatDocs[i].data() as Map<String, dynamic>;
            final chatId = chatDocs[i].id;
            
            final currentUserId = _messageService.getCurrentUserId();
            final participants = List<String>.from(chat['participants']);
            final receiverId = participants.firstWhere((id) => id != currentUserId, orElse: () => currentUserId);
            
            // FutureBuilder to fetch the receiver's details for the tile
            return FutureBuilder<DocumentSnapshot>(
              future: _friendService.getUserDetails(receiverId),
              builder: (context, userSnapshot) {
                String name = "Loading...";
                String subtitle = "No messages yet";
                String? imageUrl;

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  name = userData['name'] ?? 'Unknown User';
                  imageUrl = userData['imageUrl'];
                }

                return _buildChatTile(
                  context,
                  chatId,
                  name,
                  subtitle,
                  receiverId,
                  imageUrl: imageUrl,
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showSearchResults = _searchCtrl.text.isNotEmpty;
    final primaryColor = Theme.of(context).colorScheme.primary; 

    return Scaffold(
      body: Column(
        children: [
          // 1. Custom Header Container
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
                // Title & Notification Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Home", 
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.white),
                      onPressed: () { /* Notification action */ },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Avatar + Search Bar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: GestureDetector(
                        onTap: _openProfileMenu,
                        child: const CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white, 
                          child: Icon(Icons.person, color: Colors.purple),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.8), 
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.white70, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "Search friends or chats",
                                  hintStyle: TextStyle(color: Colors.white70, fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            const Icon(Icons.mail, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Tab Bar
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
                          // Real-time request badge
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
          
          // 2. Main Body Content
          Expanded(
            child: showSearchResults 
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDiscussionsList(), 
                      const Center(child: Text("Friend Requests List")), 
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}