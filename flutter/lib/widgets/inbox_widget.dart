import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/message.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_client.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/services/friend_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/socket_service.dart';
import 'package:ru_project/widgets/chat_ui.dart';

/// Boîte de réception unifiée : Global épinglé + une ligne par ami, triées
/// par dernière activité, avec aperçu du dernier message et horodatage.
class InboxWidget extends StatefulWidget {
  const InboxWidget({super.key});

  @override
  State<InboxWidget> createState() => _InboxWidgetState();
}

class _InboxWidgetState extends State<InboxWidget> {
  late final SocketService _socketService;
  late final ApiClient _apiClient;
  StreamSubscription<ChatEvent>? _sub;
  Map<String, Message?> _summaries = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);
    _apiClient = Provider.of<ApiClient>(context, listen: false);
    // Aperçus mis à jour en direct à chaque nouveau message (toutes rooms).
    _sub = Provider.of<ChatConnection>(context, listen: false)
        .events
        .listen(_onChatEvent);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onChatEvent(ChatEvent event) {
    if (!mounted) return;
    if (event is MessageNotified) {
      setState(() => _summaries[event.roomName] = event.message);
    } else if (event is MessageReceived) {
      setState(() => _summaries[event.roomName] = event.message);
    }
  }

  Future<void> _load() async {
    final summaries = await _socketService.getConversations();
    if (!mounted) return;
    setState(() {
      _summaries = summaries;
      _loading = false;
    });
  }

  /// Tirer pour rafraîchir : conversations ET liste d'amis (un ami ajouté
  /// depuis un autre appareil apparaît sans redémarrer l'appli).
  Future<void> _refresh() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final friendService = Provider.of<FriendService>(context, listen: false);
    await Future.wait([
      _load(),
      friendService
          .getFriends()
          .then(userProvider.setFriends)
          .catchError((Object e) => logger.e('Inbox: amis non rafraîchis: $e')),
    ]);
  }

  void _openRoom(User user, String roomName, String title, {Friend? friend}) {
    openChat(
      context,
      roomName: roomName,
      title: title,
      actualUser: user,
      friend: friend,
    ).then((_) => _load());
  }

  String _preview(User user, Message? message) {
    if (message == null) return 'Aucun message';
    final content = message.isAudio ? '🎤 Message vocal' : message.content;
    final isMine = message.senderId != null
        ? message.senderId == user.id
        : message.sender == user.username;
    return isMine ? 'Toi : $content' : '${message.sender} : $content';
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    // Transition de déconnexion : plus d'utilisateur, rien à afficher.
    if (user == null) return const SizedBox.shrink();
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final notifications = context.watch<NotificationProvider>();
    final friends = [...userProvider.friends];
    DateTime lastActivity(Friend f) =>
        _summaries[ChatConnection.privateRoomName(user.id, f.id)]?.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    // Conversations les plus récentes en premier, puis ordre alphabétique.
    friends.sort((a, b) {
      final byDate = lastActivity(b).compareTo(lastActivity(a));
      return byDate != 0
          ? byDate
          : a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Global épinglé en haut
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.public)),
            title: const Text('Global'),
            subtitle: Text(
              _preview(user, _summaries['Global']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _trailing(
                _summaries['Global'], notifications.unreadFor('Global')),
            onTap: () => _openRoom(user, 'Global', 'Global'),
          ),
          const Divider(height: 1),

          if (friends.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Ajoute des amis depuis l\'onglet « Amis » pour discuter en privé.',
                textAlign: TextAlign.center,
              ),
            ),

          // Une ligne par ami
          for (final friend in friends)
            _friendTile(user, friend, notifications),
        ],
      ),
    );
  }

  Widget? _trailing(Message? last, int unread) {
    if (last == null && unread == 0) return null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (last != null)
          Text(
            timeAgo(last.createdAt),
            style: unread > 0
                ? TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600)
                : null,
          ),
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Badge(label: Text('$unread')),
          ),
      ],
    );
  }

  Widget _friendTile(
      User user, Friend friend, NotificationProvider notifications) {
    final roomName = ChatConnection.privateRoomName(user.id, friend.id);
    final last = _summaries[roomName];
    final unread = notifications.unreadFor(roomName);
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: friend.avatarUrl.isNotEmpty
            ? NetworkImage(_apiClient.getImageNetworkUrl(friend.avatarUrl))
            : null,
        child: friend.avatarUrl.isEmpty
            ? Text(friend.username.characters.first.toUpperCase())
            : null,
      ),
      title: Text(
        friend.username,
        style: unread > 0 ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
      subtitle: Text(
        _preview(user, last),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _trailing(last, unread),
      onTap: () => _openRoom(user, roomName, friend.username, friend: friend),
    );
  }
}
