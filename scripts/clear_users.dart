import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../lib/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    print('Starting database cleanup...');

    // Clear Firestore users collection
    print('Clearing Firestore users collection...');
    final QuerySnapshot usersSnapshot = 
        await FirebaseFirestore.instance.collection('users').get();
    
    for (var doc in usersSnapshot.docs) {
      print('Deleting user document: ${doc.id}');
      await doc.reference.delete();
    }
    print('Firestore users collection cleared');

    // Clear user avatars from Storage
    print('Clearing user avatars from Storage...');
    final ListResult result = await FirebaseStorage.instance
        .ref()
        .child('user_avatars')
        .listAll();
    
    for (var item in result.items) {
      print('Deleting avatar: ${item.name}');
      await item.delete();
    }
    print('User avatars cleared');

    print('Database cleanup completed successfully');
  } catch (e) {
    print('Error during cleanup: $e');
  }
} 