import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart' as ru_project;
import 'package:ru_project/models/message.dart' as ru_project;
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/services/api_client.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/services/socket_service.dart';
import 'package:ru_project/widgets/audio_player_widget.dart';
import 'package:ru_project/widgets/voice_recorder_sheet.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:uuid/uuid.dart';

/// Longueur max d'un message (alignée sur le backend).
const int kMaxMessageLength = 2000;

/// Ouvre une conversation en plein écran.
Future<void> openChat(
  BuildContext context, {
  required String roomName,
  required String title,
  required ru_project.User actualUser,
  ru_project.Friend? friend,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatPage(
        roomName: roomName,
        title: title,
        actualUser: actualUser,
        friend: friend,
      ),
    ),
  );
}

/// Page de conversation : AppBar (titre, état de connexion, actions) + chat.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.roomName,
    required this.title,
    required this.actualUser,
    this.friend,
  });

  final String roomName;
  final String title;
  final ru_project.User actualUser;
  final ru_project.Friend? friend;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _chatKey = GlobalKey<ChatUiState>();

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<ChatConnection>().isConnected;
    final friend = widget.friend;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              isConnected
                  ? (friend != null ? friend.status : 'Tout le campus')
                  : 'Connexion…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (friend != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _chatKey.currentState?.confirmClearConversation();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'clear',
                  child: Text('Vider la conversation'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ChatUi(
          key: _chatKey,
          roomName: widget.roomName,
          actualUser: widget.actualUser,
          friends: friend != null ? [friend] : null,
        ),
      ),
    );
  }
}

class ChatUi extends StatefulWidget {
  const ChatUi({
    super.key,
    required this.roomName,
    required this.actualUser,
    this.friends,
  });

  final ru_project.User actualUser;
  final List<ru_project.Friend>? friends;
  final String roomName;

  @override
  ChatUiState createState() => ChatUiState();
}

class ChatUiState extends State<ChatUi> {
  final _uuid = const Uuid();
  late final SocketService socketService;
  late final ChatConnection chatConnection;
  late final ApiClient apiClient;
  late final NotificationProvider notifications;
  late final types.InMemoryChatController chatController;
  StreamSubscription<ChatEvent>? _sub;

  /// Auteurs connus (id -> nom + avatar), alimenté par les messages reçus.
  final Map<String, types.User> _users = {};

  /// Messages locaux pas encore confirmés par le serveur (id temporaire ->
  /// texte), conservés lors d'un rechargement et rejouables en cas d'échec.
  final Map<String, String> _pendingTexts = {};

  bool _loading = true;
  bool _loadError = false;
  bool _hasMore = false;
  bool _loadingOlder = false;

  String get _myId => widget.actualUser.id;
  bool get _isGlobal => widget.roomName == 'Global';

  @override
  void initState() {
    super.initState();
    socketService = Provider.of<SocketService>(context, listen: false);
    chatConnection = Provider.of<ChatConnection>(context, listen: false);
    apiClient = Provider.of<ApiClient>(context, listen: false);
    notifications = Provider.of<NotificationProvider>(context, listen: false);
    notifications.setCurrentRoom(widget.roomName);
    chatController = types.InMemoryChatController();
    _users[_myId] = types.User(
      id: _myId,
      name: widget.actualUser.username,
      imageSource: apiClient.getImageNetworkUrl(widget.actualUser.avatarUrl),
    );

    // La socket peut ne pas être ouverte (ex : échec au login) : on retente.
    chatConnection.connect();
    if (_isGlobal) {
      chatConnection.joinGlobal();
    } else if (widget.friends != null && widget.friends!.isNotEmpty) {
      chatConnection.joinPrivate(_myId, widget.friends!.first.id);
    }

    _sub = chatConnection.events
        .where((e) => e.roomName == widget.roomName)
        .listen(_onChatEvent);

    _loadLatest();
  }

  @override
  void dispose() {
    _sub?.cancel();
    notifications.setCurrentRoom(null);
    chatConnection.leave(widget.roomName);
    chatController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Conversion modèle métier -> modèle UI

  /// Convertit un message métier en message d'UI (texte ou vocal).
  types.Message _toUiMessage(ru_project.Message message) {
    final authorId = message.authorKey;
    _users[authorId] = types.User(
      id: authorId,
      name: message.sender,
      imageSource: message.senderAvatarUrl != null
          ? apiClient.getImageNetworkUrl(message.senderAvatarUrl!)
          : null,
    );
    final status =
        authorId == _myId ? types.MessageStatus.sent : null;
    if (message.isAudio) {
      return types.AudioMessage(
        id: message.id,
        authorId: authorId,
        source: apiClient.getImageNetworkUrl(message.audioUrl!),
        duration: Duration(seconds: message.duration ?? 0),
        createdAt: message.createdAt,
        status: status,
      );
    }
    return types.TextMessage(
      id: message.id,
      authorId: authorId,
      text: message.content,
      createdAt: message.createdAt,
      status: status,
    );
  }

  bool _contains(String id) => chatController.messages.any((m) => m.id == id);

  List<types.Message> get _pendingMessages => chatController.messages
      .where((m) => _pendingTexts.containsKey(m.id))
      .toList();

  // ---------------------------------------------------------------------------
  // Chargement de l'historique

  Future<void> _loadLatest() async {
    final page = await socketService.getMessagesFromRoom(widget.roomName);
    if (!mounted) return;
    if (page == null) {
      setState(() {
        _loading = false;
        _loadError = chatController.messages.isEmpty;
      });
      if (!_loadError) _showSnack('Impossible d\'actualiser la conversation');
      return;
    }
    final messages = page.messages.map(_toUiMessage).toList();
    final serverIds = messages.map((m) => m.id).toSet();
    // On garde les envois locaux en cours (ou en échec) à la fin.
    final pending =
        _pendingMessages.where((m) => !serverIds.contains(m.id)).toList();
    await chatController.setMessages([...messages, ...pending]);
    if (!mounted) return;
    setState(() {
      _hasMore = page.hasMore;
      _loading = false;
      _loadError = false;
    });
  }

  Future<void> _retryInitialLoad() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    await _loadLatest();
  }

