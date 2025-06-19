import 'package:cloud_firestore/cloud_firestore.dart';

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
    return getWordsCreatedInNDaysAgo(days: 1);
  }

  Future<List<QueryDocumentSnapshot>> getWordsFromMultipleDays(List<int> daysAgo, {int? limitPerDay}) async {
    List<QueryDocumentSnapshot> allDocs = [];

    for (int days in daysAgo) {
      final docs = getWordsCreatedInNDaysAgo(days: days, limit: limitPerDay);
      allDocs.addAll(docs as Iterable<QueryDocumentSnapshot<Object?>>);
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


  // Get real-time updates for a specific document
  Stream<DocumentSnapshot> getWordById(String wordId) {
    return _firestore.collection(vocabCollection).doc(wordId).snapshots();
  }

  // Check if word exists
  Future<bool> wordExists(String word) async {
    try {
      final doc = await _firestore.collection(vocabCollection).doc(word).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Add a new word with real-time feedback
  Future<DocumentReference> addWord({
    required String word,
    required String meaning,
    String? example,
    String? type,
  }) async {
    try {
      final docRef = _firestore.collection(vocabCollection).doc(word);

      await docRef.set({
        'meaning': meaning,
        'example': example ?? '',
        'type': type ?? 'English',
        'reviewCount': 0,
        'correctCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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

  // Delete word
  Future<void> deleteWord(String wordId) async {
    try {
      await _firestore.collection(vocabCollection).doc(wordId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Batch operations for better performance
  Future<void> addMultipleWords(List<Map<String, dynamic>> words) async {
    try {
      final batch = _firestore.batch();

      for (final wordData in words) {
        final docRef = _firestore.collection(vocabCollection).doc(wordData['word']);
        final data = Map<String, dynamic>.from(wordData);
        data.remove('word'); // Remove word from data as it's used as document ID
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        data['reviewCount'] = 0;
        data['correctCount'] = 0;
        data['lastReviewed'] = null;

        batch.set(docRef, data);
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Search words by text (requires proper indexing in Firestore)
  Stream<QuerySnapshot> searchWords(String searchTerm) {
    if (searchTerm.isEmpty) {
      return getAllVocabulary();
    }

    return _firestore
        .collection(vocabCollection)
        .where('meaning', isGreaterThanOrEqualTo: searchTerm)
        .where('meaning', isLessThanOrEqualTo: '$searchTerm\uf8ff')
        .snapshots();
  }

  // Get words by difficulty level
  Stream<QuerySnapshot> getWordsByDifficulty(String difficulty) {
    return _firestore
        .collection(vocabCollection)
        .where('difficulty', isEqualTo: difficulty)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get words that need review (haven't been reviewed recently)
  Stream<QuerySnapshot> getWordsForReview({int daysSinceLastReview = 1}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysSinceLastReview));

    return _firestore
        .collection(vocabCollection)
        .where('lastReviewed', isLessThan: cutoffDate)
        .orderBy('lastReviewed')
        .snapshots();
  }

  // Get statistics
  Future<Map<String, int>> getVocabularyStats() async {
    try {
      final snapshot = await _firestore.collection(vocabCollection).get();
      final docs = snapshot.docs;

      int totalWords = docs.length;
      int reviewedWords = 0;
      int masteredWords = 0;

      for (final doc in docs) {
        final data = doc.data();
        final reviewCount = data['reviewCount'] ?? 0;
        final correctCount = data['correctCount'] ?? 0;

        if (reviewCount > 0) {
          reviewedWords++;

          // Consider a word "mastered" if reviewed at least 3 times with 80%+ accuracy
          if (reviewCount >= 3 && (correctCount / reviewCount) >= 0.8) {
            masteredWords++;
          }
        }
      }

      return {
        'total': totalWords,
        'reviewed': reviewedWords,
        'mastered': masteredWords,
        'unreviewed': totalWords - reviewedWords,
      };
    } catch (e) {
      return {
        'total': 0,
        'reviewed': 0,
        'mastered': 0,
        'unreviewed': 0,
      };
    }
  }

  // Listen to connection state changes
  Stream<bool> get connectionState {
    return _firestore.doc('.info/connected').snapshots().map((snapshot) {
      return snapshot.exists && snapshot.data()?['connected'] == true;
    });
  }

}