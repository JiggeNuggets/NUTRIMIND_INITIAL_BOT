import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/meal_model.dart';
import '../models/post_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── Collections ────────────────────────────────
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _posts => _db.collection('posts');
  CollectionReference _meals(String uid) =>
      _db.collection('users').doc(uid).collection('meals');
  CollectionReference _comments(String postId) =>
      _db.collection('posts').doc(postId).collection('comments');

  // ─── USER ───────────────────────────────────────

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
    // Seed default meal plan
    await _seedDefaultMeals(user.uid);
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update(data);
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  // ─── MEALS ──────────────────────────────────────

  Future<void> _seedDefaultMeals(String uid) async {
    final today = DateTime.now();
    final meals = [
      MealModel(
        id: _uuid.v4(), userId: uid, name: 'Pomelo & Davao Honey',
        type: MealType.breakfast, price: 40, calories: 280,
        status: MealStatus.upcoming, date: today,
        protein: 3, carbs: 68, fat: 1,
        ingredients: ['Pomelo', 'Davao Honey', 'Mint leaves'],
      ),
      MealModel(
        id: _uuid.v4(), userId: uid, name: 'Grilled Tuna',
        type: MealType.lunch, price: 80, calories: 450,
        status: MealStatus.upcoming, date: today,
        protein: 42, carbs: 12, fat: 18,
        ingredients: ['Fresh Tuna', 'Garlic', 'Ginger', 'Toyo Mansi'],
      ),
      MealModel(
        id: _uuid.v4(), userId: uid, name: 'Tuna Omelette',
        type: MealType.dinner, price: 60, calories: 310,
        status: MealStatus.upcoming, date: today,
        protein: 28, carbs: 8, fat: 14,
        ingredients: ['Eggs', 'Tuna', 'Onion', 'Tomato'],
      ),
      MealModel(
        id: _uuid.v4(), userId: uid, name: 'Saba Banana',
        type: MealType.snack, price: 30, calories: 120,
        status: MealStatus.upcoming, date: today,
        protein: 2, carbs: 28, fat: 0,
        ingredients: ['Saba Banana'],
      ),
    ];

    final batch = _db.batch();
    for (final meal in meals) {
      batch.set(_meals(uid).doc(meal.id), meal.toMap());
    }
    await batch.commit();
  }

  Stream<List<MealModel>> mealsStream(String uid, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _meals(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) => s.docs
            .map((d) => MealModel.fromMap(d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.type.index.compareTo(b.type.index)));
  }

  Future<List<MealModel>> getMealsForDate(String uid, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _meals(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs
        .map((d) => MealModel.fromMap(d.data() as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
  }

  Future<void> logMeal(String uid, String mealId) async {
    await _meals(uid).doc(mealId).update({
      'status': MealStatus.logged.name,
      'loggedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> addMeal(MealModel meal) async {
    await _meals(meal.userId).doc(meal.id).set(meal.toMap());
  }

  Future<void> deleteMeal(String uid, String mealId) async {
    await _meals(uid).doc(mealId).delete();
  }

  Future<void> updateMeal(String uid, String mealId, Map<String, dynamic> data) async {
    await _meals(uid).doc(mealId).update(data);
  }

  // ─── POSTS ──────────────────────────────────────

  Stream<List<PostModel>> postsStream({String? category}) {
    Query query = _posts.orderBy('createdAt', descending: true);
    if (category != null && category != 'Trending') {
      query = query.where('category', isEqualTo: category);
    }
    return query.limit(30).snapshots().map((s) => s.docs
        .map((d) => PostModel.fromMap(d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<String> createPost(PostModel post) async {
    final id = _uuid.v4();
    final newPost = PostModel(
      id: id,
      userId: post.userId,
      userName: post.userName,
      userPhotoUrl: post.userPhotoUrl,
      location: post.location,
      content: post.content,
      category: post.category,
      imageUrl: post.imageUrl,
      createdAt: DateTime.now(),
      tags: post.tags,
    );
    await _posts.doc(id).set(newPost.toMap());
    return id;
  }

  Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
  }

  Future<void> toggleLike(String postId, String uid) async {
    final doc = await _posts.doc(postId).get();
    final data = doc.data() as Map<String, dynamic>;
    final likes = List<String>.from(data['likes'] ?? []);
    if (likes.contains(uid)) {
      likes.remove(uid);
    } else {
      likes.add(uid);
    }
    await _posts.doc(postId).update({'likes': likes});
  }

  // ─── COMMENTS ───────────────────────────────────

  Stream<List<CommentModel>> commentsStream(String postId) {
    return _comments(postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs
            .map((d) => CommentModel.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> addComment(CommentModel comment) async {
    final id = _uuid.v4();
    final newComment = CommentModel(
      id: id,
      postId: comment.postId,
      userId: comment.userId,
      userName: comment.userName,
      userPhotoUrl: comment.userPhotoUrl,
      content: comment.content,
      createdAt: DateTime.now(),
    );
    await _comments(comment.postId).doc(id).set(newComment.toMap());
    await _posts.doc(comment.postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  // ─── LEADERBOARD ────────────────────────────────

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final snap = await _users
        .orderBy('dailyBudget', descending: false)
        .limit(10)
        .get();
    return snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();
  }

  // ─── GENERATE NEW MEAL PLAN ─────────────────────

  Future<void> generateWeekMealPlan(String uid, DateTime weekStart) async {
    const mealTemplates = [
      {'name': 'Davao Pomelo Salad', 'type': 'breakfast', 'price': 45, 'cal': 220, 'protein': 4, 'carbs': 52, 'fat': 1, 'ingredients': ['Pomelo', 'Davao Honey', 'Mint Leaves', 'Lime Juice', 'Chia Seeds']},
      {'name': 'Grilled Tuna Steak', 'type': 'lunch', 'price': 90, 'cal': 480, 'protein': 45, 'carbs': 10, 'fat': 20, 'ingredients': ['Yellowfin Tuna Steak', 'Soy Sauce', 'Calamansi', 'Garlic', 'Ginger', 'Black Pepper']},
      {'name': 'Malunggay Egg Drop Soup', 'type': 'dinner', 'price': 55, 'cal': 280, 'protein': 18, 'carbs': 22, 'fat': 12, 'ingredients': ['Malunggay Leaves', 'Eggs', 'Garlic', 'Onion', 'Fish Sauce', 'Chicken Broth']},
      {'name': 'Saba Banana', 'type': 'snack', 'price': 25, 'cal': 110, 'protein': 1, 'carbs': 26, 'fat': 0, 'ingredients': ['Saba Banana', 'Glutinous Rice', 'Coconut Milk', 'Brown Sugar', 'Salt']},
      {'name': 'Durian Smoothie', 'type': 'breakfast', 'price': 60, 'cal': 310, 'protein': 5, 'carbs': 58, 'fat': 8, 'ingredients': ['Fresh Durian', 'Coconut Milk', 'Honey', 'Ice', 'Vanilla']},
      {'name': 'Bangus Sinigang', 'type': 'lunch', 'price': 85, 'cal': 420, 'protein': 38, 'carbs': 28, 'fat': 16, 'ingredients': ['Bangus (Milkfish)', 'Tamarind Powder', 'Radish', 'String Beans', 'Tomato', 'Onion', 'Water Spinach']},
      {'name': 'Tinola Manok', 'type': 'dinner', 'price': 70, 'cal': 350, 'protein': 30, 'carbs': 20, 'fat': 14, 'ingredients': ['Chicken Pieces', 'Chayote', 'Malunggay Leaves', 'Ginger', 'Onion', 'Fish Sauce', 'Rice Washing']},
    ];

    final batch = _db.batch();
    for (int d = 0; d < 7; d++) {
      final day = weekStart.add(Duration(days: d));
      final dayMeals = [0, 1, 2, 3].map((i) {
        final t = mealTemplates[(d * 4 + i) % mealTemplates.length];
        final id = _uuid.v4();
        return MealModel(
          id: id, userId: uid,
          name: t['name'] as String,
          type: MealType.values.firstWhere((e) => e.name == t['type']),
          price: (t['price'] as int).toDouble(),
          calories: t['cal'] as int,
          date: day,
          protein: t['protein'] as int,
          carbs: t['carbs'] as int,
          fat: t['fat'] as int,
          ingredients: List<String>.from(t['ingredients'] as List? ?? []),
        );
      }).toList();

      for (final meal in dayMeals) {
        batch.set(_meals(uid).doc(meal.id), meal.toMap());
      }
    }
    await batch.commit();
  }
}
