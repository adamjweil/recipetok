import * as admin from 'firebase-admin';
import * as serviceAccount from './serviceAccountKey.json';
import { faker } from '@faker-js/faker';
import * as fs from 'fs';
import * as path from 'path';

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
  storageBucket: "recipetok-acc07.firebasestorage.app"
});

const db = admin.firestore();
const auth = admin.auth();
const bucket = admin.storage().bucket();

async function getSignedUrl(filePath: string) {
  const file = bucket.file(filePath);
  const [signedUrl] = await file.getSignedUrl({
    action: 'read',
    expires: '2100-01-01'
  });
  return signedUrl;
}

async function getSampleVideos() {
  // Helper function to get signed URL
  async function getVideoSignedUrl(sampleNumber: number) {
    const file = bucket.file(`videos/sample${sampleNumber}/playlist.m3u8`);
    const [signedUrl] = await file.getSignedUrl({
      action: 'read',
      expires: '2100-01-01'
    });
    return signedUrl;
  }

  return Promise.all([1, 2, 3, 4, 5].map(async (num) => ({
    videoUrl: await getVideoSignedUrl(num),
    mp4Fallback: `https://storage.googleapis.com/gtv-videos-bucket/sample/${
      num === 1 ? 'ForBiggerBlazes' :
      num === 2 ? 'ForBiggerEscapes' :
      num === 3 ? 'ForBiggerFun' :
      num === 4 ? 'ForBiggerJoyrides' :
      'ForBiggerMeltdowns'
    }.mp4`,
    thumbnailUrl: `https://storage.googleapis.com/gtv-videos-bucket/sample/images/${
      num === 1 ? 'ForBiggerBlazes' :
      num === 2 ? 'ForBiggerEscapes' :
      num === 3 ? 'ForBiggerFun' :
      num === 4 ? 'ForBiggerJoyrides' :
      'ForBiggerMeltdowns'
    }.jpg`,
    qualities: ['720p', '480p']
  })));
}

// Add these arrays at the top of the file
const recipeTitles = [
  'Easy Homemade Pasta',
  'Perfect Chocolate Cake',
  'Crispy Fried Chicken',
  '30-Minute Stir Fry',
  'Classic Apple Pie',
  'Creamy Mac and Cheese',
  'Best Breakfast Pancakes',
  'Healthy Quinoa Bowl',
  'Spicy Thai Curry',
  'Fresh Garden Salad',
  'Grilled Salmon',
  'Homemade Pizza Dough',
  'Beef Stroganoff',
  'Vegetable Lasagna',
  'French Onion Soup'
];

const recipeDescriptions = [
  'Quick and easy recipe perfect for weeknight dinners',
  'A family favorite that never disappoints',
  'Restaurant-quality dish you can make at home',
  'Healthy and delicious meal prep option',
  'Traditional recipe with a modern twist',
  'Perfect comfort food for any occasion',
  'Budget-friendly meal the whole family will love',
  'Impressive dish that\'s surprisingly simple to make',
  'Classic recipe passed down through generations',
  'Ready in under 30 minutes!'
];

const commonIngredients = [
  'olive oil',
  'garlic',
  'onion',
  'salt',
  'black pepper',
  'butter',
  'eggs',
  'flour',
  'milk',
  'chicken breast',
  'pasta',
  'rice',
  'tomatoes',
  'cheese',
  'herbs'
];

const cookingInstructions = [
  'Preheat the oven to 350°F (175°C)',
  'Chop all vegetables finely',
  'Mix dry ingredients in a large bowl',
  'Heat oil in a large skillet over medium heat',
  'Season with salt and pepper to taste',
  'Cook until golden brown',
  'Simmer for 20 minutes',
  'Let rest for 5 minutes before serving',
  'Garnish with fresh herbs',
  'Serve hot and enjoy!'
];

// Add this near the top of the file with other constants
const adamCollections = [
  {
    name: 'Pizza',
    description: 'My favorite pizza recipes',
    imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRevNsmPB3e-9h1eS48vt2dRJSi32eGw9eWFw&s',
    videos: {},
  },
  {
    name: 'Burgers',
    description: 'Best burger recipes',
    imageUrl: 'https://plus.unsplash.com/premium_photo-1683619761468-b06992704398?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NXx8YnVyZ2VyJTIwcG5nfGVufDB8fDB8fHww',
    videos: {},
  },
  {
    name: 'Donuts',
    description: 'Sweet donut recipes',
    imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT9za753NZ8JZfpdMxdGvYIMyFYsQJ6FgexIpuhhZx7fE7mQ8zNxLZogwUehpjdULMX85M&usqp=CAU',
    videos: {},
  },
];

