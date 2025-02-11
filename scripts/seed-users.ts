import * as admin from 'firebase-admin';
import * as serviceAccount from './serviceAccountKey.json';
import { faker } from '@faker-js/faker';

// Initialize Firebase Admin with the correct bucket name
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
  storageBucket: "recipetok-acc07.firebasestorage.app"  // Updated bucket name
});

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

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

// Add food-focused bios array
const foodBios = [
  "Passionate home cook exploring global flavors 🌎",
  "Always experimenting with new recipes in the kitchen 👨‍🍳",
  "Food photographer and recipe developer 📸",
  "Healthy eating enthusiast | Meal prep lover 🥗",
  "Culinary student sharing my cooking journey 🔪",
  "Plant-based recipes and sustainable cooking 🌱",
  "BBQ master and grilling enthusiast 🔥",
  "Baking addict | Sourdough specialist 🍞",
  "Farm to table cooking | Seasonal recipes 🌾",
  "Comfort food with a healthy twist 🥘",
  "Food science nerd | Recipe tester 🧪",
  "Traditional recipes with modern flair 👩‍🍳",
  "Meal prep pro | Fitness foodie 💪",
  "Dessert lover sharing sweet creations 🧁",
  "International cuisine explorer | Spice lover 🌶"
];

const recipeDescriptions = [
  'Made this delicious dish for dinner tonight! The flavors turned out amazing 😋',
  'Finally perfected my grandmother\'s recipe after months of practice 👩‍🍳',
  'Quick and healthy meal prep for the week ahead! #MealPrep',
  'Sunday cooking session - meal prepped for the entire week! 🥘',
  'My take on a classic recipe with a modern twist 🌟',
  'Tried this recipe from @ChefJohn and it turned out perfect! Thanks for the inspiration',
  'Experimenting with new flavors today - absolutely love how it turned out! 🔥',
  'Simple ingredients, maximum flavor. Sometimes less is more! 👨‍🍳',
  'Meal prepping doesn\'t have to be boring - look at these colors! 🌈',
  'Late night cooking session - worth every minute of prep time 🌙'
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
  {
    name: 'Sushi',
    description: 'Roll with it! 🍱',
    imageUrl: 'https://int.japanesetaste.com/cdn/shop/articles/how-to-make-makizushi-sushi-rolls-japanese-taste.jpg?v=1707914944&width=1280',
    videos: {},
  },
  {
    name: 'Steaks',
    description: 'Rare finds, well done! 🥩',
    imageUrl: 'https://www.howtocook.recipes/wp-content/uploads/2022/11/rare-steak-recipejpg.jpg',
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
    description: 'First time making pizza from scratch! The fresh basil and buffalo mozzarella make all the difference 🍕 #HomemadePizza #ItalianCooking',
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
    title: 'Avocado Toast Brunch',
    description: 'Starting my day right with this protein-packed avocado toast! Added a poached egg and everything bagel seasoning 🥑 #HealthyBreakfast #BrunchGoals',
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
    description: 'Meal prep done right! This omega-3 rich bowl keeps me energized all day. The secret is in the marinade 🐟 #CleanEating #HealthyMealPrep',
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
    title: 'Post-Workout Protein Bowl',
    description: 'My go-to post-gym fuel! Packed with 30g of protein and tons of antioxidants from fresh berries 💪 #PostWorkout #HealthyEating',
    photoUrls: [
      'https://images.unsplash.com/photo-1577805947697-89e18249d767',
    ],
    ingredients: 'Greek yogurt, Mixed berries, Banana, Protein powder, Granola',
    instructions: '1. Blend ingredients\n2. Add toppings\n3. Serve immediately',
    mealType: 'breakfast',
  },
  {
    title: 'Quick Chicken Stir Fry',
    description: 'When you need dinner in 20 minutes! Used fresh veggies from the farmers market and my homemade stir fry sauce 🥢 #QuickMeals #StirFry',
    photoUrls: [
      'https://images.unsplash.com/photo-1603133872878-684f208fb84b',
    ],
    ingredients: 'Chicken breast, Mixed vegetables, Soy sauce, Ginger, Garlic',
    instructions: '1. Cut chicken\n2. Prepare sauce\n3. Stir fry\n4. Serve hot',
    mealType: 'dinner',
  },
];

