import 'package:flutter/material.dart';
import '../services/friend_service.dart';

class FriendRequestsPage extends StatefulWidget {

    final bool showAppBar;
 const FriendRequestsPage({
    super.key,
    this.showAppBar = true,
  });
    @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  final FriendService _friendService = FriendService();
  
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() async {
    final data = await _friendService.getReceivedRequests();
    setState(() {
      _requests = data;
      _isLoading = false;
    });
  }

  void _accept(String reqId, String fromUid) async {
    await _friendService.acceptRequest(reqId, fromUid);
    _loadRequests();
  }

  void _delete(String reqId) async {
    await _friendService.deleteRequest(reqId);
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: widget.showAppBar
          ? AppBar(title: const Text("Friend Requests"),       
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
)
          : null, // If showAppBar is false, this will be null, hiding it.
          
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(child: Text("No friend requests"))
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, i) {
                    final req = _requests[i];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: req['imageUrl'] != ''
                              ? NetworkImage(req['imageUrl'])
                              : null,
                          child: req['imageUrl'] == ''
                              ? Icon(Icons.person)
                              : null,
                        ),
                        title: Text(req['name']),
                        subtitle: Text(req['email']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () => _accept(req['requestId'], req['fromUid']),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () => _delete(req['requestId']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
