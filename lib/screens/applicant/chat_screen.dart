import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Mock chat data
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      text: 'Hi! I saw your application for the Junior Developer position. Are you available for an interview this week?',
      isFromEmployer: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      employerName: 'Jeremiah\'s Company',
      employerAvatar: 'J',
    ),
    ChatMessage(
      id: '2',
      text: 'Yes, I would love to schedule an interview! I\'m available on Tuesday and Thursday afternoon.',
      isFromEmployer: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    ChatMessage(
      id: '3',
      text: 'Perfect! How about Tuesday at 2:00 PM? We can do it via video call.',
      isFromEmployer: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      employerName: 'Jeremiah\'s Company',
      employerAvatar: 'J',
    ),
    ChatMessage(
      id: '4',
      text: 'That works great for me. I\'ll send you the meeting link shortly.',
      isFromEmployer: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      employerName: 'Jeremiah\'s Company',
      employerAvatar: 'J',
    ),
    ChatMessage(
      id: '5',
      text: 'Thank you! I\'m looking forward to it. Should I prepare anything specific for the interview?',
      isFromEmployer: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    ChatMessage(
      id: '6',
      text: 'Just be ready to discuss your experience and maybe do a quick coding exercise. Nothing too stressful! 😊',
      isFromEmployer: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      employerName: 'Jeremiah\'s Company',
      employerAvatar: 'J',
    ),
  ];

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: _messageController.text.trim(),
            isFromEmployer: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _messageController.clear();
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildChatHeader(),
          Expanded(
            child: _buildChatMessages(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Chat',
        style: TextStyle(
          color: darkTeal,
          fontWeight: FontWeight.bold,
          fontSize: 16,
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
          onPressed: () {
            // TODO: Implement video call
          },
          icon: const Icon(
            Icons.video_call,
            color: mediumSeaGreen,
            size: 24,
          ),
        ),
        IconButton(
          onPressed: () {
            // TODO: Implement more options
          },
          icon: const Icon(
            Icons.more_vert,
            color: darkTeal,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: paleGreen,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Employer avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [mediumSeaGreen, darkTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Center(
              child: Text(
                'J',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jeremiah\'s Company',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: mediumSeaGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: mediumSeaGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mediumSeaGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Text(
              'Junior Developer',
              style: TextStyle(
                color: mediumSeaGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    return Container(
      color: lightMint,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageBubble(message, index);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isFromEmployer = message.isFromEmployer;
    final showAvatar = isFromEmployer && 
        (index == 0 || _messages[index - 1].isFromEmployer == false);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isFromEmployer) ...[
            if (showAvatar) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [mediumSeaGreen, darkTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    message.employerAvatar ?? 'E',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              const SizedBox(width: 40),
            ],
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isFromEmployer 
                  ? CrossAxisAlignment.start 
                  : CrossAxisAlignment.end,
              children: [
                if (isFromEmployer && showAvatar) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      message.employerName ?? 'Employer',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isFromEmployer ? Colors.white : mediumSeaGreen,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isFromEmployer ? 4 : 20),
                      bottomRight: Radius.circular(isFromEmployer ? 20 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: darkTeal.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isFromEmployer ? darkTeal : Colors.white,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(
                    left: isFromEmployer ? 8 : 0,
                    right: isFromEmployer ? 0 : 8,
                  ),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isFromEmployer) ...[
            const SizedBox(width: 40),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: paleGreen,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: paleGreen.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: darkTeal,
                    fontSize: 11,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: mediumSeaGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isFromEmployer;
  final DateTime timestamp;
  final String? employerName;
  final String? employerAvatar;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isFromEmployer,
    required this.timestamp,
    this.employerName,
    this.employerAvatar,
  });
}