  /// Remonte l'historique quand l'utilisateur atteint le haut de la liste.
  Future<void> _loadOlder() async {
    if (!_hasMore || _loadingOlder) return;
    final oldest = chatController.messages
        .where((m) => !_pendingTexts.containsKey(m.id))
        .firstOrNull;
    final before = oldest?.createdAt;
    if (before == null) return;
    _loadingOlder = true;
    try {
      final page = await socketService.getMessagesFromRoom(widget.roomName,
          before: before);
      if (!mounted || page == null) return;
      final older = page.messages
          .where((m) => !_contains(m.id))
          .map(_toUiMessage)
          .toList();
      await chatController.insertAllMessages(older, index: 0);
      if (mounted) setState(() => _hasMore = page.hasMore);
    } finally {
      _loadingOlder = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Temps réel

  void _onChatEvent(ChatEvent event) {
    if (!mounted) return;
    switch (event) {
      case MessageReceived(:final message):
        if (_contains(message.id)) return;
        chatController.insertMessage(_toUiMessage(message));
        if (_loadError) setState(() => _loadError = false);
      case MessageDeleted(:final messageId):
        final existing =
            chatController.messages.where((m) => m.id == messageId).firstOrNull;
        if (existing != null) chatController.removeMessage(existing);
      case AllMessagesDeleted():
        chatController.setMessages(_pendingMessages);
      case ChatResynced():
        // Reconnexion après une coupure : on récupère ce qui a été manqué.
        _loadLatest();
      case MessageNotified():
        // Géré par NotificationProvider ; la room ouverte affiche déjà le
        // message via MessageReceived.
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Envoi

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sendText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;
    if (text.length > kMaxMessageLength) {
      _showSnack(
          'Message trop long (${text.length}/$kMaxMessageLength caractères)');
      return;
    }

    final tempId = 'local-${_uuid.v4()}';
    _pendingTexts[tempId] = text;
    final message = types.TextMessage(
      id: tempId,
      authorId: _myId,
      text: text,
      createdAt: DateTime.now(),
      status: types.MessageStatus.sending,
    );
    await chatController.insertMessage(message);
    await _deliver(message);
  }

  /// Envoie (ou renvoie) un message local et met à jour son statut.
  Future<void> _deliver(types.TextMessage local) async {
    final text = _pendingTexts[local.id];
    if (text == null) return;
    final response =
        await socketService.sendMessageToRoom(widget.roomName, text);
    if (!mounted) return;
    final current =
        chatController.messages.where((m) => m.id == local.id).firstOrNull;
    if (current == null) return; // supprimé entre-temps

    if (response == null) {
      await chatController.updateMessage(
        current,
        local.copyWith(
          status: types.MessageStatus.error,
          failedAt: DateTime.now(),
        ),
      );
      _showSnack('Message non envoyé — touche-le pour réessayer');
      return;
    }

    _pendingTexts.remove(local.id);
    if (_contains(response.id)) {
      // Déjà récupéré par un rechargement : on retire juste la copie locale.
      await chatController.removeMessage(current);
      return;
    }
    await chatController.updateMessage(current, _toUiMessage(response));
  }

  // Ouvre la feuille d'enregistrement ; à l'envoi, upload puis insertion
  // (le serveur ne ré-émet pas à l'expéditeur).
  Future<void> _recordAndSendAudio() async {
    final result = await showModalBottomSheet<RecordedAudio>(
      context: context,
      builder: (_) => const VoiceRecorderSheet(),
    );
    if (result == null || !mounted) return;

    final sent = await socketService.sendAudioMessage(
        widget.roomName, result.path, result.duration);
    if (sent == null) {
      _showSnack('Échec de l\'envoi du vocal');
      return;
    }
    if (mounted && !_contains(sent.id)) {
      await chatController.insertMessage(_toUiMessage(sent));
    }
  }

  // ---------------------------------------------------------------------------
  // Actions sur un message

  void _onMessageTap(BuildContext context, types.Message message,
      {required int index, required TapUpDetails details}) {
    if (message.status == types.MessageStatus.error &&
        _pendingTexts.containsKey(message.id)) {
      _showFailedMessageActions(message as types.TextMessage);
    }
  }

  void _onMessageLongPress(BuildContext context, types.Message message,
      {required int index, required LongPressStartDetails details}) {
    if (_pendingTexts.containsKey(message.id)) {
      if (message.status == types.MessageStatus.error) {
        _showFailedMessageActions(message as types.TextMessage);
      }
      return;
    }
    final canDelete = message.authorId == _myId;
    final text = message is types.TextMessage ? message.text : null;
    if (!canDelete && text == null) return;

    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: this.context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copier'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: text));
                  _showSnack('Message copié');
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(sheetContext).colorScheme.error),
                title: const Text('Supprimer'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showFailedMessageActions(types.TextMessage message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Réessayer'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final sending =
                    message.copyWith(status: types.MessageStatus.sending);
                await chatController.updateMessage(message, sending);
                await _deliver(sending);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Annuler l\'envoi'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pendingTexts.remove(message.id);
                chatController.removeMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(types.Message item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text(
            'Ce message sera supprimé pour tous les participants.'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          TextButton(
            child: const Text('Supprimer'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final index = chatController.messages.indexWhere((m) => m.id == item.id);
    if (index == -1) return;
    await chatController.removeMessage(item);
    final ok = await socketService.deleteMessage(item.id, widget.roomName);
    if (!ok && mounted) {
      // Échec : on remet le message à sa place.
      final restoreAt = index.clamp(0, chatController.messages.length);
      if (!_contains(item.id)) {
        await chatController.insertMessage(item, index: restoreAt);
      }
      _showSnack('Impossible de supprimer ce message');
    }
  }

  /// Vide toute la conversation (privée uniquement), après confirmation.
  Future<void> confirmClearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vider la conversation'),
        content: const Text(
            'Tous les messages seront supprimés, pour vous deux. Cette action est définitive.'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          TextButton(
            child: const Text('Vider'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await socketService.deleteMessages(widget.roomName);
    if (!mounted) return;
    if (ok) {
      _pendingTexts.clear();
      await chatController.setMessages([]);
      setState(() => _hasMore = false);
    } else {
      _showSnack('Impossible de vider la conversation');
    }
  }

  // ---------------------------------------------------------------------------
  // Rendu

  /// En Global, on affiche le pseudo (et l'avatar) des autres participants.
  Widget _buildMessageWrapper(
    BuildContext context,
    types.Message message,
    int index,
    Animation<double> animation,
    Widget child, {
    bool? isRemoved,
    required bool isSentByMe,
    types.MessageGroupStatus? groupStatus,
  }) {
    final showIdentity = _isGlobal && !isSentByMe;
    final isFirstOfGroup = groupStatus == null || groupStatus.isFirst;
    final isLastOfGroup = groupStatus == null || groupStatus.isLast;
    return ui.ChatMessage(
      message: message,
      index: index,
      animation: animation,
      isRemoved: isRemoved,
      groupStatus: groupStatus,
      topWidget: showIdentity && isFirstOfGroup
          ? Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 2),
              child: ui.Username(userId: message.authorId),
            )
          : null,
      leadingWidget: showIdentity
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: isLastOfGroup
                  ? ui.Avatar(userId: message.authorId)
                  : const SizedBox(width: 32),
            )
          : null,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Impossible de charger la conversation.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _retryInitialLoad,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return ui.Chat(
      currentUserId: _myId,
      resolveUser: (types.UserID id) async =>
          _users[id] ?? types.User(id: id, name: id),
      chatController: chatController,
      onMessageSend: _sendText,
      onAttachmentTap: _recordAndSendAudio,
      onMessageTap: _onMessageTap,
      onMessageLongPress: _onMessageLongPress,
      builders: types.Builders(
        composerBuilder: (_) => const ui.Composer(
          hintText: 'Écris un message…',
          attachmentIcon: Icon(Icons.mic_none_outlined),
        ),
        emptyChatListBuilder: (_) => ui.EmptyChatList(
          text: _isGlobal
              ? 'Aucun message pour l\'instant.\nLance la discussion avec tout le campus 👋'
              : 'Aucun message pour l\'instant.\nDis bonjour 👋',
        ),
        chatAnimatedListBuilder: (context, itemBuilder) =>
            ui.ChatAnimatedList(
          itemBuilder: itemBuilder,
          onEndReached: _hasMore ? _loadOlder : null,
        ),
        chatMessageBuilder: _buildMessageWrapper,
        audioMessageBuilder: (
          BuildContext context,
          types.AudioMessage message,
          int index, {
          required bool isSentByMe,
          types.MessageGroupStatus? groupStatus,
        }) {
          return SizedBox(
            width: 250,
            child: AudioPlayerWidget(message: message),
          );
        },
      ),
    );
  }
}
