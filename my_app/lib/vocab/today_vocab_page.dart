import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_app/service/firestore_service.dart';

class TodayVocabs extends StatefulWidget {
  const TodayVocabs({super.key});

  @override
  State<TodayVocabs> createState() => _TodayVocabsState();
}

class _TodayVocabsState extends State<TodayVocabs> {
  final PageController _pageController = PageController();
  late Stream<QuerySnapshot> _wordsStream;

  @override
  void initState() {
    super.initState();
    // Initialize stream once to avoid recreating it on every build
    final FirestoreService firestore = FirestoreService();
    _wordsStream = firestore.getTodayWords();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today Words"),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _wordsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No words found."),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              // Progress indicator
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Word ${(_pageController.hasClients ? _pageController.page?.round() ?? 0 : 0) + 1} of ${docs.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              // Flashcards
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return FlashcardWidget(
                      key: ValueKey(doc.id),
                      document: doc,
                      onUpdate: _refreshData, // Callback for manual refresh
                    );
                  },
                ),
              ),
              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _previousCard,
                      child: const Text('Previous'),
                    ),
                    ElevatedButton(
                      onPressed: _nextCard,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _refreshData() {
    setState(() {
      // Trigger rebuild to refresh stream
      final FirestoreService firestore = FirestoreService();
      _wordsStream = firestore.getCollection("vocab").snapshots();
    });
  }

  void _previousCard() {
    if (_pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextCard() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}


class FlashcardWidget extends StatefulWidget {
  final DocumentSnapshot document;
  final VoidCallback? onUpdate;

  const FlashcardWidget({
    super.key,
    required this.document,
    this.onUpdate,
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with AutomaticKeepAliveClientMixin {
  bool showMeaning = false;

  @override
  bool get wantKeepAlive => true; // Keep state when scrolling

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final word = widget.document.id;
    final data = widget.document.data() as Map<String, dynamic>?;

    if (data == null) {
      return const Center(
        child: Text('Invalid word data'),
      );
    }

    return Center(
      child: GestureDetector(
        onTap: _toggleMeaning,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Card(
            elevation: showMeaning ? 15 : 10,
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 100),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: showMeaning
                    ? LinearGradient(
                  colors: [Colors.blue.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        word,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: showMeaning
                            ? _buildMeaningContent(data)
                            : _buildTapHint(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeaningContent(Map<String, dynamic> data) {
    return Column(
      key: const ValueKey('meaning'),
      children: [
        Text(
          data['meaning'] ?? 'No meaning available',
          style: const TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (data['example'] != null && data['example'].toString().isNotEmpty)
          Text(
            data['example'],
            style: TextStyle(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        // Additional fields if available
      ],
    );
  }

  Widget _buildTapHint() {
    return const Column(
      key: ValueKey('hint'),
      children: [
        Icon(
          Icons.touch_app,
          size: 40,
          color: Colors.grey,
        ),
        SizedBox(height: 8),
        Text(
          "(Tap to reveal)",
          style: TextStyle(
            fontSize: 20,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _toggleMeaning() {
    setState(() {
      showMeaning = !showMeaning;
    });
  }
}