// Add this after other sample data arrays
const sampleMessages = [
  "Hey, loved your latest recipe!",
  "Could you share more details about the ingredients?",
  "Thanks for the cooking tips!",
  "Your videos are so helpful",
  "What temperature do you recommend?",
  "I tried this recipe, it was amazing!",
  "How long should I cook it for?",
  "Where do you get your ingredients?",
  "Great presentation!",
  "Can I substitute any ingredients?"
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

async function createVideo(userId: string, videos: any[]) {
  const randomVideo = videos[Math.floor(Math.random() * videos.length)];
  
  // Get 3-5 random ingredients
  const numIngredients = Math.floor(Math.random() * 3) + 3;
  const ingredients = Array.from({ length: numIngredients }, () => {
    const randomIndex = Math.floor(Math.random() * commonIngredients.length);
    return commonIngredients[randomIndex];
  });

  // Get 3-5 random instructions
  const numInstructions = Math.floor(Math.random() * 3) + 3;
  const instructions = Array.from({ length: numInstructions }, () => {
    const randomIndex = Math.floor(Math.random() * cookingInstructions.length);
    return cookingInstructions[randomIndex];
  });

  try {
    const videoDoc = await db.collection('videos').add({
      userId,
      videoUrl: randomVideo.videoUrl,
      mp4Fallback: randomVideo.mp4Fallback,
      qualities: randomVideo.qualities,
      format: 'hls',
      thumbnailUrl: randomVideo.thumbnailUrl,
      title: recipeTitles[Math.floor(Math.random() * recipeTitles.length)],
      description: recipeDescriptions[Math.floor(Math.random() * recipeDescriptions.length)],
      ingredients,
      instructions,
      likes: [],
      views: 0,
      commentCount: 0,
      isPinned: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update the user's videoCount
    await db.collection('users').doc(userId).update({
      videoCount: admin.firestore.FieldValue.increment(1),
    });

    console.log(`Created recipe video: ${videoDoc.id}`);
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

// Add this function to create collections
async function createAdamCollections(userId: string, adamVideos: any[]) {
  console.log('Creating collections for Adam...');
  
  for (const collection of adamCollections) {
    const groupRef = await db.collection('users').doc(userId).collection('groups').add({
      name: collection.name,
      description: collection.description,
      imageUrl: collection.imageUrl,
      videos: {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    if (collection.name === 'Pizza' && adamVideos[0]) {
      await groupRef.update({
        [`videos.${adamVideos[0].id}`]: {
          addedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    } else if (collection.name === 'Burgers' && adamVideos[2]) {
      await groupRef.update({
        [`videos.${adamVideos[2].id}`]: {
          addedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    }
    
    console.log(`Created ${collection.name} collection: ${groupRef.id}`);
  }
}

// Add this function after createAdamCollections
async function createConversations(adamId: string, otherUserIds: string[]) {
  console.log('Creating conversations for Adam...');
  
  // Create conversations with 3 random users
  const selectedUsers = otherUserIds
    .sort(() => Math.random() - 0.5)
    .slice(0, 3);

  for (const otherUserId of selectedUsers) {
    // Create conversation ID by sorting user IDs
    const conversationId = [adamId, otherUserId].sort().join('_');
    
    // Create conversation document
    await db.collection('conversations').doc(conversationId).set({
      participants: [adamId, otherUserId],
      lastMessage: '',
      lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSenderId: '',
    });

    // Add 5-10 messages to each conversation
    const messageCount = Math.floor(Math.random() * 6) + 5;
    let lastMessage = '';
    let lastSenderId = '';

    for (let i = 0; i < messageCount; i++) {
      // Alternate between Adam and other user
      const senderId = i % 2 === 0 ? adamId : otherUserId;
      const message = sampleMessages[Math.floor(Math.random() * sampleMessages.length)];
      
      // Add message
      await db.collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
          text: message,
          senderId: senderId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });

      lastMessage = message;
      lastSenderId = senderId;

      // If message is from other user, increment Adam's unread count
      if (senderId !== adamId) {
        await db.collection('users')
          .doc(adamId)
          .collection('unreadMessages')
          .doc(conversationId)
          .set({
            count: admin.firestore.FieldValue.increment(1),
          }, { merge: true });
      }
    }

    // Update conversation with last message info
    await db.collection('conversations').doc(conversationId).update({
      lastMessage: lastMessage,
      lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSenderId: lastSenderId,
    });

    console.log(`Created conversation between Adam and user ${otherUserId}`);
  }
}

async function seedDatabase() {
  try {
    const videos = await getSampleVideos();
    const createdUserIds: string[] = [];

    // First create Adam's user
    const adamUser = {
      email: 'adamjweil@gmail.com',
      password: 'password',
      displayName: 'Adam Weil',
      username: 'adam',
      bio: 'Food enthusiast and home chef',
      avatarUrl: faker.image.avatar(),
    };

    // Create auth user for Adam
    const adamUserRecord = await auth.createUser({
      email: adamUser.email,
      password: adamUser.password,
      displayName: adamUser.displayName,
      photoURL: adamUser.avatarUrl,
    });

    const adamId = adamUserRecord.uid;

    // Create user document in Firestore
    await db.collection('users').doc(adamId).set({
      uid: adamId,
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

    createdUserIds.push(adamId);
    console.log(`Created Adam's account: ${adamId}`);

    // After creating Adam's account and before creating videos
    await createAdamCollections(adamId, videos);
    console.log('Created collections for Adam');

    // Create videos for Adam
    const numAdamVideos = 3;
    for (let i = 0; i < numAdamVideos; i++) {
      const videoId = await createVideo(adamId, videos);
      console.log(`Created video ${i + 1}/${numAdamVideos} for Adam: ${videoId}`);
    }

    // Create random users
    for (let i = 0; i < 10; i++) {
      const userId = await createUser();
      createdUserIds.push(userId);
      console.log(`Created user ${i + 1}/10 with ID: ${userId}`);

      // Create 1-2 videos for each user
      const numVideos = Math.random() < 0.5 ? 1 : 2;
      for (let j = 0; j < numVideos; j++) {
        const videoId = await createVideo(userId, videos);
        console.log(`Created video ${j + 1}/${numVideos} for user ${userId}: ${videoId}`);
      }
    }

    // Create random follow connections between users
    await createRandomConnections(createdUserIds);

    // Create conversations
    const otherUserIds = createdUserIds.filter(id => id !== adamId);
    await createConversations(adamId, otherUserIds);

    console.log('Database seeding completed successfully');
    process.exit(0);
  } catch (error) {
    console.error('Error during seeding:', error);
    process.exit(1);
  }
}

// Start the seeding process
seedDatabase().catch(console.error); 