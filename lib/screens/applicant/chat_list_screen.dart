import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class ApplicantChatListScreen extends StatefulWidget {
  const ApplicantChatListScreen({super.key});

  @override
  State<ApplicantChatListScreen> createState() => _ApplicantChatListScreenState();
}

class _ApplicantChatListScreenState extends State<ApplicantChatListScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<ChatRoom> _chats = [];
  bool _isLoading = true;

  // Color palette
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      setState(() => _isLoading = true);
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final chats = await ChatService.getUserChats(user.id);
      
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load chats: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
              ),
            )
          : _chats.isEmpty
              ? _buildEmptyState()
              : _buildChatList(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Messages',
        style: TextStyle(
          color: darkTeal,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back_ios,
          color: darkTeal,
          size: 24,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _loadChats,
          icon: const Icon(
            Icons.refresh,
            color: mediumSeaGreen,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _EmptyStateIcon(),
          SizedBox(height: 24),
          _EmptyStateTitle(),
          SizedBox(height: 8),
          _EmptyStateSubtitle(),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      itemCount: _chats.length,
      cacheExtent: 500, // Cache more items for smoother scrolling
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return _ChatListItem(
          chat: chat,
          onTap: () => _navigateToChat(chat, chat.members.firstWhere(
            (member) => member.userId != _supabase.auth.currentUser?.id,
            orElse: () => chat.members.first,
          )),
        );
      },
    );
  }

  void _navigateToChat(ChatRoom chat, ChatMember otherMember) async {
    // Mark messages as read when opening chat
    if (chat.unreadCount > 0) {
      try {
        await ChatService.markMessagesAsRead(chat.id);
        // Refresh the chat list to update unread counts
        _loadChats();
      } catch (e) {
        // Silently handle error - user can still navigate to chat
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplicantChatScreen(
          chatId: chat.id,
          employerId: otherMember.userId,
          employerName: otherMember.userName ?? 'Unknown Employer',
          jobTitle: chat.jobTitle ?? 'Job Application',
        ),
      ),
    ).then((_) {
      // Refresh chats when returning from chat screen
      _loadChats();
    });
  }
}

// Optimized const widgets to reduce rebuilds
class _EmptyStateIcon extends StatelessWidget {
  const _EmptyStateIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF4CA771).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.chat_bubble_outline,
        size: 60,
        color: Color(0xFF4CA771),
      ),
    );
  }
}

class _EmptyStateTitle extends StatelessWidget {
  const _EmptyStateTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'No conversations yet',
      style: TextStyle(
        color: Color(0xFF013237),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _EmptyStateSubtitle extends StatelessWidget {
  const _EmptyStateSubtitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Start chatting with employers who\nrespond to your job applications',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFF013237).withValues(alpha: 0.7),
        fontSize: 14,
      ),
    );
  }
}

// Optimized chat list item to reduce rebuilds
class _ChatListItem extends StatelessWidget {
  final ChatRoom chat;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final otherMember = chat.members.firstWhere(
      (member) => member.userId != currentUser?.id,
      orElse: () => chat.members.first,
    );

    final otherMemberInitial = otherMember.userName?.isNotEmpty == true
        ? otherMember.userName![0].toUpperCase()
        : 'E';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0F0F0),
            width: 0.5,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Large profile picture
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CA771), Color(0xFF013237)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      otherMemberInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Contact info and message preview
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact name and job title
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contact name
                          Text(
                            otherMember.userName ?? 'Unknown Employer',
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Job title and company (if available)
                          if (chat.jobTitle != null || chat.companyName != null) ...[
                            const SizedBox(height: 3),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [                              
                                // Company name
                                if (chat.companyName != null) ...[
                                  Text(
                                    chat.companyName!,
                                    style: TextStyle(
                                      color: const Color(0xFF666666),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 5),
                                 // Job title
                                if (chat.jobTitle != null) ...[
                                  Text(
                                    chat.jobTitle!,
                                    style: TextStyle(
                                      color: const Color(0xFF4CA771),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],                                
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Message preview
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getLastMessagePreview(chat),
                              style: TextStyle(
                                color: chat.unreadCount > 0 
                                    ? const Color(0xFF1A1A1A)
                                    : const Color(0xFF666666),
                                fontSize: 14,
                                fontWeight: chat.unreadCount > 0 
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Unread count badge or timestamp
                          if (chat.unreadCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CA771),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              chat.lastMessageAt != null
                                  ? _formatTime(chat.lastMessageAt!)
                                  : '',
                              style: const TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLastMessagePreview(ChatRoom chat) {
    if (chat.lastMessage == null) {
      return 'No messages yet';
    }
    
    final message = chat.lastMessage!;
    final content = message['content'] as String? ?? '';
    final senderId = message['sender_id'] as String? ?? '';
    final currentUser = Supabase.instance.client.auth.currentUser;
    
    // Check if the message was sent by the current user
    final isFromCurrentUser = senderId == currentUser?.id;
    
    if (isFromCurrentUser) {
      return 'You: $content';
    } else {
      // Get sender name from profiles
      final senderName = message['profiles']?['full_name'] as String? ?? 'User';
      return '$senderName: $content';
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
}
