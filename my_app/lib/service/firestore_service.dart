import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/service/gemini_service.dart';
import 'package:rxdart/rxdart.dart';

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

  Stream<List<QueryDocumentSnapshot>> getAllVocabulary({
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

      return query.snapshots().map((snapshot) => snapshot.docs);
    } catch (e) {
      // Return empty stream on error
      return Stream.empty();
    }
  }

  // Get today's words added today
  Stream<List<QueryDocumentSnapshot>> getTodayWords() {
    return _getWordsCreatedInNDaysAgo(days: 0);
  }

  // Get words that need review (from multiple days combined)
  Stream<List<QueryDocumentSnapshot>> getWordsForReviewStream() {
    List<int> daysAgo = [0, 1, 2, 3, 7, 14, 30, 90, 180, 365];
    return _getWordsFromMultipleDaysStream(daysAgo);
  }

  // Helper method to get words from a specific day
  Stream<List<QueryDocumentSnapshot>> _getWordsCreatedInNDaysAgo({
    required int days,
    int? limit,
  }) {
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

    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  // Helper method to combine words from multiple days
  Stream<List<QueryDocumentSnapshot>> _getWordsFromMultipleDaysStream(
      List<int> daysAgo, {
        int? limitPerDay,
      }) {
    List<Stream<List<QueryDocumentSnapshot>>> streams = daysAgo
        .map((days) => _getWordsCreatedInNDaysAgo(days: days, limit: limitPerDay))
        .toList();

    return Rx.combineLatest<List<QueryDocumentSnapshot>, List<QueryDocumentSnapshot>>(
      streams,
          (allLists) => allLists.expand((docs) => docs).toList(),
    );
  }


  Future<DocumentReference> addWordToVocab({required String word}) async {
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
        'choices': map['choices'],
      });

      return docRef;
    } catch (e) {
      rethrow;
    }
  }
  Future<void> addQuote({required String quote}) async {
    if (quote.isNotEmpty) {
      await FirebaseFirestore.instance.collection('quote').add({
        'quote': quote,
        'saveAt': FieldValue.serverTimestamp(),
      });
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
