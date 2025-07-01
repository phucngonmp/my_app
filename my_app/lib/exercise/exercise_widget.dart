// Individual Exercise Widget with Timer
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_app/exercise/exercise_model.dart';
import 'package:my_app/service/firestore_service.dart';

class ExerciseWidget extends StatefulWidget {
  final String docId;
  final int exerciseIndexOnFirebase;
  final Exercise exercise;
  final int currentSet;
  final VoidCallback onCompleted;

  const ExerciseWidget({
    super.key,
    required this.docId,
    required this.exerciseIndexOnFirebase,
    required this.exercise,
    required this.currentSet,
    required this.onCompleted,
  });

  @override
  State<ExerciseWidget> createState() => _ExerciseWidgetState();
}

class _ExerciseWidgetState extends State<ExerciseWidget> {
  FirestoreService _firestoreService = FirestoreService();
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isTimerActive = false;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  @override
  void didUpdateWidget(ExerciseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise != widget.exercise ||
        oldWidget.currentSet != widget.currentSet) {
      _resetTimer();
      _initializeTimer();
    }
  }

  void _initializeTimer() {
    if (widget.exercise.seconds != null) {
      _remainingSeconds = widget.exercise.seconds!;
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _isTimerActive = false;
    setState(() {});
  }

  void _startTimer() {
    if (widget.exercise.seconds == null) return;

    setState(() {
      _isTimerActive = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isTimerActive = false;

          // Auto move to next exercise/set when timer reaches zero
          _onTimerCompleted();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerActive = false;
    });
  }

  void _onTimerCompleted() {
    _firestoreService.updateSetCompleted(
      docId: widget.docId,
      exerciseIndex: widget.exerciseIndexOnFirebase,
    );
    widget.onCompleted();
  }

  void _markAsDone() {
    _firestoreService.updateSetCompleted(
      docId: widget.docId,
      exerciseIndex: widget.exerciseIndexOnFirebase,
    );
    widget.onCompleted();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Exercise Name
          Text(
            widget.exercise.name,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Set Information
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              'Set ${widget.currentSet} of ${widget.exercise.sets}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Exercise Details
          if (widget.exercise.reps != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.repeat, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.exercise.reps} reps',
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
            ),

          // Timer Display
          if (widget.exercise.seconds != null) ...[
            const SizedBox(height: 24),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue[100],
                border: Border.all(color: Colors.blue, width: 4),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      'Exercise Time',
                      style: TextStyle(fontSize: 16, color: Colors.blue[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Control Buttons
          if (widget.exercise.seconds != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isTimerActive ? _pauseTimer : _startTimer,
                  icon: Icon(_isTimerActive ? Icons.pause : Icons.play_arrow),
                  label: Text(_isTimerActive ? 'Pause' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ] else
            // For rep-based exercises
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _markAsDone,
                icon: const Icon(Icons.check),
                label: const Text('Mark as Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
