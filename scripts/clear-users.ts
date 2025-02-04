import * as admin from 'firebase-admin';
import * as serviceAccount from './serviceAccountKey.json';

// Initialize Firebase Admin with storage bucket
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
  storageBucket: "recipetok-acc07.appspot.com"
});

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

async function clearAllUsers() {
  try {
    console.log('Starting database cleanup...');

    // Clear Firebase Authentication users
    console.log('Clearing Firebase Authentication users...');
    const listUsersResult = await auth.listUsers();
    const deleteAuthPromises = listUsersResult.users.map(async (userRecord) => {
      console.log('Deleting auth user:', userRecord.uid);
      await auth.deleteUser(userRecord.uid);
    });
    await Promise.all(deleteAuthPromises);
    console.log('Firebase Authentication users cleared');

    // Clear Firestore users collection
    console.log('Clearing Firestore users collection...');
    const usersSnapshot = await db.collection('users').get();
    const deletePromises = usersSnapshot.docs.map(async (doc) => {
      console.log('Deleting user document:', doc.id);
      await doc.ref.delete();
    });
    await Promise.all(deletePromises);
    console.log('Firestore users collection cleared');

    // Try to clear Storage, but don't fail if bucket doesn't exist
    try {
      console.log('Clearing user avatars from Storage...');
      const bucket = storage.bucket();
      const [files] = await bucket.getFiles({ prefix: 'user_avatars/' });
      
      if (files.length > 0) {
        const deleteFilePromises = files.map(async (file) => {
          console.log('Deleting avatar:', file.name);
          await file.delete();
        });
        await Promise.all(deleteFilePromises);
        console.log('User avatars cleared');
      } else {
        console.log('No user avatars found to clear');
      }
    } catch (error: any) {
      console.warn('Storage cleanup failed (this is OK if Storage is not initialized):', error.message);
    }

    console.log('Database cleanup completed successfully');
    process.exit(0);
  } catch (error: any) {
    console.error('Error during cleanup:', error);
    process.exit(1);
  }
}

clearAllUsers(); 