import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_app/service/firestore_service.dart';

class ReviewVocabs extends StatefulWidget {
  const ReviewVocabs({super.key});

  @override
  State<ReviewVocabs> createState() => _ReviewVocabState();
}

class _ReviewVocabState extends State<ReviewVocabs> {
  late Future<List<QueryDocumentSnapshot>> futureAllDocs;
  List<QueryDocumentSnapshot> allDocs = [];
  int currentQuestionIndex = 0;
  int? selectedAnswerIndex;
  bool showResult = false;
  bool isCorrect = false;
  int correctAnswers = 0;
  int totalQuestions = 0;
  bool quizCompleted = false;

  @override
  void initState() {
    super.initState();
    final FirestoreService firestoreService = FirestoreService();
    futureAllDocs = firestoreService.getWordsForReview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Review'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (allDocs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${currentQuestionIndex + 1}/${allDocs.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder(
        future: futureAllDocs,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyWidget();
          }

          // Initialize docs only once
          if (allDocs.isEmpty) {
            allDocs = snapshot.data!.toList();
            allDocs.shuffle();
            totalQuestions = allDocs.length;
          }

          if (quizCompleted) {
            return _buildCompletionWidget();
          }

          return _buildQuizWidget();
        },
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading questions: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No vocabulary words found for review.'),
        ],
      ),
    );
  }

  Widget _buildQuizWidget() {
    final currentDoc = allDocs[currentQuestionIndex];
    final currentData = currentDoc.data() as Map<String, dynamic>;

    // Extract data from Firebase document
    final questionText = currentData['question'] as String? ?? 'What does this word mean?';
    final choices = List<String>.from(currentData['choices'] as List? ?? []);
    final correctIndex = currentData['correctIndex'] as int? ?? 0;
    final example = currentData['example'] as String? ?? '';

    // Fallback if no choices available
    if (choices.isEmpty) {
      return const Center(
        child: Text('No choices available for this question.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (currentQuestionIndex + 1) / allDocs.length,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
          const SizedBox(height: 20),

          // Score display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Score: $correctAnswers / $totalQuestions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),

          // Question
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  questionText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (example.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Example: $example',
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Options
          Expanded(
            child: ListView.builder(
              itemCount: choices.length,
              itemBuilder: (context, index) {
                return _buildOptionButton(index, choices[index], correctIndex);
              },
            ),
          ),

          // Action buttons
          if (showResult) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      currentQuestionIndex == allDocs.length - 1 ? 'Finish' : 'Next',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionButton(int index, String option, int correctIndex) {
    Color? backgroundColor;
    Color? textColor;
    IconData? icon;

    if (showResult) {
      if (index == correctIndex) {
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
      } else if (selectedAnswerIndex == index) {
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.cancel;
      }
    } else if (selectedAnswerIndex == index) {
      backgroundColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: showResult ? null : () => _selectAnswer(index, correctIndex),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white,
          foregroundColor: textColor ?? Colors.black87,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: backgroundColor != null ? Colors.transparent : Colors.grey.shade300,
            ),
          ),
          elevation: showResult ? 0 : 2,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: backgroundColor?.withOpacity(0.3) ?? Colors.grey.shade200,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 20, color: textColor)
                    : Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor ?? Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionWidget() {
    final percentage = (correctAnswers / totalQuestions * 100).round();
    String message;
    Color color;
    IconData icon;

    if (percentage >= 80) {
      message = 'Excellent work!';
      color = Colors.green;
      icon = Icons.star;
    } else if (percentage >= 60) {
      message = 'Good job!';
      color = Colors.blue;
      icon = Icons.thumb_up;
    } else {
      message = 'Keep practicing!';
      color = Colors.orange;
      icon = Icons.school;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You scored $correctAnswers out of $totalQuestions',
              style: const TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '($percentage%)',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _restartQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Review Again', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Home', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAnswer(int selectedIndex, int correctIndex) {
    setState(() {
      selectedAnswerIndex = selectedIndex;
      showResult = true;
      isCorrect = selectedIndex == correctIndex;
      if (isCorrect) {
        correctAnswers++;
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < allDocs.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswerIndex = null;
        showResult = false;
        isCorrect = false;
      });
    } else {
      setState(() {
        quizCompleted = true;
      });
    }
  }

  void _retryQuestion() {
    setState(() {
      selectedAnswerIndex = null;
      showResult = false;
      isCorrect = false;
    });
  }

  void _restartQuiz() {
    setState(() {
      currentQuestionIndex = 0;
      selectedAnswerIndex = null;
      showResult = false;
      isCorrect = false;
      correctAnswers = 0;
      quizCompleted = false;
      allDocs.shuffle(); // Shuffle for variety
    });
  }
}