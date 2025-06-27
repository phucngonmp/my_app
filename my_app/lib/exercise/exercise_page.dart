import 'package:flutter/material.dart';
import 'package:my_app/exercise/exercise_model.dart';
import 'package:my_app/service/firestore_service.dart';

import 'exercise_widget.dart';

class ExercisePage extends StatefulWidget {
  final List<Exercise> exercises;
  final String docId;
  final int currentSet;
  final int indexOnFirebase;

  const ExercisePage({
    super.key,
    required this.exercises,
    required this.docId,
    required this.currentSet,
    required this.indexOnFirebase,
  });

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  int _indexOnFirebase = 0;
  int _currentExerciseIndex = 0;
  int _currentSet = 0;
  late List<Exercise> _notDoneExercises;

  @override
  void initState() {
    super.initState();
    _indexOnFirebase = widget.indexOnFirebase;
    _currentSet = widget.currentSet;
    _notDoneExercises = widget.exercises;
  }

  void _onExerciseCompleted() {
    setState(() {
      // Check if all sets are completed for current exercise
      if (_currentSet >= _notDoneExercises[_currentExerciseIndex].sets) {
        // Move to next exercise
        if (widget.indexOnFirebase < _notDoneExercises.length - 1) {
          _indexOnFirebase++;
          _currentSet = 1;
          _currentExerciseIndex++;
        } else {
          // All exercises completed
          _showWorkoutCompletedDialog();
        }
      } else {
        // Move to next set
        _currentSet++;
      }
    });
  }

  void _showWorkoutCompletedDialog() {
    final FirestoreService firestoreService = FirestoreService();
    int selectedValue = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Text('🎉 ', style: TextStyle(fontSize: 24)),
                  Text(
                    'Workout Completed!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Congratulations! You\'ve completed all exercises. Great job!',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'How do you want your next workout be?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Difficulty indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Icon(
                            Icons.trending_down,
                            color: Colors.green,
                            size: 20,
                          ),
                          Text(
                            'Easier',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(
                            Icons.remove,
                            color: Colors.grey,
                            size: 20,
                          ),
                          Text(
                            'Same',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.red,
                            size: 20,
                          ),
                          Text(
                            'Harder',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Custom slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 12,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20,
                      ),
                      activeTrackColor: _getSliderColor(selectedValue),
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: _getSliderColor(selectedValue),
                      overlayColor: _getSliderColor(selectedValue).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: selectedValue.toDouble(),
                      min: -30,
                      max: 30,
                      divisions: 12,
                      onChanged: (value) {
                        setState(() {
                          selectedValue = value.round();
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Selected value display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getSliderColor(selectedValue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getSliderColor(selectedValue).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${selectedValue > 0 ? '+' : ''}$selectedValue%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getSliderColor(selectedValue),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await firestoreService.updateFeedback(
                        docId: widget.docId,
                        feedback: selectedValue,
                      );
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop({
                        'notDoneExercises': _notDoneExercises,
                      }); // Return data to previous page
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Finish Workout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Helper method to get color based on selected value
  Color _getSliderColor(int value) {
    if (value < 0) {
      return Colors.green;
    } else if (value > 0) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_notDoneExercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Workout'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('No exercises available')),
      );
    }

    final currentExercise = _notDoneExercises[_currentExerciseIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout in Progress'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              _showExerciseList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Text(
                  'Exercise ${_currentExerciseIndex + 1} of ${_notDoneExercises.length + _currentExerciseIndex}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value:
                      (_currentExerciseIndex + 1) /
                      (_notDoneExercises.length + _currentExerciseIndex),
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ),
          ),

          // Current Exercise Widget
          Expanded(
            child: ExerciseWidget(
              exerciseIndexOnFirebase: _indexOnFirebase,
              docId: widget.docId,
              exercise: currentExercise,
              currentSet: _currentSet,
              onCompleted: _onExerciseCompleted,
            ),
          ),
        ],
      ),
    );
  }

  void _showExerciseList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🔹 allows full-height scrollable sheet
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6, // Adjust as needed
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exercise List',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._notDoneExercises.asMap().entries.map((entry) {
                      int index = entry.key;
                      Exercise exercise = entry.value;
                      bool isCompleted =
                          exercise.setsCompleted >= exercise.sets;
                      bool isCurrent = index == _currentExerciseIndex;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCompleted
                              ? Colors.green
                              : isCurrent
                              ? Colors.blue
                              : Colors.grey[300],
                          child: Icon(
                            isCompleted
                                ? Icons.check
                                : isCurrent
                                ? Icons.play_arrow
                                : Icons.fitness_center,
                            color: isCompleted || isCurrent
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                        ),
                        title: Text(
                          exercise.name,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${exercise.setsCompleted}/${exercise.sets} sets completed',
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
