import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';

class EmployerChatScreen extends StatefulWidget {
  final String chatId;
  final String applicantId;
  final String applicantName;
  final String jobTitle;
  
  const EmployerChatScreen({
    super.key,
    required this.chatId,
    required this.applicantId,
    required this.applicantName,
    required this.jobTitle,
  });

  @override
  State<EmployerChatScreen> createState() => _EmployerChatScreenState();
}

class _EmployerChatScreenState extends State<EmployerChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _isOtherUserTyping = false;
  String? _otherUserTypingName;
  
  // Animation controllers
  late AnimationController _typingAnimationController;
  late AnimationController _messageAnimationController;
  
  // Map to track which messages have their timestamps visible
  Map<String, bool> _showTimestamps = {};
  
  // Map to track sent messages that should auto-progress to delivered
  Map<String, Timer> _sentMessageTimers = {};

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);
  static const Color applicantBubbleColor = Color(0xFFF0F9F0);

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _setupScrollListener();
    _setupRealtimeSubscription();
    
    // Load messages after a short delay to ensure widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMessages();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _messageAnimationController.dispose();
    
    // Cancel all pending timers
    for (final timer in _sentMessageTimers.values) {
      timer.cancel();
    }
    _sentMessageTimers.clear();
    
    ChatService.unsubscribeFromMessages();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _isLoading = true);
      final messages = await ChatService.getInitialMessages(widget.chatId);
      
      if (mounted) {
        setState(() {
          // Sort messages chronologically (oldest first, newest last)
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _messages = messages;
          _isLoading = false;
          _hasMoreMessages = messages.length >= 20;
        });
        
        // Force a complete rebuild of the ListView
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // This will trigger a complete rebuild
            });
            // Scroll immediately first, then animate
            _scrollToBottomImmediately();
            Future.delayed(const Duration(milliseconds: 100), () {
              _scrollToBottom();
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load messages: $e');
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    try {
      setState(() => _isLoadingMore = true);
      
      final moreMessages = await ChatService.loadMoreMessages(
        widget.chatId, 
        _messages.length,
      );
      
      if (mounted) {
        setState(() {
          // Sort older messages chronologically and insert at the beginning
          moreMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _messages.insertAll(0, moreMessages);
          _isLoadingMore = false;
          _hasMoreMessages = moreMessages.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Check when we're near the top (position 0) to load more messages
      if (_scrollController.position.pixels <= 100 && _hasMoreMessages && !_isLoadingMore) {
        _loadMoreMessages();
      }
    });
  }

  void _setupRealtimeSubscription() {
    ChatService.subscribeToMessages(widget.chatId, (message) {
      setState(() {
        // Check if this is a new message or an update to existing message
        final existingIndex = _messages.indexWhere((m) => m.id == message.id);
        if (existingIndex >= 0) {
          // Update existing message
          _messages[existingIndex] = message;
        } else {
          // Add new message in correct chronological position
          _insertMessageInOrder(message);
          _messageAnimationController.forward();
          _scrollToBottom();
          
          // Handle status progression for user's own messages
          _handleMessageStatusProgression(message);
        }
      });
    });

    // Subscribe to typing indicators
    ChatService.subscribeToTypingIndicators(widget.chatId, (typingData) {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && typingData['user_id'] != currentUser.id) {
        setState(() {
          _isOtherUserTyping = typingData['is_typing'] == true;
          if (_isOtherUserTyping) {
            _otherUserTypingName = typingData['user_name'] ?? 'Someone';
          }
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final messageText = _messageController.text.trim();
    _messageController.clear();

    // Stop typing indicator
    await ChatService.stopTyping(widget.chatId);

    try {
      await ChatService.sendMessage(
        chatId: widget.chatId,
        content: messageText,
      );
      
      // Mark messages as read
      await ChatService.markMessagesAsRead(widget.chatId);
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
      // Restore message text on error
      _messageController.text = messageText;
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      ChatService.startTyping(widget.chatId);
    } else {
      ChatService.stopTyping(widget.chatId);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Add a small delay to ensure ListView is fully built
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            // Scroll to the actual bottom (maxScrollExtent)
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  void _scrollToBottomImmediately() {
    if (_scrollController.hasClients) {
      // Scroll to the actual bottom (maxScrollExtent)
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
      backgroundColor: lightMint,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildJobApplicationInfo(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMessages,
              color: mediumSeaGreen,
              child: _buildChatMessages(),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final applicantInitial = widget.applicantName.isNotEmpty 
        ? widget.applicantName[0].toUpperCase() 
        : 'A';
    
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: darkTeal.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: lightMint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: darkTeal,
            size: 20,
          ),
        ),
      ),
      title: Row(
        children: [
          // Enhanced applicant avatar with online indicator
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [mediumSeaGreen, Color(0xFF2E7D4E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: mediumSeaGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    applicantInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Online indicator
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.applicantName,
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Active now',
                      style: TextStyle(
                        color: mediumSeaGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [],
    );
  }

  Widget _buildJobApplicationInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: mediumSeaGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.work_outline_rounded,
              color: mediumSeaGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job Application',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.jobTitle,
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [mediumSeaGreen, Color(0xFF2E7D4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: mediumSeaGreen.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'Applied',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    // Show loading state
    if (_isLoading && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: mediumSeaGreen.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading conversation...',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Show empty state only if not loading and no messages
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: mediumSeaGreen.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start the conversation!',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to begin chatting\nwith the applicant',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lightMint.withValues(alpha: 0.3),
            lightMint.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: ListView.builder(
        key: ValueKey('messages_${_messages.length}_${DateTime.now().millisecondsSinceEpoch}'), // Force rebuild when messages change
        controller: _scrollController,
        padding: const EdgeInsets.only(
          left: 16,
          right: 8, // Reduce right padding so bubbles can extend closer to edge
          top: 24, // Increased top padding to push bubbles down
          bottom: 4, // Further reduced bottom padding to minimize gap
        ),
        itemCount: _messages.length + (_isOtherUserTyping ? 1 : 0) + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading more indicator at the top (which is now at the bottom due to reverse)
          if (_isLoadingMore && index == 0) {
            return _buildLoadingMoreIndicator();
          }
          
          // Adjust message index if loading more
          final messageIndex = _isLoadingMore ? index - 1 : index;
          
          // Typing indicator
          if (_isOtherUserTyping && messageIndex == _messages.length) {
            return _buildTypingIndicator();
          }
          
          // Message bubble
          if (messageIndex < _messages.length) {
            final message = _messages[messageIndex];
            return _buildMessageBubble(message, messageIndex);
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _insertMessageInOrder(ChatMessage message) {
    // Find the correct position to insert the message chronologically
    int insertIndex = _messages.length;
    
    for (int i = 0; i < _messages.length; i++) {
      if (message.createdAt.isBefore(_messages[i].createdAt)) {
        insertIndex = i;
        break;
      }
    }
    
    _messages.insert(insertIndex, message);
  }

  void _handleMessageStatusProgression(ChatMessage message) {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null || message.senderId != currentUser.id) return;

    // If message is in "sent" status, set up a timer to auto-progress to "delivered"
    if (message.status == MessageStatus.sent) {
      // Cancel any existing timer for this message
      _sentMessageTimers[message.id]?.cancel();
      
      // Set up new timer to progress to delivered after 2 seconds
      _sentMessageTimers[message.id] = Timer(const Duration(seconds: 2), () {
        setState(() {
          final messageIndex = _messages.indexWhere((m) => m.id == message.id);
          if (messageIndex >= 0) {
            // Create updated message with delivered status
            final updatedMessage = ChatMessage(
              id: message.id,
              chatId: message.chatId,
              senderId: message.senderId,
              content: message.content,
              messageType: message.messageType,
              createdAt: message.createdAt,
              editedAt: message.editedAt,
              deletedAt: message.deletedAt,
              isRead: message.isRead,
              replyToId: message.replyToId,
              senderName: message.senderName,
              senderAvatar: message.senderAvatar,
              status: MessageStatus.delivered,
              sentAt: message.sentAt,
              deliveredAt: DateTime.now(),
              seenAt: message.seenAt,
              failedAt: message.failedAt,
            );
            _messages[messageIndex] = updatedMessage;
          }
        });
        
        // Clean up timer
        _sentMessageTimers.remove(message.id);
      });
    }
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final currentUser = _supabase.auth.currentUser;
    final isFromCurrentUser = message.senderId == currentUser?.id;
    
    // Show avatar with the latest message from this sender (chronologically last)
    final showAvatar = !isFromCurrentUser && 
        (index == _messages.length - 1 || _messages[index + 1].senderId != message.senderId);
    
    // Show name with the first message from this sender (chronologically first)
    final showName = !isFromCurrentUser && 
        (index == 0 || _messages[index - 1].senderId != message.senderId);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromCurrentUser) ...[
            // LEFT SIDE - Applicant messages
            if (showAvatar) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [mediumSeaGreen, Color(0xFF2E7D4E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: mediumSeaGreen.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    message.senderAvatar ?? message.senderName?.substring(0, 1).toUpperCase() ?? 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              const SizedBox(width: 48),
            ],
            
            // Applicant message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show timestamp above applicant messages when tapped
                  if (_showTimestamps[message.id] == true) ...[
                    Center(
                      child: Text(
                        _formatDetailedTime(message.createdAt),
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (showName) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 6),
                      child: Text(
                        message.senderName ?? 'Applicant',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showTimestamps[message.id] = !(_showTimestamps[message.id] ?? false);
                      });
                    },
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: applicantBubbleColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border.all(
                          color: paleGreen.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: darkTeal.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // RIGHT SIDE - Current user messages
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showTimestamps[message.id] = !(_showTimestamps[message.id] ?? false);
                      });
                    },
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [mediumSeaGreen, Color(0xFF2E7D4E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: mediumSeaGreen.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        message.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  // Show status below user messages when tapped
                  if (_showTimestamps[message.id] == true) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildMessageStatusIcon(message),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 0), // Minimal spacing for edge
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), // Reduced vertical padding
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Calendar button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: paleGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: () {
                  _showCalendarOptions();
                },
                icon: Icon(
                  Icons.calendar_today_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: lightMint,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: paleGreen.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  onChanged: _onTextChanged,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: darkTeal.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Send button with enhanced design
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _isSending 
                      ? null
                      : const LinearGradient(
                          colors: [mediumSeaGreen, Color(0xFF2E7D4E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _isSending ? mediumSeaGreen.withValues(alpha: 0.5) : null,
                  shape: BoxShape.circle,
                  boxShadow: _isSending ? null : [
                    BoxShadow(
                      color: mediumSeaGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading more messages...',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTypingDot(int index) {
    final delay = index * 0.2;
    final animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimationController,
        curve: Interval(delay, delay + 0.6, curve: Curves.easeInOut),
      ),
    );
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: darkTeal.withValues(alpha: animation.value * 0.6),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }


  String _formatDetailedTime(DateTime timestamp) {
    final weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final weekday = weekdays[timestamp.weekday - 1];
    
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$weekday $displayHour:$minute $period';
  }

  Widget _buildMessageStatusIcon(ChatMessage message) {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              mediumSeaGreen.withValues(alpha: 0.7),
            ),
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check_rounded,
          size: 14,
          color: mediumSeaGreen.withValues(alpha: 0.7),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: mediumSeaGreen.withValues(alpha: 0.7),
        );
      case MessageStatus.seen:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: mediumSeaGreen,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Colors.red.withValues(alpha: 0.7),
        );
    }
  }



  Widget _buildTypingIndicator() {
    if (!_isOtherUserTyping) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [mediumSeaGreen, Color(0xFF2E7D4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                widget.applicantName.isNotEmpty 
                    ? widget.applicantName[0].toUpperCase()
                    : 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: applicantBubbleColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_otherUserTypingName ?? 'Someone'} is typing',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(3, (index) => Padding(
                    padding: EdgeInsets.only(right: index < 2 ? 2 : 0),
                    child: _buildTypingDot(index),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCalendarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: darkTeal.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Calendar Options',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildCalendarOption(
              'Schedule Meeting',
              Icons.video_call_rounded,
              'Schedule a meeting with this applicant',
              () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/schedule-meeting', arguments: {
                  'applicantId': widget.applicantId,
                  'applicantName': widget.applicantName,
                  'jobTitle': widget.jobTitle,
                });
              },
            ),
            _buildCalendarOption(
              'View Calendar',
              Icons.calendar_today_rounded,
              'View your calendar and availability',
              () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/employer-calendar');
              },
            ),
            _buildCalendarOption(
              'Set Availability',
              Icons.schedule_rounded,
              'Manage your availability settings',
              () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/availability-settings');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarOption(String title, IconData icon, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: mediumSeaGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: mediumSeaGreen,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: darkTeal,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: darkTeal.withValues(alpha: 0.7),
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
  }
}