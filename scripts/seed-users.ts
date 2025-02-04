import * as admin from 'firebase-admin';
import * as serviceAccount from './serviceAccountKey.json';
import { faker } from '@faker-js/faker';

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
  storageBucket: "recipetok-acc07.appspot.com"
});

const db = admin.firestore();
const auth = admin.auth();

const sampleVideos = [
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
  },
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg',
  },
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg',
  },
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg',
  },
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMeltdowns.jpg',
  },
];

async function createUser() {
  const firstName = faker.person.firstName();
  const lastName = faker.person.lastName();
  const email = faker.internet.email({ firstName, lastName });
  const password = 'password123';
  const displayName = `${firstName} ${lastName}`;
  const username = faker.internet.userName({ firstName, lastName });

  try {
    // Create auth user
    const userRecord = await auth.createUser({
      email,
      password,
      displayName,
      photoURL: faker.image.avatar(),
    });

    // Create user document in Firestore
    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email,
      displayName,
      username,
      bio: faker.lorem.sentence(),
      avatarUrl: faker.image.avatar(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      followers: [],
      following: [],
      videoCount: 0,
    });

    return userRecord.uid;
  } catch (error) {
    console.error('Error creating user:', error);
    throw error;
  }
}

async function createVideo(userId: string) {
  const randomVideo = sampleVideos[Math.floor(Math.random() * sampleVideos.length)];
  
  try {
    const videoDoc = await db.collection('videos').add({
      userId,
      videoUrl: randomVideo.videoUrl,
      thumbnailUrl: randomVideo.thumbnailUrl,
      title: faker.lorem.words(3),
      description: faker.lorem.sentence(),
      ingredients: Array.from({ length: 3 }, () => faker.lorem.word()),
      instructions: Array.from({ length: 3 }, () => faker.lorem.sentence()),
      likes: 0,
      views: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update the user's videoCount
    await db.collection('users').doc(userId).update({
      videoCount: admin.firestore.FieldValue.increment(1),
    });

    console.log(`Created video with thumbnail: ${randomVideo.thumbnailUrl}`);
    return videoDoc.id;
  } catch (error) {
    console.error('Error creating video:', error);
    throw error;
  }
}

async function createRandomConnections(userIds: string[]) {
  console.log('Creating random follow connections between users...');
  
  for (const userId of userIds) {
    // Randomly follow 1-3 other users
    const numToFollow = Math.floor(Math.random() * 3) + 1;
    const otherUsers = userIds.filter(id => id !== userId);
    
    // Shuffle and take first n users
    const usersToFollow = otherUsers
      .sort(() => Math.random() - 0.5)
      .slice(0, numToFollow);
    
    for (const targetId of usersToFollow) {
      await db.collection('users').doc(userId).update({
        following: admin.firestore.FieldValue.arrayUnion(targetId)
      });
      
      await db.collection('users').doc(targetId).update({
        followers: admin.firestore.FieldValue.arrayUnion(userId)
      });
      
      console.log(`User ${userId} is now following ${targetId}`);
    }
  }
}

async function seedDatabase() {
  try {
    // First create your specific user
    const adamUser = {
      email: 'adamjweil@gmail.com',
      password: 'password',
      displayName: 'Adam Weil',
      username: 'adam',
      bio: 'Food enthusiast and home chef',
      avatarUrl: faker.image.avatar(),
    };

    const createdUserIds: string[] = [];

    // Create auth user for Adam
    try {
      const adamUserRecord = await auth.createUser({
        email: adamUser.email,
        password: adamUser.password,
        displayName: adamUser.displayName,
        photoURL: adamUser.avatarUrl,
      });

      // Create user document in Firestore
      await db.collection('users').doc(adamUserRecord.uid).set({
        uid: adamUserRecord.uid,
        email: adamUser.email,
        displayName: adamUser.displayName,
        username: adamUser.username,
        bio: adamUser.bio,
        avatarUrl: adamUser.avatarUrl,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        followers: [],
        following: [],
        videoCount: 0,
      });

      createdUserIds.push(adamUserRecord.uid); // Add Adam's ID to the array
      console.log(`Created specific user: ${adamUserRecord.uid}`);

      // Create 3 specific videos for Adam
      const adamVideos = [
        {
          title: 'Perfect Homemade Pizza',
          description: 'Learn how to make restaurant-quality pizza at home',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/pizza/300/300',
          ingredients: ['Pizza dough', 'Tomato sauce', 'Mozzarella', 'Fresh basil'],
          instructions: ['Prepare the dough', 'Add toppings', 'Bake at high heat'],
        },
        {
          title: 'Classic Pasta Carbonara',
          description: 'Authentic Italian carbonara recipe',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/pasta/300/300',
          ingredients: ['Spaghetti', 'Eggs', 'Pecorino Romano', 'Guanciale'],
          instructions: ['Cook pasta', 'Prepare sauce', 'Combine and serve'],
        },
        {
          title: 'Ultimate Burger Guide',
          description: 'How to make the perfect burger',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/burger/300/300',
          ingredients: ['Ground beef', 'Burger buns', 'Lettuce', 'Tomato'],
          instructions: ['Form patties', 'Season well', 'Grill to perfection'],
        },
      ];

      for (const videoData of adamVideos) {
        const videoDoc = await db.collection('videos').add({
          userId: adamUserRecord.uid,
          ...videoData,
          likes: 0,
          views: 0,
          comments: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Created video for Adam: ${videoDoc.id}`);
      }

      // Add this after the videos loop
      await db.collection('users').doc(adamUserRecord.uid).update({
        videoCount: adamVideos.length,
      });
    } catch (error) {
      console.error('Error creating Adam\'s account:', error);
      // Continue with creating other users even if Adam's account creation fails
    }

    // Create random users
    for (let i = 0; i < 10; i++) {
      const userId = await createUser();
      createdUserIds.push(userId);
      console.log(`Created user ${i + 1}/10 with ID: ${userId}`);

      // Create 1-2 videos for each user
      const numVideos = Math.random() < 0.5 ? 1 : 2;
      for (let j = 0; j < numVideos; j++) {
        const videoId = await createVideo(userId);
        console.log(`Created video ${j + 1}/${numVideos} for user ${userId}: ${videoId}`);
      }
    }

    // Create random follow connections between users
    await createRandomConnections(createdUserIds);

    console.log('Database seeding completed successfully');
    process.exit(0);
  } catch (error) {
    console.error('Error during seeding:', error);
    process.exit(1);
  }
}

seedDatabase(); 