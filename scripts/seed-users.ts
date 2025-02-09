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
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
  },
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg',
  },
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/TearsOfSteel.jpg',
  },
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/Sintel.jpg',
  },
  {
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/SubaruOutbackOnStreetAndDirt.jpg',
  }
];

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

// Add this after other sample data arrays
const sampleMealPosts = [
  {
    title: 'Homemade Margherita Pizza',
    description: 'Classic Italian pizza with fresh basil',
    photoUrls: [
      'https://images.unsplash.com/photo-1574071318508-1cdbab80d002',
      'https://images.unsplash.com/photo-1593560708920-61dd98c46a4e',
    ],
    ingredients: 'Pizza dough, San Marzano tomatoes, Fresh mozzarella, Basil, Olive oil',
    instructions: '1. Preheat oven to 500°F\n2. Roll out dough\n3. Add toppings\n4. Bake for 12-15 minutes',
    mealType: 'dinner',
    cookTime: 45,
    calories: 850,
    protein: 28,
    isVegetarian: true,
    carbonSaved: 1.2,
  },
  {
    title: 'Avocado Toast',
    description: 'Perfect breakfast or brunch',
    photoUrls: [
      'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d',
      'https://images.unsplash.com/photo-1588137378633-dea1336ce1e2',
    ],
    ingredients: 'Sourdough bread, Ripe avocado, Cherry tomatoes, Red pepper flakes, Salt',
    instructions: '1. Toast bread\n2. Mash avocado\n3. Add toppings\n4. Season to taste',
    mealType: 'breakfast',
    cookTime: 10,
    calories: 320,
    protein: 12,
    isVegetarian: true,
    carbonSaved: 0.8,
  },
  {
    title: 'Grilled Salmon Bowl',
    description: 'Healthy and delicious dinner option',
    photoUrls: [
      'https://images.unsplash.com/photo-1467003909585-2f8a72700288',
      'https://images.unsplash.com/photo-1580476262798-bddd9f4b7369',
    ],
    ingredients: 'Fresh salmon, Brown rice, Avocado, Cucumber, Soy sauce',
    instructions: '1. Cook rice\n2. Grill salmon\n3. Prepare vegetables\n4. Assemble bowl',
    mealType: 'dinner',
    cookTime: 30,
    calories: 620,
    protein: 42,
    isVegetarian: false,
    carbonSaved: 0,
  },
  {
    title: 'Protein Smoothie Bowl',
    description: 'Post-workout nutrition',
    photoUrls: [
      'https://images.unsplash.com/photo-1577805947697-89e18249d767',
    ],
    ingredients: 'Greek yogurt, Mixed berries, Banana, Protein powder, Granola',
    instructions: '1. Blend ingredients\n2. Add toppings\n3. Serve immediately',
    mealType: 'breakfast',
  },
  {
    title: 'Chicken Stir Fry',
    description: 'Quick and easy weeknight dinner',
    photoUrls: [
      'https://images.unsplash.com/photo-1603133872878-684f208fb84b',
    ],
    ingredients: 'Chicken breast, Mixed vegetables, Soy sauce, Ginger, Garlic',
    instructions: '1. Cut chicken\n2. Prepare sauce\n3. Stir fry\n4. Serve hot',
    mealType: 'dinner',
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
      thumbnailUrl: randomVideo.thumbnailUrl,
      title: recipeTitles[Math.floor(Math.random() * recipeTitles.length)],
      description: recipeDescriptions[Math.floor(Math.random() * recipeDescriptions.length)],
      ingredients,
      instructions,
      likes: 0,
      views: 0,
      commentCount: 0,
      isPinned: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create the likes subcollection document
    await videoDoc.collection('likes').doc('placeholder').set({
      timestamp: admin.firestore.FieldValue.serverTimestamp()
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

// Add this function to create meal posts
async function createMealPost(userId: string, postData: any) {
  try {
    // First get the user's data
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};

    const mealPost = {
      userId,
      userName: userData.displayName || 'Anonymous',
      userAvatarUrl: userData.avatarUrl,
      title: postData.title,
      description: postData.description,
      photoUrls: postData.photoUrls,
      ingredients: postData.ingredients,
      instructions: postData.instructions,
      mealType: postData.mealType,
      cookTime: postData.cookTime || 0,
      calories: postData.calories || 0,
      protein: postData.protein || 0,
      isVegetarian: postData.isVegetarian || false,
      carbonSaved: postData.carbonSaved || 0.0,
      isPublic: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      likesCount: 0,
      commentsCount: 0,
      likedBy: [],
    };

    const postDoc = await db.collection('meal_posts').add(mealPost);
    console.log(`Created meal post: ${postDoc.id}`);
    return postDoc.id;
  } catch (error) {
    console.error('Error creating meal post:', error);
    throw error;
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
    let adamId: string; // Define adamId at the top level of the try block

    // Create auth user for Adam
    try {
      const adamUserRecord = await auth.createUser({
        email: adamUser.email,
        password: adamUser.password,
        displayName: adamUser.displayName,
        photoURL: adamUser.avatarUrl,
      });

      adamId = adamUserRecord.uid; // Store the ID

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

      createdUserIds.push(adamUserRecord.uid);
      console.log(`Created specific user: ${adamUserRecord.uid}`);

      // Create 9 specific videos for Adam
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
        {
          title: 'Creamy Mac and Cheese',
          description: 'The ultimate comfort food recipe',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/mac/300/300',
          ingredients: ['Macaroni', 'Cheddar cheese', 'Milk', 'Butter'],
          instructions: ['Boil pasta', 'Make cheese sauce', 'Combine and bake'],
        },
        {
          title: 'Chocolate Chip Cookies',
          description: 'Soft and chewy chocolate chip cookies',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/cookies/300/300',
          ingredients: ['Flour', 'Butter', 'Chocolate chips', 'Brown sugar'],
          instructions: ['Mix ingredients', 'Form cookies', 'Bake until golden'],
        },
        {
          title: 'Spicy Thai Curry',
          description: 'Authentic Thai red curry recipe',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/curry/300/300',
          ingredients: ['Coconut milk', 'Red curry paste', 'Chicken', 'Vegetables'],
          instructions: ['Cook curry paste', 'Add coconut milk', 'Simmer with ingredients'],
        },
        {
          title: 'Fresh Sushi Rolls',
          description: 'Learn to make sushi at home',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/sushi/300/300',
          ingredients: ['Sushi rice', 'Nori', 'Fresh fish', 'Vegetables'],
          instructions: ['Prepare rice', 'Layer ingredients', 'Roll and cut'],
        },
        {
          title: 'Homemade Bread',
          description: 'Simple no-knead bread recipe',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/bread/300/300',
          ingredients: ['Flour', 'Yeast', 'Salt', 'Water'],
          instructions: ['Mix ingredients', 'Let rise', 'Bake in Dutch oven'],
        },
        {
          title: 'Grilled Steak',
          description: 'Perfect steak every time',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
          thumbnailUrl: 'https://picsum.photos/seed/steak/300/300',
          ingredients: ['Ribeye steak', 'Salt', 'Pepper', 'Garlic'],
          instructions: ['Season well', 'Grill to temperature', 'Rest before cutting'],
        }
      ];

      const createdVideos = [];
      for (const videoData of adamVideos) {
        const videoDoc = await db.collection('videos').add({
          userId: adamUserRecord.uid,
          ...videoData,
          likes: 0,
          views: 0,
          commentCount: 0,
          isPinned: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Create the likes subcollection document
        await videoDoc.collection('likes').doc('placeholder').set({
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        createdVideos.push({ id: videoDoc.id, ...videoData });
        console.log(`Created video for Adam: ${videoDoc.id}`);
      }

      await db.collection('users').doc(adamUserRecord.uid).update({
        videoCount: adamVideos.length,
      });

      // Pass the created videos to createAdamCollections
      await createAdamCollections(adamUserRecord.uid, createdVideos);

      // Add Adam's meal posts
      for (const postData of sampleMealPosts) {
        await createMealPost(adamUserRecord.uid, postData);
        console.log(`Created meal post for Adam: ${postData.title}`);
      }
    } catch (error) {
      console.error('Error creating Adam\'s account:', error);
      throw error; // Re-throw the error to stop the seeding process
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

      // Create 3 random meal posts for each user
      for (let j = 0; j < 3; j++) {
        const randomPost = sampleMealPosts[Math.floor(Math.random() * sampleMealPosts.length)];
        await createMealPost(userId, {
          ...randomPost,
          title: `${randomPost.title} ${j + 1}`,
          description: `${faker.lorem.sentence()} ${randomPost.description}`,
        });
        console.log(`Created meal post ${j + 1}/3 for user ${userId}`);
      }
    }

    // Create random follow connections between users
    await createRandomConnections(createdUserIds);

    // Create conversations using adamId instead of adamUserRecord
    const otherUserIds = createdUserIds.filter(id => id !== adamId);
    await createConversations(adamId, otherUserIds);

    console.log('Database seeding completed successfully');
    process.exit(0);
  } catch (error) {
    console.error('Error during seeding:', error);
    process.exit(1);
  }
}

seedDatabase(); 