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
const avatarUrls = [
  // Professional headshots and portraits
  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
  'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
  'https://images.unsplash.com/photo-1438761681033-6461ffad8d80',
  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
  'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
  'https://images.unsplash.com/photo-1554151228-14d9def656e4',
  'https://images.unsplash.com/photo-1499952127939-9bbf5af6c51c',
  'https://images.unsplash.com/photo-1517841905240-472988babdf9',
  'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6',
  'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
  // Animal portraits for variety
  'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8',
  'https://images.unsplash.com/photo-1518791841217-8f162f1e1131',
  'https://images.unsplash.com/photo-1573865526739-10659fec78a5',
  'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba',
  'https://images.unsplash.com/photo-1543852786-1cf6624b9987'
];

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
  'Nailed this sourdough after 6 months of practice! Look at that crumb structure 🍞✨',
  'First attempt at homemade ramen and the broth is PERFECT. 18-hour process totally worth it 🍜',
  'Made croissants from scratch and my French grandmother would be proud! Those layers though 🥐',
  'Finally mastered the art of tempering chocolate. Look at that shine! No more blooming 🍫',
  'My homemade pasta game is getting stronger! Made these ravioli completely from scratch 🍝',
  'Been working on my plating skills and I think I am ready for MasterChef now 👨‍🍳',
  'The secret is in the 24-hour marinade. Best grilled chicken I have ever made! 🔥',
  'Three days of prep for this authentic Pho but just look at that clear broth! 🥣',
  'Made macarons and NOT ONE cracked! Third time is the charm 🤩',
  'My knife skills are finally paying off - brunoise cut in under 2 minutes! 🔪'
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
    description: 'Finally achieved that perfect Neapolitan crust! 72-hour cold fermented dough and my new pizza steel made all the difference 🍕 #HomemadePizza #ItalianCooking',
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
    description: 'Leveled up my poaching game - look at that perfectly runny yolk! The homemade sourdough makes all the difference 🥑 #HealthyBreakfast #BrunchGoals',
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
    description: 'Mastered the art of crispy salmon skin while keeping the inside perfectly medium-rare. That color is all natural, no filters needed! 🐟 #CleanEating #HealthyMealPrep',
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
    description: 'Who says healthy cant be Instagram-worthy? Made my own granola and that protein content is insane! 💪 #PostWorkout #HealthyEating',
    photoUrls: [
      'https://images.unsplash.com/photo-1577805947697-89e18249d767',
    ],
    ingredients: 'Greek yogurt, Mixed berries, Banana, Protein powder, Granola',
    instructions: '1. Blend ingredients\n2. Add toppings\n3. Serve immediately',
    mealType: 'breakfast',
  },
  {
    title: 'Quick Chicken Stir Fry',
    description: 'Wok hei achieved! Finally got that restaurant-style char on my veggies. The secret? Getting that wok smoking hot 🥢 #QuickMeals #StirFry',
    photoUrls: [
      'https://images.unsplash.com/photo-1603133872878-684f208fb84b',
    ],
    ingredients: 'Chicken breast, Mixed vegetables, Soy sauce, Ginger, Garlic',
    instructions: '1. Cut chicken\n2. Prepare sauce\n3. Stir fry\n4. Serve hot',
    mealType: 'dinner',
    cookTime: 30,
    calories: 450,
    protein: 35,
    isVegetarian: false,
    carbonSaved: 0.9,
  },
];

