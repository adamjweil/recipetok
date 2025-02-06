import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get or create a conversation between two users
  Future<String> getOrCreateConversation(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Sort user IDs to ensure consistent conversation ID
    final sortedUserIds = [currentUserId, otherUserId]..sort();
    final conversationId = sortedUserIds.join('_');

    final conversationDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (!conversationDoc.exists) {
      // Create new conversation
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': sortedUserIds,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
      });
    }

    return conversationId;
  }

  // Send a message
  Future<void> sendMessage(String conversationId, String message) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    
    // Get conversation to find other participant
    final conversation = await conversationRef.get();
    final participants = List<String>.from(conversation.data()?['participants'] ?? []);
    final otherUserId = participants.firstWhere((id) => id != currentUserId);

    // Add message to conversation
    await conversationRef.collection('messages').add({
      'text': message,
      'senderId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Update conversation metadata
    await conversationRef.update({
      'lastMessage': message,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
    });

    // Increment unread count for other user
    await _firestore
        .collection('users')
        .doc(otherUserId)
        .collection('unreadMessages')
        .doc(conversationId)
        .set({
          'count': FieldValue.increment(1),
        }, SetOptions(merge: true));
  }

  // Mark messages as read
  Future<void> markConversationAsRead(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Mark all messages as read
    final messagesQuery = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesQuery.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();

    // Reset unread count
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('unreadMessages')
        .doc(conversationId)
        .delete();
  }

  // Get user's conversations
  Stream<List<Map<String, dynamic>>> getConversations() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('DEBUG: User not authenticated');
      throw Exception('Not authenticated');
    }
    print('DEBUG: Fetching conversations for user: $currentUserId');

    // Split the query into two parts for debugging
    final Query conversationsQuery = _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId);
    
    print('DEBUG: Basic query created');

    final Query orderedQuery = conversationsQuery
        .orderBy('lastMessageTimestamp', descending: true);
    
    print('DEBUG: Ordered query created');

    return orderedQuery
        .snapshots()
        .handleError((error) {
          print('DEBUG: Error in conversations query: $error');
          // Rethrow to maintain stream error handling
          throw error;
        })
        .asyncMap((snapshot) async {
          print('DEBUG: Got ${snapshot.docs.length} conversations');
          final conversations = <Map<String, dynamic>>[];
          
          for (var doc in snapshot.docs) {
            print('DEBUG: Processing conversation: ${doc.id}');
            // Cast the data to Map<String, dynamic>
            final data = doc.data() as Map<String, dynamic>;
            
            // Safely cast participants to List<String>
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );
            print('DEBUG: Other user ID: $otherUserId');

            try {
              // Get other user's data
              final otherUserDoc = await _firestore
                  .collection('users')
                  .doc(otherUserId)
                  .get();
              print('DEBUG: Got other user data: ${otherUserDoc.exists}');

              final otherUserData = otherUserDoc.data() ?? {};

              // Get unread count
              final unreadDoc = await _firestore
                  .collection('users')
                  .doc(currentUserId)
                  .collection('unreadMessages')
                  .doc(doc.id)
                  .get();
              print('DEBUG: Got unread count doc: ${unreadDoc.exists}');

              // Safely handle the timestamp
              final timestamp = data['lastMessageTimestamp'] as Timestamp?;
              
              conversations.add({
                'conversationId': doc.id,
                'userId': otherUserId,
                'username': otherUserData['username'] ?? '',
                'displayName': otherUserData['displayName'] ?? '',
                'avatarUrl': otherUserData['avatarUrl'],
                'lastMessage': data['lastMessage'] ?? '',
                'lastMessageTimestamp': timestamp?.toDate() ?? DateTime.now(),
                'unread': (unreadDoc.data()?['count'] as int? ?? 0) > 0,
              });
            } catch (e) {
              print('DEBUG: Error processing conversation: $e');
            }
          }
          return conversations;
        });
  }

  // Get total unread message count
  Stream<int> getTotalUnreadCount() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('unreadMessages')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.fold<int>(
            0,
            (sum, doc) => sum + (doc.data()['count'] as int? ?? 0),
          );
        });
  }

  // Add this method to MessageService
  Future<void> debugCheckConversations() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('DEBUG: No current user');
      return;
    }

    try {
      print('DEBUG: Starting conversation check for user: $currentUserId');
      
      // First try to get all conversations
      final conversationsRef = _firestore.collection('conversations');
      print('DEBUG: Attempting to query conversations collection');
      
      // Try getting conversations where user is a participant
      final query = conversationsRef.where('participants', arrayContains: currentUserId);
      print('DEBUG: Created query with participant filter');
      
      final snapshot = await query.get();
      print('DEBUG: Successfully got conversations snapshot');
      print('DEBUG: Total conversations in DB: ${snapshot.docs.length}');
      
      for (var doc in snapshot.docs) {
        print('DEBUG: Conversation ${doc.id}:');
        print('DEBUG: Participants: ${(doc.data()['participants'] as List?)?.join(', ')}');
        print('DEBUG: Last message: ${doc.data()['lastMessage']}');
        print('DEBUG: Last message timestamp: ${doc.data()['lastMessageTimestamp']}');
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error checking conversations:');
      print('DEBUG: Error message: $e');
      print('DEBUG: Stack trace: $stackTrace');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Get a reference to the conversation
    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    
    // Start a batch write
    final batch = _firestore.batch();

    // Delete all messages in the conversation
    final messagesSnapshot = await conversationRef
        .collection('messages')
        .get();
    
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the conversation document
    batch.delete(conversationRef);

    // Delete unread messages counter
    final unreadRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('unreadMessages')
        .doc(conversationId);
    
    batch.delete(unreadRef);

    // Commit the batch
    await batch.commit();
  }
} 