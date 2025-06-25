import 'package:flutter/material.dart';
import 'package:my_app/bubble widget/bubble_widget_page.dart';
import 'package:my_app/bubble%20widget/bubble_widget_overlay.dart';
import 'package:my_app/vocab/review_vocabs_page.dart';
import 'package:my_app/vocab/total_vocabs_page.dart';
import 'vocab/today_vocab_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}
// This is the overlay entry point - REQUIRED!
@pragma("vm:entry-point")
void overlayMain() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaterialApp(
    home: BubbleWidgetOverlay(),
    debugShowCheckedModeBanner: false,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocabulary Zone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Home Page
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  int getYearProgress() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year + 1, 1, 1);

    final totalDaysInYear = endOfYear.difference(startOfYear).inDays;
    final daysPassed = now.difference(startOfYear).inDays;

    return ((daysPassed / totalDaysInYear) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final yearProgress = getYearProgress();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phuc\'s Zone'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Year Progress Bar
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Year Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: yearProgress / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$yearProgress%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            buildMenuButton(context, 'Today vocabs', const TodayVocabs()),
            buildMenuButton(context, 'All vocabs', const TotalVocabs()),
            buildMenuButton(context, 'Review', const ReviewVocabs()),
            buildMenuButton(context, "Bubble Widget", const BubbleWidget())
          ],
        ),
      ),
    );
  }

  Widget buildMenuButton(BuildContext context, String label, Widget page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => page));
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18),
        ),
        child: Text(label),
      ),
    );
  }
}