// Add this after other sample data arrays
const sampleMealComments = [
  "This looks absolutely delicious! 😋",
  "Love your plating! Could you share the recipe?",
  "Making this tonight! Thanks for sharing 🙏",
  "Your food always looks amazing! 👨‍🍳",
  "What temperature do you cook this at?",
  "Perfect comfort food! 😍",
  "I tried this recipe and it turned out great!",
  "The colors in this dish are beautiful 📸",
  "How long did this take to make?",
  "This is definitely going on my must-try list ✨",
  "Love how simple yet elegant this looks",
  "My kids would love this! Saving for later",
  "The texture looks perfect! Any special tips?",
  "This is making me hungry! 🤤",
  "Where do you get your ingredients from?",
  "Your presentation is always on point! 👌",
  "Can this be made vegetarian?",
  "Perfect weeknight dinner idea!",
  "The seasoning looks spot on 👏",
  "This would be great for meal prep!"
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
  // Common first names
  const firstNames = [
    'James', 'John', 'Robert', 'Michael', 'William',
    'David', 'Richard', 'Joseph', 'Thomas', 'Christopher',
    'Emma', 'Olivia', 'Ava', 'Isabella', 'Sophia',
    'Mia', 'Charlotte', 'Amelia', 'Harper', 'Evelyn'
  ];

  // Common last names
  const lastNames = [
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones',
    'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
    'Anderson', 'Taylor', 'Thomas', 'Moore', 'Jackson',
    'Martin', 'Lee', 'Thompson', 'White', 'Harris'
  ];

  const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
  const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
  const email = faker.internet.email({ firstName, lastName });
  const password = 'password123';
  const displayName = `${firstName} ${lastName}`;
  
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
      photoURL: avatarUrls[Math.floor(Math.random() * avatarUrls.length)],
    });

    // Create user document in Firestore
    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email,
      displayName,
      firstName,
      lastName,
      birthDate,
      gender,
      foodPreferences,
      bio: foodBios[Math.floor(Math.random() * foodBios.length)],
      avatarUrl: avatarUrls[Math.floor(Math.random() * avatarUrls.length)],
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

// Add this helper function at the top level
function getRandomTimestampInLastTwoWeeks() {
  const now = new Date();
  const twoWeeksAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
  return new Date(twoWeeksAgo.getTime() + Math.random() * (now.getTime() - twoWeeksAgo.getTime()));
}

// Update the createMealPost function signature and implementation
async function createMealPost(userId: string, postData: any, timestamp: Date): Promise<string> {
  try {
    // First get the user's data
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};

    // Get all users for potential likers with their data
    const usersSnapshot = await db.collection('users')
      .where('uid', '!=', userId)
      .get();
    
    if (!usersSnapshot.docs.length) {
      console.log('No users found for liking/commenting');
      throw new Error('No users found for liking/commenting');
    }

    const potentialLikers = usersSnapshot.docs
      .map(doc => ({
        id: doc.id,
        firstName: doc.data().firstName || 'Unknown',
        lastName: doc.data().lastName || '',
        displayName: doc.data().displayName || 'Unknown',
        avatarUrl: doc.data().avatarUrl
      }))
      .filter(user => user.id);
    
    // Determine number of likes based on a distribution
    // 25% chance each for 0, 1, 2, and 3+ likes
    const likesDistribution = Math.random();
    let numLikes;
    if (likesDistribution < 0.25) {
      numLikes = 0; // 25% chance of 0 likes
    } else if (likesDistribution < 0.5) {
      numLikes = 1; // 25% chance of 1 like
    } else if (likesDistribution < 0.75) {
      numLikes = 2; // 25% chance of 2 likes
    } else {
      numLikes = Math.floor(Math.random() * 8) + 3; // 25% chance of 3-10 likes
    }

    // Select random likers based on the determined number
    const selectedLikers = [...potentialLikers]
      .sort(() => 0.5 - Math.random())
      .slice(0, Math.min(numLikes, potentialLikers.length));

    // Store just the IDs in the likedBy array
    const likedByIds = selectedLikers.map(liker => liker.id);

    const mealPost = {
      userId,
      userName: userData.displayName || 'Anonymous',
      userAvatarUrl: userData.avatarUrl,
      title: postData.title,
      description: postData.description,
      photoUrls: postData.photoUrls || [],
      ingredients: postData.ingredients,
      instructions: postData.instructions,
      mealType: postData.mealType.toLowerCase(), // Ensure mealType is lowercase
      cookTime: postData.cookTime || 0,
      calories: postData.calories || 0,
      protein: postData.protein || 0,
      isVegetarian: postData.isVegetarian || false,
      carbonSaved: postData.carbonSaved || 0.0,
      isPublic: true,
      createdAt: admin.firestore.Timestamp.fromDate(timestamp),
      likes: likedByIds.length,
      likesCount: likedByIds.length,
      commentsCount: 0,
      likedBy: likedByIds,
    };

    const postDoc = await db.collection('meal_posts').add(mealPost);
    
    // Create a likes subcollection for the meal post with user details
    const batch = admin.firestore().batch();
    selectedLikers.forEach(liker => {
      if (liker && liker.id) {
        const likeDoc = postDoc.collection('likes').doc(liker.id);
        batch.set(likeDoc, {
          userId: liker.id,
          firstName: liker.firstName,
          lastName: liker.lastName,
          displayName: liker.displayName,
          timestamp: admin.firestore.Timestamp.fromDate(timestamp)
        });
      }
    });
    await batch.commit();

    return postDoc.id;
  } catch (error) {
    console.error('Error creating meal post:', error);
    throw error;
  }
}

