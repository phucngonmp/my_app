import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/exercise/exercise_model.dart';
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

  Future<void> addToGoodStuff({required String content}) async {
    if (content.isNotEmpty) {
      await FirebaseFirestore.instance.collection('good_stuff').add({
        'content': content,
        'saveAt': FieldValue.serverTimestamp(),
      });
    }
  }
  Future<DocumentReference> addWordToVocab({required String word}) async {
    final geminiService = GeminiService();
    final map = await geminiService.generateWordData(word);
    try {
      final docRef = _firestore.collection(vocabCollection).doc(word);
      List<dynamic> jsonList = map['exercises'];
      List<Exercise> exercises = jsonList.map((e) => Exercise.fromJson(e)).toList();
      await docRef.set({
        'exercises' : exercises
      });

      return docRef;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateFeedback({required String docId, required int feedback}) async{
    final docRef = _firestore.collection('workout').doc(docId);
    final docSnapshot = await docRef.get();
    if(docSnapshot.exists){
      await docRef.update({'feedback' : feedback});
    }
  }

  Future<void> updateSetCompleted({
    required String docId,
    required int exerciseIndex,
  }) async {
    final docRef = _firestore.collection('workout').doc(docId);

    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final exercises = List<Map<String, dynamic>>.from(data['exercises']);

      final current = exercises[exerciseIndex]['setsCompleted'] ?? 0;
      final totalSets = exercises[exerciseIndex]['sets'] ?? 0;

      if (current < totalSets) {
        exercises[exerciseIndex]['setsCompleted'] = current + 1;
      }
      await docRef.update({
        'exercises': exercises,
      });
    }
  }


  Future<DocumentReference> addExercisesOfDate({required DateTime date}) async {
    final geminiService = GeminiService();
    final map = await geminiService.generateWorkOutList(date: date);
    final docId = convertToWorkoutDocId(date: date);
    try {
      final docRef = _firestore.collection('workout').doc(docId);

      await docRef.set({
        'exercises': map['exercises'],
        'feedback': map['feedback']
      });

      return docRef;
    } catch (e) {
      rethrow;
    }
  }
  Future<List<Exercise>> getNotDoneExercisesOfDate({required DateTime date}) async {
    final docId = convertToWorkoutDocId(date: date);

    final docSnapshot = await _firestore.collection('workout').doc(docId).get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final exercisesJson = data['exercises'] as List<dynamic>;

      return exercisesJson
          .map((json) => Exercise.fromJson(json as Map<String, dynamic>))
          .where((exercise) => exercise.setsCompleted < exercise.sets)
          .toList();
    }
    return [];
  }
  

  Future<List<Exercise>> getExercisesOfDate({required DateTime date}) async {
    final docId = convertToWorkoutDocId(date: date);

    final docSnapshot = await _firestore.collection('workout').doc(docId).get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final exercisesJson = data['exercises'] as List<dynamic>;

      return exercisesJson
          .map((json) => Exercise.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }


  Future<String> getPreviousDataOfWorkOut({required DateTime date}) async{
    final previousDocId = convertToWorkoutDocId(date: date.subtract(Duration(days: 7)));

    DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
        .collection('workout')
        .doc(previousDocId)
        .get();

    if(docSnapshot.exists){
      final data = docSnapshot.data() as Map<String, dynamic>;
      print("here");
      final exercises = data['exercises'] as List<dynamic>;
      final feedback = data['feedback'];
      // Convert each exercise map into a formatted string
      List<String> formattedList = exercises.map((exercise) {
        final name = exercise['name'];
        final sets = exercise['sets'];
        final setsCompleted = exercise['setsCompleted'];


        final reps = exercise['reps'];
        final seconds = exercise['seconds'];

        final details = (reps == null)
            ? '${seconds.toString()} seconds'
            : '${reps.toString()} reps';

        return '$name: $sets sets x $details [done: $setsCompleted/$sets]';
      }).toList();
      return formattedList.join('\n') + '| feedback: ${feedback}';
    }
    return "No data";
  }

  String convertToWorkoutDocId({required DateTime date}){
    String dateString = '${date.day.toString().padLeft(2, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.year}';
    return dateString;
  }
}
