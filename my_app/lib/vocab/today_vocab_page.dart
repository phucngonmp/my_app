import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_app/service/firestore_service.dart';

class TodayVocabs extends StatefulWidget {
  const TodayVocabs({super.key});

  @override
  State<TodayVocabs> createState() => _TodayVocabsState();
}

class _TodayVocabsState extends State<TodayVocabs> {
  int _index = 0;
  final FirestoreService firestore = FirestoreService();
  bool _isTodayWord = true;
  final PageController _pageController = PageController();
  late Stream<List<QueryDocumentSnapshot>> _wordsStream;
  int _totalWords = 0; // Track total words

  @override
  void initState() {
    super.initState();
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
        title: Text(_isTodayWord ? "Today Words" : "Review Words"),
        actions: [
          IconButton(
              onPressed: _switchWordsMode,
              icon: const Icon(Icons.swap_horiz_rounded)
          ),
        ],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
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
                    onPressed: _switchWordsMode,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.book, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_isTodayWord
                      ? "No words added today."
                      : "No words to review."),
                ],
              ),
            );
          }

          final docs = snapshot.data!;
          _totalWords = docs.length;

          // Reset index if it's out of bounds
          if (_index >= _totalWords) {
            _index = 0;
          }

          return Column(
            children: [
              // Progress indicator
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Word ${_index + 1} of ${docs.length}', // Display as 1-based
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              // Flashcards
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: docs.length,
                  onPageChanged: (index) {
                    setState(() {
                      _index = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return FlashcardWidget(
                      key: ValueKey(doc.id),
                      document: doc,
                      onUpdate: _switchWordsMode,
                    );
                  },
                ),
              ),
              // Navigation buttons with proper spacing
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _index > 0 ? _previousCard : null, // Disable if at first card
                        child: const Text('Previous'),
                      ),
                      ElevatedButton(
                        onPressed: _index < _totalWords - 1 ? _nextCard : null, // Disable if at last card
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _switchWordsMode() {
    setState(() {
      _isTodayWord = !_isTodayWord;
      _index = 0; // Reset to first card when switching modes
      _wordsStream = _isTodayWord
          ? firestore.getTodayWords()
          : firestore.getWordsForReviewStream();

      // Reset PageController to first page
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _previousCard() {
    if (_pageController.hasClients && _index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // Note: _index will be updated by onPageChanged callback
    }
  }

  void _nextCard() {
    if (_pageController.hasClients && _index < _totalWords - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // Note: _index will be updated by onPageChanged callback
    }
  }
}

class FlashcardWidget extends StatefulWidget {
  final DocumentSnapshot document;
  final VoidCallback? onUpdate;

  const FlashcardWidget({super.key, required this.document, this.onUpdate});

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
      return const Center(child: Text('Invalid word data'));
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
        Icon(Icons.touch_app, size: 40, color: Colors.grey),
        SizedBox(height: 8),
        Text(
          "(Tap to reveal)",
          style: TextStyle(fontSize: 20, color: Colors.grey),
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