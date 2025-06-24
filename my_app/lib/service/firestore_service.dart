import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/service/gemini_service.dart';


const apiKey = 'AIzaSyD8DwI5G3w0JpmHDxo33qpxA1PZ-3ZeRrs';

class FirestoreService {
  late final FirebaseFirestore _firestore;

  // Singleton pattern
  static FirestoreService? _instance;

  // Private constructor
  FirestoreService._() {
    _firestore = FirebaseFirestore.instance;
  }

  // Factory constructor for singleton
  factory FirestoreService() {
    _instance ??= FirestoreService._();
    return _instance!;
  }

  // Getter for the Firestore instance
  FirebaseFirestore get instance => _firestore;


  static const String vocabCollection = 'vocab';

  // Get collection reference (for your existing code compatibility)
  CollectionReference getCollection(String collectionName) {
    return _firestore.collection(collectionName);
  }

  // Get real-time updates for vocabulary with optional filters
  Stream<QuerySnapshot> getAllVocabulary({
    int? limit,
    String? orderBy,
    bool descending = false,
    DateTime? createdAfter,
    String? type,
  }) {
    try {
      Query query = _firestore.collection(vocabCollection);
      if (createdAfter != null) {
        query = query.where('createdAt', isGreaterThan: createdAfter);
      }
      if (type != null && type.isNotEmpty) {
        query = query.where('type', isEqualTo: type);
      }
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      if (limit != null) {
        query = query.limit(limit);
      }

      return query.snapshots();
    } catch (e) {
      // Return empty stream on error
      return const Stream.empty();
    }
  }

  // Get today's words added today or need to review
  Stream<QuerySnapshot> getTodayWords() {
    return getWordsCreatedInNDaysAgo(days: 0);
  }

  // Get words that need review (haven't been reviewed recently)
  Future<List<QueryDocumentSnapshot>> getWordsForReview() async {
    List<int> days = [0, 1, 2, 3, 4, 5, 6, 7, 14, 30, 90, 180, 365];
    return await getWordsFromMultipleDays(days);
  }

  Future<List<QueryDocumentSnapshot>> getWordsFromMultipleDays(List<int> daysAgo, {int? limitPerDay}) async {
    List<QueryDocumentSnapshot> allDocs = [];

    for (int days in daysAgo) {
      final snapshot = await getWordsCreatedInNDaysAgo(days: days, limit: limitPerDay).first; // ✅ wait for stream
      allDocs.addAll(snapshot.docs);
    }

    return allDocs;
  }


  Stream<QuerySnapshot> getWordsCreatedInNDaysAgo({required int days, int? limit}) {
    final targetDate = DateTime.now().subtract(Duration(days: days));
    final start = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final end = start.add(Duration(days: 1));

    Query query = _firestore
        .collection(vocabCollection)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }


  // Add a new word with real-time feedback
  Future<DocumentReference> addWordToVocab({
    required String word,
  }) async {
    final geminiService = GeminiService();
    final map = await geminiService.generateWordData(word);
    try {
      final docRef = _firestore.collection(vocabCollection).doc(word);

      await docRef.set({
        'meaning': map['meaning'],
        'example': map['example'] ?? '',
        'type': map['type'],
        'createAt': FieldValue.serverTimestamp(),
        'question': map['question'],
        'correctIndex': map['correctIndex'],
        'choices' : map['choices']
      });

      return docRef;
    } catch (e) {
      rethrow;
    }
  }

  // Update word with real-time sync
  Future<void> updateWord(String wordId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(vocabCollection).doc(wordId).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  // Update word review statistics
  Future<void> updateWordReview(String wordId, bool wasCorrect) async {
    try {
      final docRef = _firestore.collection(vocabCollection).doc(wordId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final reviewCount = (data['reviewCount'] ?? 0) + 1;
        final correctCount = (data['correctCount'] ?? 0) + (wasCorrect ? 1 : 0);

        transaction.update(docRef, {
          'reviewCount': reviewCount,
          'correctCount': correctCount,
          'lastReviewed': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      rethrow;
    }
  }




}