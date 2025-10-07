import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

enum MessageStatus {
  sending,
  sent,
  delivered,
  seen,
  failed
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String messageType;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final bool isRead;
  final String? replyToId;
  final String? senderName;
  final String? senderAvatar;
  // Enhanced status tracking
  final MessageStatus status;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? seenAt;
  final DateTime? failedAt;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.messageType,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    required this.isRead,
    this.replyToId,
    this.senderName,
    this.senderAvatar,
    this.status = MessageStatus.sending,
    this.sentAt,
    this.deliveredAt,
    this.seenAt,
    this.failedAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      chatId: map['chat_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      content: map['content'] ?? '',
      messageType: map['message_type'] ?? 'text',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      editedAt: map['edited_at'] != null ? DateTime.parse(map['edited_at']) : null,
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      isRead: map['is_read'] ?? false,
      replyToId: map['reply_to_id'],
      senderName: map['sender_name'],
      senderAvatar: map['sender_avatar'],
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['message_status'] ?? map['status'] ?? 'sending'),
        orElse: () => MessageStatus.sending,
      ),
      sentAt: map['sent_at'] != null ? DateTime.parse(map['sent_at']) : null,
      deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at']) : null,
      seenAt: map['seen_at'] != null ? DateTime.parse(map['seen_at']) : null,
      failedAt: map['failed_at'] != null ? DateTime.parse(map['failed_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'created_at': createdAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_read': isRead,
      'reply_to_id': replyToId,
      'message_status': status.name,
      'sent_at': sentAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'seen_at': seenAt?.toIso8601String(),
      'failed_at': failedAt?.toIso8601String(),
    };
  }
}

class ChatRoom {
  final String id;
  final String? jobId;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessageId;
  final bool isActive;
  final List<ChatMember> members;
  final String? jobTitle;
  final String? companyName;
  final Map<String, dynamic>? lastMessage;
  final int unreadCount;

  ChatRoom({
    required this.id,
    this.jobId,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessageId,
    required this.isActive,
    required this.members,
    this.jobTitle,
    this.companyName,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['id'] ?? '',
      jobId: map['job_id'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      lastMessageAt: map['last_message_at'] != null 
          ? DateTime.parse(map['last_message_at']) 
          : null,
      lastMessageId: map['last_message_id'],
      isActive: map['is_active'] ?? true,
      members: (map['members'] as List<dynamic>? ?? [])
          .map((m) => ChatMember.fromMap(m))
          .toList(),
      jobTitle: map['job_title'],
      companyName: map['company_name'],
      lastMessage: map['last_message'],
      unreadCount: map['unread_count'] ?? 0,
    );
  }
}

class ChatMember {
  final String chatId;
  final String userId;
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final bool isActive;
  final String? userName;
  final String? userAvatar;
  final String? userRole;

  ChatMember({
    required this.chatId,
    required this.userId,
    required this.joinedAt,
    required this.lastReadAt,
    required this.isActive,
    this.userName,
    this.userAvatar,
    this.userRole,
  });

  factory ChatMember.fromMap(Map<String, dynamic> map) {
    return ChatMember(
      chatId: map['chat_id'] ?? '',
      userId: map['user_id'] ?? '',
      joinedAt: DateTime.parse(map['joined_at'] ?? DateTime.now().toIso8601String()),
      lastReadAt: DateTime.parse(map['last_read_at'] ?? DateTime.now().toIso8601String()),
      isActive: map['is_active'] ?? true,
      userName: map['profiles']?['full_name'] ?? map['user_name'],
      userAvatar: map['profiles']?['avatar_url'] ?? map['user_avatar'],
      userRole: map['profiles']?['role'] ?? map['user_role'],
    );
  }
}

class ChatService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static RealtimeChannel? _messageChannel;
  static RealtimeChannel? _typingChannel;
  static Timer? _typingTimer;

  // Create or get chat between employer and applicant
  static Future<String> createOrGetChat({
    required String jobId,
    required String employerId,
    required String applicantId,
  }) async {
    try {
      final response = await _supabase.rpc('create_or_get_chat', params: {
        'p_job_id': jobId,
        'p_employer_id': employerId,
        'p_applicant_id': applicantId,
      });
      
      return response.toString();
    } catch (e) {
      debugPrint('Error creating/getting chat: $e');
      rethrow;
    }
  }