// Add these arrays before the seedDatabase function
const adamMealPosts = [
  {
    title: 'Perfect Morning Avocado Toast',
    description: 'Starting my day right with this protein-packed avocado toast! Added a poached egg and everything bagel seasoning 🥑',
    photoUrls: ['https://images.unsplash.com/photo-1541519227354-08fa5d50c44d'],
    ingredients: 'Sourdough bread, ripe avocado, eggs, everything bagel seasoning, red pepper flakes',
    instructions: 'Toast bread, mash avocado, poach egg, assemble, and season',
    mealType: 'breakfast',
    cookTime: 15,
    calories: 350,
    protein: 15,
    isVegetarian: true,
    carbonSaved: 0.8,
  },
  {
    title: 'Homemade Sushi Rolls',
    description: 'Finally mastered the art of rolling sushi at home! 🍱 These spicy tuna rolls are a game changer',
    photoUrls: ['https://images.unsplash.com/photo-1579871494447-9811cf80d66c'],
    ingredients: 'Sushi rice, nori, fresh tuna, spicy mayo, cucumber',
    instructions: 'Prepare rice, mix spicy tuna, roll carefully, slice',
    mealType: 'dinner',
    cookTime: 45,
    calories: 450,
    protein: 22,
    isVegetarian: false,
    carbonSaved: 1.2,
  },
  {
    title: 'Protein Power Bowl',
    description: 'Post-workout fuel that tastes amazing! Quinoa base with grilled chicken and roasted veggies 💪',
    photoUrls: ['https://images.unsplash.com/photo-1543339308-43e59d6b73a6'],
    ingredients: 'Quinoa, chicken breast, mixed vegetables, olive oil, lemon',
    instructions: 'Cook quinoa, grill chicken, roast vegetables, assemble',
    mealType: 'lunch',
    cookTime: 30,
    calories: 520,
    protein: 35,
    isVegetarian: false,
    carbonSaved: 0.9,
  },
  {
    title: 'Healthy Overnight Oats',
    description: 'Meal prep made easy! These overnight oats with berries and honey are perfect for busy mornings 🍯',
    photoUrls: ['https://images.unsplash.com/photo-1517673400267-0251440c45dc'],
    ingredients: 'Rolled oats, almond milk, chia seeds, mixed berries, honey',
    instructions: 'Mix ingredients, refrigerate overnight, top with fresh berries',
    mealType: 'breakfast',
    cookTime: 5,
    calories: 310,
    protein: 12,
    isVegetarian: true,
    carbonSaved: 0.5,
  },
  {
    title: 'Homemade Pizza Night',
    description: 'Nothing beats a fresh homemade pizza! The secret is in the dough fermentation 🍕',
    photoUrls: ['https://images.unsplash.com/photo-1574071318508-1cdbab80d002'],
    ingredients: 'Pizza dough, San Marzano tomatoes, fresh mozzarella, basil',
    instructions: 'Stretch dough, add toppings, bake at high heat',
    mealType: 'dinner',
    cookTime: 25,
    calories: 850,
    protein: 28,
    isVegetarian: true,
    carbonSaved: 1.1,
  },
  {
    title: 'Mediterranean Lunch Bowl',
    description: 'Fresh and light Mediterranean bowl with homemade hummus and falafel 🥙',
    photoUrls: ['https://images.unsplash.com/photo-1529059997568-3d847b1154f0'],
    ingredients: 'Chickpeas, tahini, mixed greens, falafel, olive oil',
    instructions: 'Make hummus, prepare falafel, assemble bowl',
    mealType: 'lunch',
    cookTime: 40,
    calories: 480,
    protein: 18,
    isVegetarian: true,
    carbonSaved: 1.4,
  },
  {
    title: 'Healthy Afternoon Smoothie',
    description: 'The perfect afternoon pick-me-up! Packed with superfoods and protein 🥤',
    photoUrls: ['https://images.unsplash.com/photo-1502741224143-90386d7f8c82'],
    ingredients: 'Banana, spinach, protein powder, almond milk, chia seeds',
    instructions: 'Blend all ingredients until smooth',
    mealType: 'snack',
    cookTime: 5,
    calories: 220,
    protein: 20,
    isVegetarian: true,
    carbonSaved: 0.3,
  },
  {
    title: 'Grilled Steak & Veggies',
    description: 'Perfect medium-rare steak with grilled seasonal vegetables 🥩',
    photoUrls: ['https://images.unsplash.com/photo-1544025162-d76694265947'],
    ingredients: 'Ribeye steak, asparagus, mushrooms, garlic butter',
    instructions: 'Season steak, grill to preference, rest, serve',
    mealType: 'dinner',
    cookTime: 20,
    calories: 680,
    protein: 45,
    isVegetarian: false,
    carbonSaved: 0.0,
  },
  {
    title: 'Energy Protein Balls',
    description: 'No-bake protein balls - perfect pre-workout snack or afternoon treat! 🍪',
    photoUrls: ['https://images.unsplash.com/photo-1604329760661-e71dc83f8f26'],
    ingredients: 'Dates, almonds, protein powder, cocoa powder, honey',
    instructions: 'Process ingredients, form balls, refrigerate',
    mealType: 'snack',
    cookTime: 15,
    calories: 120,
    protein: 8,
    isVegetarian: true,
    carbonSaved: 0.4,
  },
  {
    title: 'Spicy Ramen Bowl',
    description: 'Homemade ramen with a perfect soft-boiled egg and fresh vegetables 🍜',
    photoUrls: ['https://images.unsplash.com/photo-1569718212165-3a8278d5f624'],
    ingredients: 'Ramen noodles, pork belly, soft-boiled egg, green onions',
    instructions: 'Prepare broth, cook noodles, assemble toppings',
    mealType: 'dinner',
    cookTime: 35,
    calories: 580,
    protein: 32,
    isVegetarian: false,
    carbonSaved: 0.7,
  }
];

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