// Add function to upload video and get URL
async function uploadVideoAndGetUrl(filename: string): Promise<{videoUrl: string, thumbnailUrl: string}> {
  try {
    // Upload video file
    const videoBuffer = require('fs').readFileSync(`assets/videos/${filename}`);
    const videoFile = storage.bucket().file(`sample_videos/${filename}`);
    await videoFile.save(videoBuffer);
    await videoFile.makePublic();
    const videoUrl = videoFile.publicUrl();

    // For thumbnail, we'll use a default image for now
    // You can replace this with actual video thumbnails if you have them
    const thumbnailUrl = 'https://picsum.photos/seed/burger/300/300';

    console.log(`Uploaded video: ${filename}`);
    return { videoUrl, thumbnailUrl };
  } catch (error) {
    console.error(`Error uploading video ${filename}:`, error);
    throw error;
  }
}

// Add your custom videos to the array
async function initializeSampleVideos() {
  const burger1 = await uploadVideoAndGetUrl('Burger_1.mp4');
  const burger2 = await uploadVideoAndGetUrl('Burger_2.mp4');
  
  sampleVideos.push(
    {
      videoUrl: burger1.videoUrl,
      thumbnailUrl: burger1.thumbnailUrl,
    },
    {
      videoUrl: burger2.videoUrl,
      thumbnailUrl: burger2.thumbnailUrl,
    }
  );
}