  // Get user's chat rooms with last message and unread count
  static Future<List<ChatRoom>> getUserChats(String userId) async {
    try {
      // Use the optimized stored procedure
      final response = await _supabase.rpc('get_user_chats', params: {
        'user_uuid': userId,
      });

      final List<ChatRoom> chats = [];
      for (final chatData in response as List) {
        // Create members list with current user and other member
        final members = [
          {
            'user_id': userId,
            'chat_id': chatData['chat_id'],
            'joined_at': chatData['chat_created_at'],
            'last_read_at': chatData['user_last_read_at'],
            'is_active': true,
            'profiles': {
              'id': userId,
              'full_name': 'Current User', // This will be overridden by actual profile data
              'avatar_url': null,
              'role': 'applicant', // This will be overridden by actual profile data
            },
          },
          {
            'user_id': chatData['other_member_id'],
            'chat_id': chatData['chat_id'],
            'joined_at': chatData['chat_created_at'],
            'last_read_at': chatData['user_last_read_at'],
            'is_active': true,
            'profiles': {
              'id': chatData['other_member_id'],
              'full_name': chatData['other_member_name'],
              'avatar_url': chatData['other_member_avatar_url'],
              'role': chatData['other_member_role'],
            },
          },
        ];

        // Create last message data if exists
        Map<String, dynamic>? lastMessage;
        if (chatData['last_message_id'] != null) {
          lastMessage = {
            'id': chatData['last_message_id'],
            'content': chatData['last_message_content'],
            'sender_id': chatData['last_message_sender_id'],
            'created_at': chatData['last_message_created_at'],
            'profiles': {
              'full_name': chatData['last_message_sender_name'],
              'avatar_url': null,
            },
          };
        }

        chats.add(ChatRoom.fromMap({
          'id': chatData['chat_id'],
          'job_id': chatData['job_id'],
          'created_at': chatData['chat_created_at'],
          'last_message_at': chatData['last_message_at'],
          'is_active': true,
          'members': members,
          'job_title': chatData['job_title'],
          'company_name': chatData['company_name'],
          'last_message': lastMessage,
          'unread_count': (chatData['unread_count'] as num).toInt(), // Convert BIGINT to int
        }));
      }

      return chats;
    } catch (e) {
      debugPrint('Error fetching user chats: $e');
      return [];
    }
  }