// Add test user data
const testUser = {
  email: 'test@test.com',
  password: 'password',
  displayName: 'Chef Jamie',
  firstName: 'Jamie',
  lastName: 'Thompson',
  birthDate: '1995-08-21',
  gender: 'Prefer not to say',
  foodPreferences: ['Italian', 'French', 'Japanese', 'Mediterranean'],
  bio: 'Former restaurant chef turned home cooking enthusiast. Specializing in French techniques with a modern twist 🔪✨',
  avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
};

// Add test user's meal posts
const testUserMealPosts = [
  {
    title: 'Duck Confit',
    description: 'After 3 days of curing and 6 hours of slow cooking, this duck confit is EVERYTHING! That crispy skin though... 🦆✨ #FrenchCuisine #ChefLife',
    photoUrls: ['https://images.unsplash.com/photo-1580476262798-bddd9f4b7369'],
    ingredients: 'Duck legs, sea salt, garlic, thyme, duck fat, black pepper',
    instructions: '1. Cure duck for 3 days\n2. Rinse and pat dry\n3. Slow cook in duck fat\n4. Crisp skin before serving',
    mealType: 'dinner',
    cookTime: 360,
    calories: 780,
    protein: 45,
    isVegetarian: false,
    carbonSaved: 0.0,
  },
  {
    title: 'Chocolate Soufflé',
    description: 'No deflation here! Mastered the perfect rise on these dark chocolate soufflés. The key? Proper egg white technique and preheated ramekins 🍫 #PastryChef #FrenchDesserts',
    photoUrls: ['https://images.unsplash.com/photo-1470124182917-cc6e71b22ecc'],
    ingredients: 'Dark chocolate, eggs, butter, sugar, vanilla bean, cream of tartar',
    instructions: '1. Prepare ramekins\n2. Make chocolate base\n3. Fold in egg whites\n4. Bake immediately',
    mealType: 'dinner',
    cookTime: 25,
    calories: 420,
    protein: 8,
    isVegetarian: true,
    carbonSaved: 0.5,
  },
  {
    title: 'Homemade Ramen',
    description: 'My 36-hour tonkotsu ramen! That broth clarity and the perfect jammy egg... worth every minute of prep. Even made the noodles from scratch! 🍜 #RamenMaster #ChefTechniques',
    photoUrls: ['https://images.unsplash.com/photo-1569718212165-3a8278d5f624'],
    ingredients: 'Pork bones, ramen noodles, chashu pork, soy sauce, mirin, eggs',
    instructions: '1. Prepare 36-hour broth\n2. Make noodles\n3. Cook chashu\n4. Assemble bowls',
    mealType: 'dinner',
    cookTime: 2160,
    calories: 890,
    protein: 52,
    isVegetarian: false,
    carbonSaved: 0.8,
  }
];

