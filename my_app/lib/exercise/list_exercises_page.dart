import 'package:flutter/material.dart';
import 'package:my_app/exercise/exercise_model.dart';
import 'package:my_app/exercise/exercise_page.dart';
import 'package:my_app/service/firestore_service.dart';
import 'package:table_calendar/table_calendar.dart';

class ListExercisesPage extends StatefulWidget {
  const ListExercisesPage({super.key});

  @override
  State<ListExercisesPage> createState() => _ListExercisesPageState();
}

class _ListExercisesPageState extends State<ListExercisesPage> {
  final FirestoreService firestoreService = FirestoreService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isCreatingRoutine = false;

  // Add a key to force FutureBuilder to rebuild
  Key _futureBuilderKey = UniqueKey();

  // Get exercises for the selected day (or today if no day is selected)
  Future<List<Exercise>> _getExercisesForDay() async {
    final targetDate = _selectedDay ?? DateTime.now();

    // Check if it's Saturday (weekday 6 in Dart)
    if (targetDate.weekday == DateTime.saturday) {
      // Return empty list for Saturday (Rest Day)
      return [];
    }

    return await firestoreService.getExercisesOfDate(date: targetDate);
  }

  // Check if selected date is Saturday
  bool get _isRestDay {
    final targetDate = _selectedDay ?? DateTime.now();
    return targetDate.weekday == DateTime.saturday;
  }

  // Method to refresh the exercise list
  void _refreshExercises() {
    setState(() {
      _futureBuilderKey = UniqueKey(); // This will force FutureBuilder to rebuild
    });
  }

  void createExercises() async {
    setState(() {
      _isCreatingRoutine = true; // Start loading
    });

    try {
      final date = _selectedDay ?? DateTime.now();
      await firestoreService.addExercisesOfDate(date: date);

      // Trigger a rebuild to refresh the FutureBuilder
      setState(() {
        _isCreatingRoutine = false; // Stop loading
        _futureBuilderKey = UniqueKey(); // Force refresh
      });
    } catch (e) {
      // Handle error
      setState(() {
        _isCreatingRoutine = false; // Stop loading even on error
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create routine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStartButton(bool isStartButtonEnabled) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 80),
      child: _isRestDay
          ? Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          "Enjoy your rest day! 🌟",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green[600],
          ),
          textAlign: TextAlign.center,
        ),
      )
          : isStartButtonEnabled
          ? ElevatedButton(
        onPressed: () async {
          DateTime date = _selectedDay ?? DateTime.now();
          final exercises = await firestoreService.getNotDoneExercisesOfDate(date: date);
          final currentSet = exercises[0].setsCompleted + 1;
          print('exercises[0].index:' + exercises[0].index.toString());
          // Navigate to ExercisePage and wait for result
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExercisePage(
                docId: firestoreService.convertToWorkoutDocId(date: date),
                exercises: exercises,
                currentSet: currentSet,
                indexOnFirebase: exercises[0].index
              ),
            ),
          );

          // Refresh the exercise list when returning from workout page
          // This will happen regardless of the result
          _refreshExercises();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          "Start Workout",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : Container(),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Workout Progress"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Add refresh button in app bar
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshExercises,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar Section
          Container(
            color: Colors.white,
            child: TableCalendar<Exercise>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _futureBuilderKey = UniqueKey(); // Refresh when day changes
                });
              },
              calendarFormat: CalendarFormat.week,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: FutureBuilder<List<Exercise>>(
                key: _futureBuilderKey, // This key forces rebuild when changed
                future: _getExercisesForDay(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        _buildStartButton(false), // Show disabled button while loading
                      ],
                    );
                  }

                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading exercises',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _refreshExercises,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text("Retry"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildStartButton(false), // Show disabled button on error
                      ],
                    );
                  }

                  final exercises = snapshot.data ?? [];
                  final bool isStartButtonEnabled = exercises.isNotEmpty;

                  if (exercises.isEmpty) {
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Show loading animation when creating routine
                                if (_isCreatingRoutine) ...[
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Creating your routine...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please wait while we set up your exercises',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ] else if (_isRestDay) ...[
                                  // Show rest day message for Saturday
                                  Icon(Icons.spa, size: 64, color: Colors.green[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Rest Day',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Take a break and let your muscles recover',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Recovery Tips:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '• Stay hydrated\n• Get enough sleep\n• Light stretching\n• Gentle walks',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // Show normal empty state
                                  Icon(
                                    Icons.fitness_center,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No exercises found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No workout planned for today',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: createExercises,
                                    icon: const Icon(Icons.add),
                                    label: const Text("Create Now"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        _buildStartButton(isStartButtonEnabled), // Pass the calculated value
                      ],
                    );
                  }

                  // Show exercises list
                  return Column(
                    children: [
                      // Add pull-to-refresh functionality
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            _refreshExercises();
                            // Wait a bit for the refresh to complete
                            await Future.delayed(const Duration(milliseconds: 500));
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: exercises.length,
                            itemBuilder: (context, index) {
                              final exercise = exercises[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                    (exercise.setsCompleted == exercise.sets)
                                        ? Colors.green
                                        : Colors.grey[300],
                                    child: Icon(
                                      (exercise.setsCompleted == exercise.sets)
                                          ? Icons.check
                                          : Icons.fitness_center,
                                      color: (exercise.setsCompleted == exercise.sets)
                                          ? Colors.white
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  title: Text(
                                    exercise.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration:
                                      (exercise.setsCompleted == exercise.sets)
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.seconds != null
                                            ? "${exercise.sets} sets × ${exercise.seconds}s"
                                            : "${exercise.sets} sets × ${exercise.reps} reps",
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Progress: ${exercise.setsCompleted}/${exercise.sets} sets",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: (exercise.setsCompleted == exercise.sets)
                                              ? Colors.green[600]
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: (exercise.setsCompleted == exercise.sets)
                                      ? const Icon(Icons.done, color: Colors.green)
                                      : CircularProgressIndicator(
                                    value: exercise.setsCompleted / exercise.sets,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      _buildStartButton(isStartButtonEnabled), // Pass the calculated value
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}