  // Get chat messages with lazy loading support
  static Future<List<ChatMessage>> getChatMessages(
    String chatId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Use the optimized stored procedure
      final response = await _supabase.rpc('get_chat_messages', params: {
        'chat_uuid': chatId,
        'limit_count': limit,
        'offset_count': offset,
      });

      final messages = (response as List)
          .map((message) => ChatMessage.fromMap(message))
          .toList();

      return messages;
    } catch (e) {
      debugPrint('Error in ChatService.getChatMessages: $e');
      return [];
    }
  }

  // Get initial messages (most recent)
  static Future<List<ChatMessage>> getInitialMessages(String chatId) async {
    return getChatMessages(chatId, limit: 20);
  }

  // Load more messages (for pagination) - simplified version
  static Future<List<ChatMessage>> loadMoreMessages(
    String chatId, 
    int currentCount,
  ) async {
    return getChatMessages(chatId, limit: 20, offset: currentCount);
  }

  // Send message with enhanced status tracking
  static Future<String> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? replyToId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create message with sending status
      final messageResponse = await _supabase
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': user.id,
            'content': content,
            'message_type': messageType,
            'reply_to_id': replyToId,
            'status': 'sending',
            'message_status': 'sending',
            'sent_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final messageId = messageResponse['id'] as String;
      debugPrint('Message created with ID: $messageId');

      // Update status to sent immediately
      await _supabase
          .from('messages')
          .update({
            'status': 'sent',
            'message_status': 'sent',
            'sent_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
      
      debugPrint('Message status updated to sent');

      // Simulate delivery after a short delay (like real messaging apps)
      Timer(const Duration(milliseconds: 500), () async {
        try {
          await _supabase
              .from('messages')
              .update({
                'status': 'delivered',
                'message_status': 'delivered',
                'delivered_at': DateTime.now().toIso8601String(),
              })
              .eq('id', messageId);
          
          debugPrint('Message status updated to delivered');
        } catch (e) {
          debugPrint('Error updating to delivered status: $e');
        }
      });

      return messageId;
    } catch (e) {
      debugPrint('Error sending message: $e');
      
      // Mark message as failed if it exists
      try {
        await _supabase
            .from('messages')
            .update({
              'status': 'failed',
              'message_status': 'failed',
              'failed_at': DateTime.now().toIso8601String(),
            })
            .eq('content', content)
            .eq('chat_id', chatId)
            .order('created_at', ascending: false)
            .limit(1);
      } catch (updateError) {
        debugPrint('Error updating failed message: $updateError');
      }
      
      rethrow;
    }
  }

  // Mark messages as read and update seen status
  static Future<void> markMessagesAsRead(String chatId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Update chat members last_read_at
      await _supabase.rpc('mark_chat_messages_read', params: {
        'chat_uuid': chatId,
        'user_uuid': user.id,
      });

      // Update message seen status for messages not sent by current user
      await _supabase
          .from('messages')
          .update({
            'status': 'seen',
            'message_status': 'seen',
            'seen_at': DateTime.now().toIso8601String(),
          })
          .eq('chat_id', chatId)
          .neq('sender_id', user.id)
          .eq('message_status', 'delivered');

      // Update sender's message status progression
      // When recipient sees "sent" messages, update sender's messages to "delivered"
      await _supabase
          .from('messages')
          .update({
            'status': 'delivered',
            'message_status': 'delivered',
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('chat_id', chatId)
          .eq('sender_id', user.id)
          .eq('message_status', 'sent');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Typing indicators functionality
  static Future<void> startTyping(String chatId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('typing_indicators')
          .upsert({
            'chat_id': chatId,
            'user_id': user.id,
            'is_typing': true,
            'last_activity': DateTime.now().toIso8601String(),
          });

      // Set timer to stop typing after 3 seconds of inactivity
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        stopTyping(chatId);
      });
    } catch (e) {
      debugPrint('Error starting typing: $e');
    }
  }

  static Future<void> stopTyping(String chatId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('typing_indicators')
          .update({
            'is_typing': false,
            'last_activity': DateTime.now().toIso8601String(),
          })
          .eq('chat_id', chatId)
          .eq('user_id', user.id);

      _typingTimer?.cancel();
    } catch (e) {
      debugPrint('Error stopping typing: $e');
    }
  }

  // Subscribe to typing indicators
  static void subscribeToTypingIndicators(
    String chatId,
    Function(Map<String, dynamic>) onTypingChange,
  ) {
    _typingChannel?.unsubscribe();
    
    _typingChannel = _supabase
        .channel('typing:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_indicators',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            try {
              final typingData = payload.newRecord;
              onTypingChange(typingData);
            } catch (e) {
              debugPrint('Error processing typing indicator: $e');
            }
          },
        )
        .subscribe();
  }

  // Unsubscribe from typing indicators
  static void unsubscribeFromTypingIndicators() {
    _typingChannel?.unsubscribe();
    _typingChannel = null;
    _typingTimer?.cancel();
  }

  // Subscribe to real-time messages
  static void subscribeToMessages(String chatId, Function(ChatMessage) onNewMessage) {
    // Unsubscribe from previous channel
    _messageChannel?.unsubscribe();
    
    _messageChannel = _supabase
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) async {
            try {
              final messageData = payload.newRecord;
              
              // Fetch sender profile data for the new message
              final senderId = messageData['sender_id'] as String;
              final profileResponse = await _supabase
                  .from('profiles')
                  .select('id, full_name, avatar_url')
                  .eq('id', senderId)
                  .maybeSingle();
              
              final message = ChatMessage.fromMap({
                ...messageData,
                'sender_name': profileResponse?['full_name'],
                'sender_avatar': profileResponse?['avatar_url'],
              });
              
              debugPrint('Real-time message received - ID: ${message.id}, Status: ${message.status.name}');
              onNewMessage(message);
            } catch (e) {
              debugPrint('Error processing real-time message: $e');
              // Fallback: create message without profile data
              try {
                final messageData = payload.newRecord;
                final message = ChatMessage.fromMap({
                  ...messageData,
                  'sender_name': 'Unknown',
                  'sender_avatar': null,
                });
                onNewMessage(message);
              } catch (fallbackError) {
                debugPrint('Error in fallback message processing: $fallbackError');
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) async {
            try {
              final messageData = payload.newRecord;
              
              // Fetch sender profile data for the updated message
              final senderId = messageData['sender_id'] as String;
              final profileResponse = await _supabase
                  .from('profiles')
                  .select('id, full_name, avatar_url')
                  .eq('id', senderId)
                  .maybeSingle();
              
              final message = ChatMessage.fromMap({
                ...messageData,
                'sender_name': profileResponse?['full_name'],
                'sender_avatar': profileResponse?['avatar_url'],
              });
              
              debugPrint('Real-time message update received - ID: ${message.id}, Status: ${message.status.name}');
              onNewMessage(message);
            } catch (e) {
              debugPrint('Error processing real-time message update: $e');
            }
          },
        )
        .subscribe();
  }

  // Unsubscribe from real-time messages
  static void unsubscribeFromMessages() {
    _messageChannel?.unsubscribe();
    _messageChannel = null;
    unsubscribeFromTypingIndicators();
  }

  // Get unread message count for a user
  static Future<int> getUnreadMessageCount(String userId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .inFilter('chat_id', await _getUserChatIds(userId))
          .neq('sender_id', userId)
          .eq('is_read', false)
          .filter('deleted_at', 'is', null);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting unread message count: $e');
      return 0;
    }
  }

  // Helper method to get user's chat IDs
  static Future<List<String>> _getUserChatIds(String userId) async {
    try {
      final response = await _supabase
          .from('chat_members')
          .select('chat_id')
          .eq('user_id', userId)
          .eq('is_active', true);

      return (response as List)
          .map((member) => member['chat_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting user chat IDs: $e');
      return [];
    }
  }

  // Delete message (soft delete)
  static Future<void> deleteMessage(String messageId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('messages')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', messageId)
          .eq('sender_id', user.id);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  // Edit message
  static Future<void> editMessage(String messageId, String newContent) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('messages')
          .update({
            'content': newContent,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('sender_id', user.id);
    } catch (e) {
      debugPrint('Error editing message: $e');
      rethrow;
    }
  }
}