async function seedDatabase() {
  try {
    // First create your specific user
    const adamUser = {
      email: 'adamjweil@gmail.com',
      password: 'password',
      displayName: 'Adam Weil',
      firstName: 'Adam',
      lastName: 'Weil',
      birthDate: '1989-02-14',
      gender: 'Man',
      foodPreferences: ['Italian', 'Japanese', 'American'],
      bio: 'Food enthusiast and home chef',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
    };

    const createdUserIds: string[] = [];
    let adamId: string;
    let testUserId: string;

    // Create auth user for Adam
    try {
      console.log('Creating Adam\'s account...');
      const adamUserRecord = await auth.createUser({
        email: adamUser.email,
        password: adamUser.password,
        displayName: adamUser.displayName,
        photoURL: adamUser.avatarUrl,
      });

      adamId = adamUserRecord.uid;
      console.log('Created Adam\'s account with ID:', adamId);

      // Create user document in Firestore
      await db.collection('users').doc(adamUserRecord.uid).set({
        uid: adamUserRecord.uid,
        email: adamUser.email,
        displayName: adamUser.displayName,
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

      // Create test user
      console.log('Creating test account...');
      const testUserRecord = await auth.createUser({
        email: testUser.email,
        password: testUser.password,
        displayName: testUser.displayName,
        photoURL: testUser.avatarUrl,
      });

      testUserId = testUserRecord.uid;
      console.log('Created test account with ID:', testUserId);

      // Create test user document in Firestore
      await db.collection('users').doc(testUserRecord.uid).set({
        uid: testUserRecord.uid,
        email: testUser.email,
        displayName: testUser.displayName,
        firstName: testUser.firstName,
        lastName: testUser.lastName,
        birthDate: testUser.birthDate,
        gender: testUser.gender,
        foodPreferences: testUser.foodPreferences,
        bio: testUser.bio,
        avatarUrl: testUser.avatarUrl,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        followers: [],
        following: [],
        videoCount: 0,
      });

      createdUserIds.push(testUserRecord.uid);

      // Create other users first to have them available for likes and comments
      console.log('Creating random users...');
      for (let i = 0; i < 10; i++) {
        const userId = await createUser();
        createdUserIds.push(userId);
        console.log(`Created user ${i + 1}/10 with ID: ${userId}`);
      }

      // Create test user's meal posts with interactions
      console.log('Creating meal posts for test user...');
      for (const postData of testUserMealPosts) {
        try {
          const timestamp = getRandomTimestampInLastTwoWeeks();
          const postId = await createMealPost(testUserId!, postData, timestamp);
          
          if (!postId) {
            console.error('Failed to create meal post: postId is null');
            continue;
          }

          // Add likes from Adam and 2-4 random users
          const numRandomLikes = Math.floor(Math.random() * 3) + 2; // 2-4 random likes
          const randomLikers = [...createdUserIds]
            .filter(id => id !== testUserId && id !== adamId)
            .sort(() => 0.5 - Math.random())
            .slice(0, numRandomLikes);
          
          // Always include Adam's like
          randomLikers.push(adamId!);

          // Update post with likes
          await db.collection('meal_posts').doc(postId).update({
            likes: randomLikers.length,
            likedBy: randomLikers,
          });

          // Add comments from Adam and random users
          const commentTexts = [
            'This looks incredible! Love the attention to detail 👨‍🍳',
            'Your plating skills are next level! 🔥',
            'Need the full recipe ASAP! 🙏',
            'The dedication to perfecting this dish shows!',
            'This is restaurant quality! Amazing work 👏'
          ];

          // Add 2-3 comments per post
          const numComments = Math.floor(Math.random() * 2) + 2;
          for (let i = 0; i < numComments; i++) {
            const commenterId = i === 0 ? adamId! : randomLikers[i - 1];
            await db.collection('meal_posts').doc(postId)
              .collection('comments')
              .add({
                text: commentTexts[i],
                userId: commenterId,
                createdAt: admin.firestore.Timestamp.fromDate(
                  new Date(timestamp.getTime() + (i + 1) * 60000)
                ),
              });
          }

          // Update comment count
          await db.collection('meal_posts').doc(postId).update({
            commentsCount: numComments,
          });

          console.log(`Successfully created meal post for test user: ${postData.title} with ID: ${postId} at ${timestamp.toISOString()}`);
        } catch (error) {
          console.error(`Failed to create meal post: ${postData.title}`, error);
          console.error('Error details:', error);
        }
      }

      // Make Adam follow the test user
      await db.collection('users').doc(adamId!).update({
        following: admin.firestore.FieldValue.arrayUnion(testUserId!),
      });

      await db.collection('users').doc(testUserId!).update({
        followers: admin.firestore.FieldValue.arrayUnion(adamId!),
      });

      // Now create Adam's meal posts
      console.log('Creating meal posts for Adam...');
      for (const postData of adamMealPosts) {
        try {
          const timestamp = getRandomTimestampInLastTwoWeeks();
          const postId = await createMealPost(adamId!, postData, timestamp);
          console.log(`Successfully created meal post for Adam: ${postData.title} with ID: ${postId} at ${timestamp.toISOString()}`);
        } catch (error) {
          console.error(`Failed to create meal post: ${postData.title}`, error);
          console.error('Error details:', error);
        }
      }

      // Create videos for Adam
      console.log('Creating videos for Adam...');
      const createdVideos = [];
      for (const videoData of adamVideos) {
        const videoDoc = await db.collection('videos').add({
          userId: adamId,
          username: adamUser.displayName,
          userImage: adamUser.avatarUrl,
          ...videoData,
          likes: 0,
          views: 0,
          commentCount: 0,
          isPinned: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await videoDoc.collection('likes').doc('placeholder').set({
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        createdVideos.push({ id: videoDoc.id, ...videoData });
        console.log(`Created video for Adam: ${videoDoc.id}`);
      }

      // Update video count
      await db.collection('users').doc(adamId).update({
        videoCount: adamVideos.length,
      });

      // Create Adam's collections
      await createAdamCollections(adamId, createdVideos);

      // Create videos for other users
      console.log('Creating content for other users...');
      for (const userId of createdUserIds) {
        if (userId === adamId) continue;

        // Create 1-2 videos for each user
        const numVideos = Math.random() < 0.5 ? 1 : 2;
        for (let j = 0; j < numVideos; j++) {
          const videoId = await createVideo(userId);
          console.log(`Created video ${j + 1}/${numVideos} for user ${userId}: ${videoId}`);
        }

        // Create 3 random meal posts for each user
        for (let j = 0; j < 3; j++) {
          const randomPost = sampleMealPosts[Math.floor(Math.random() * sampleMealPosts.length)];
          const timestamp = getRandomTimestampInLastTwoWeeks();
          await createMealPost(userId, {
            ...randomPost,
            title: randomPost.title,
            description: randomPost.description,
          }, timestamp);
          console.log(`Created meal post ${j + 1}/3 for user ${userId}`);
        }
      }

      // Create follow connections
      await createRandomConnections(createdUserIds, adamId);

      // Create conversations
      const otherUserIds = createdUserIds.filter(id => id !== adamId);
      await createConversations(adamId, otherUserIds);

      console.log('Database seeding completed successfully');
      process.exit(0);
    } catch (error) {
      console.error('Error creating Adam\'s account:', error);
      throw error;
    }
  } catch (error) {
    console.error('Error during seeding:', error);
    process.exit(1);
  }
}

seedDatabase(); 