async function createUser() {
  const firstName = faker.person.firstName();
  const lastName = faker.person.lastName();
  const email = faker.internet.email({ firstName, lastName });
  const password = 'password123';
  const displayName = `${firstName} ${lastName}`;
  const username = faker.internet.userName({ firstName, lastName });
  
  // Generate a random birth date between 18 and 60 years ago
  const birthDate = faker.date.between({
    from: new Date(Date.now() - 60 * 365 * 24 * 60 * 60 * 1000),
    to: new Date(Date.now() - 18 * 365 * 24 * 60 * 60 * 1000)
  }).toISOString().split('T')[0];

  // Random gender selection
  const genders = ['Man', 'Woman', 'Prefer not to say'];
  const gender = genders[Math.floor(Math.random() * genders.length)];

  // Random food preferences (2-4 preferences)
  const allFoodTypes = [
    'Italian', 'Japanese', 'Mexican', 'Chinese', 'Indian', 'Thai',
    'Mediterranean', 'American', 'Korean', 'Vietnamese', 'French', 'Greek'
  ];
  const numPreferences = Math.floor(Math.random() * 3) + 2; // 2-4 preferences
  const foodPreferences = [...allFoodTypes]
    .sort(() => 0.5 - Math.random())
    .slice(0, numPreferences);

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
      firstName,
      lastName,
      birthDate,
      gender,
      foodPreferences,
      bio: foodBios[Math.floor(Math.random() * foodBios.length)],
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
  
  // Get user data first
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();
  
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
    // Get random likers (between 5 and 20)
    const numLikes = Math.floor(Math.random() * 16) + 5;
    const potentialLikers = (await db.collection('users')
      .where('uid', '!=', userId)
      .limit(30)
      .get()).docs.map(doc => doc.id);
    
    const likedBy = [...potentialLikers]
      .sort(() => 0.5 - Math.random())
      .slice(0, numLikes);

    const videoDoc = await db.collection('videos').add({
      userId,
      username: userData?.displayName || 'Anonymous',
      userHandle: userData?.username || 'user',
      userImage: userData?.avatarUrl,
      videoUrl: randomVideo.videoUrl,
      thumbnailUrl: randomVideo.thumbnailUrl,
      title: recipeTitles[Math.floor(Math.random() * recipeTitles.length)],
      description: recipeDescriptions[Math.floor(Math.random() * recipeDescriptions.length)],
      ingredients,
      instructions,
      likes: likedBy.length,
      likedBy: likedBy,
      views: Math.floor(Math.random() * 100) + 50, // Random views between 50-150
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

    console.log(`Created recipe video: ${videoDoc.id} with ${likedBy.length} likes`);
    return videoDoc.id;
  } catch (error) {
    console.error('Error creating video:', error);
    throw error;
  }
}

// Update the createRandomConnections function
async function createRandomConnections(userIds: string[], adamId: string) {
  try {
    // Make 3-5 random users follow Adam
    const numberOfFollowers = Math.floor(Math.random() * 3) + 3; // Random number between 3 and 5
    const randomFollowers = [...userIds]
      .filter(id => id !== adamId)
      .sort(() => 0.5 - Math.random())
      .slice(0, numberOfFollowers);

    // Make Adam follow 3-5 random users (different from followers)
    const remainingUsers = [...userIds]
      .filter(id => id !== adamId && !randomFollowers.includes(id));
    const numberOfFollowing = Math.floor(Math.random() * 3) + 3; // Random number between 3 and 5
    const randomFollowing = remainingUsers
      .sort(() => 0.5 - Math.random())
      .slice(0, numberOfFollowing);

    const batch = admin.firestore().batch();

    // Update Adam's followers array
    batch.update(admin.firestore().collection('users').doc(adamId), {
      followers: admin.firestore.FieldValue.arrayUnion(...randomFollowers),
      following: admin.firestore.FieldValue.arrayUnion(...randomFollowing),
    });

    // Update following array for each follower
    for (const followerId of randomFollowers) {
      batch.update(admin.firestore().collection('users').doc(followerId), {
        following: admin.firestore.FieldValue.arrayUnion(adamId),
      });
    }

    // Update followers array for each user Adam follows
    for (const followingId of randomFollowing) {
      batch.update(admin.firestore().collection('users').doc(followingId), {
        followers: admin.firestore.FieldValue.arrayUnion(adamId),
      });
    }

    // Create some random connections between other users
    for (const userId of userIds) {
      if (userId === adamId) continue;
      
      // Each user follows 2-4 random other users
      const numberOfFollowing = Math.floor(Math.random() * 3) + 2;
      const potentialFollowees = userIds.filter(id => id !== userId && id !== adamId);
      const randomFollowees = potentialFollowees
        .sort(() => 0.5 - Math.random())
        .slice(0, numberOfFollowing);

      // Update following array for current user
      batch.update(admin.firestore().collection('users').doc(userId), {
        following: admin.firestore.FieldValue.arrayUnion(...randomFollowees),
      });

      // Update followers array for each followed user
      for (const followeeId of randomFollowees) {
        batch.update(admin.firestore().collection('users').doc(followeeId), {
          followers: admin.firestore.FieldValue.arrayUnion(userId),
        });
      }
    }

    await batch.commit();
    console.log(`Created random follow connections with ${numberOfFollowers} users following Adam and Adam following ${numberOfFollowing} users`);
  } catch (error) {
    console.error('Error creating random connections:', error);
    throw error;
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

// Add this function to create meal post with likes
async function createMealPost(userId: string, postData: any) {
  try {
    // First get the user's data
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};

    // Get all users for potential likers with their data
    const usersSnapshot = await db.collection('users')
      .where('uid', '!=', userId)
      .get();
    
    const potentialLikers = usersSnapshot.docs.map(doc => ({
      id: doc.id,
      firstName: doc.data().firstName || 'Unknown',
      lastName: doc.data().lastName || '',
      displayName: doc.data().displayName || 'Unknown'
    }));
    
    // Generate random number of likes (between 5 and 20)
    const numLikes = Math.floor(Math.random() * 16) + 5;
    const selectedLikers = [...potentialLikers]
      .sort(() => 0.5 - Math.random())
      .slice(0, numLikes);

    // Store just the IDs in the likedBy array
    const likedByIds = selectedLikers.map(liker => liker.id);

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
      likes: likedByIds.length,
      likesCount: likedByIds.length,
      commentsCount: 0,
      likedBy: likedByIds, // Just store the array of user IDs
    };

    const postDoc = await db.collection('meal_posts').add(mealPost);
    
    // Create a likes subcollection for the meal post with user details
    const batch = admin.firestore().batch();
    selectedLikers.forEach(liker => {
      const likeDoc = postDoc.collection('likes').doc(liker.id);
      batch.set(likeDoc, {
        userId: liker.id,
        firstName: liker.firstName,
        lastName: liker.lastName,
        displayName: liker.displayName,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    await batch.commit();

    console.log(`Created meal post: ${postDoc.id} with ${likedByIds.length} likes`);
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
      firstName: 'Adam',
      lastName: 'Weil',
      birthDate: '1989-02-14',
      gender: 'Man',
      foodPreferences: ['Italian', 'Japanese', 'American'],
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
        firstName: adamUser.firstName,
        lastName: adamUser.lastName,
        birthDate: adamUser.birthDate,
        gender: adamUser.gender,
        foodPreferences: adamUser.foodPreferences,
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
          username: adamUser.displayName,
          userHandle: adamUser.username,
          userImage: adamUser.avatarUrl,
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

    // Create follow connections
    await createRandomConnections(createdUserIds, adamId);

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