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

async function clearCollection(collectionPath: string) {
  console.log(`Clearing collection: ${collectionPath}...`);
  const snapshot = await db.collection(collectionPath).get();
  
  const deletePromises = snapshot.docs.map(async (doc) => {
    // Delete subcollections first
    const subcollections = await doc.ref.listCollections();
    for (const subcollection of subcollections) {
      await clearCollection(`${collectionPath}/${doc.id}/${subcollection.id}`);
    }
    // Then delete the document
    await doc.ref.delete();
    console.log(`Deleted document: ${doc.id} from ${collectionPath}`);
  });

  await Promise.all(deletePromises);
  console.log(`Finished clearing ${collectionPath}`);
}

async function clearAllCollections() {
  try {
    console.log('Starting database cleanup...');

    // Clear all main collections
    await Promise.all([
      clearCollection('conversations'),
      clearCollection('users'),
      clearCollection('videos'),
      clearCollection('stories'),
    ]);

    // Clear Firebase Authentication users
    console.log('Clearing Firebase Authentication users...');
    const listUsersResult = await auth.listUsers();
    const deleteAuthPromises = listUsersResult.users.map(async (userRecord) => {
      console.log('Deleting auth user:', userRecord.uid);
      await auth.deleteUser(userRecord.uid);
    });
    await Promise.all(deleteAuthPromises);
    console.log('Firebase Authentication users cleared');

    // Clear Storage
    try {
      console.log('Clearing files from Storage...');
      const bucket = storage.bucket();
      const [files] = await bucket.getFiles();
      
      if (files.length > 0) {
        const deleteFilePromises = files.map(async (file) => {
          console.log('Deleting file:', file.name);
          await file.delete();
        });
        await Promise.all(deleteFilePromises);
        console.log('Storage files cleared');
      } else {
        console.log('No files found in Storage');
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

clearAllCollections(); 