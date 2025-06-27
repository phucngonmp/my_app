import 'package:flutter_gemini/flutter_gemini.dart';
import 'dart:convert';

import 'package:my_app/service/firestore_service.dart';

const apiKey = 'AIzaSyD8DwI5G3w0JpmHDxo33qpxA1PZ-3ZeRrs';

class GeminiService {
  late final Gemini _gemini;

  // Singleton pattern
  static GeminiService? _instance;

  // Private constructor
  GeminiService._() {
    Gemini.init(apiKey: apiKey);
    _gemini = Gemini.instance;
  }

  // Factory constructor for singleton
  factory GeminiService() {
    _instance ??= GeminiService._();
    return _instance!;
  }

  // Getter for the Gemini instance
  Gemini get instance => _gemini;

  Future<Map<String, dynamic>> generateWorkOutList({required DateTime date}) async {
    final FirestoreService firestoreService = FirestoreService();
    String previousData = await firestoreService.getPreviousDataOfWorkOut(date: date);
    String type = _getTypeOfWorkOut(date);
    final prompt =
        '''
    Generate a home workout routine for me. I have a pull-up bar and dumbbells.
    here my average statistics: plank 50s, push up 25+, pull up 5+, burpee 15+
    The workout must:
      - Last approximately 30 to 40 minutes
      - Focus on $type
    
    Use this previous routine for reference and adjust the workout to suit my current level: $previousData
    And use the feedback in the previous workout to adjust this routine. for example: if feedback: -20 then make it
    easier 20%
    Return the result strictly as a **valid JSON object**.
    
    The JSON object must contain:
    - A key `"exercises"`: a list of exercises
    - A key `"feedback"`: set to the default value `0` (integer)
    
    Each exercise object in the list must include 5 fields only:
    - `"index"`: starts from 0 and increments for each exercise (integer)
    - `"name"`: a short string (e.g., "Push-ups")
    - `"sets"`: an **integer only**, not a string
    - `"reps"` OR `"seconds"`: must be a **whole number as an integer**. Do not use text like "As many as possible"
    - `"setsCompleted"`: always `0` (integer)
    
    ⚠️ Important:
    - All numeric fields (`sets`, `reps`, `seconds`, `setsCompleted`) must be strictly formatted as integers (e.g., `10`, not `"10"`).
    - Do NOT return any value as a string where a number is expected.

    ''';
    print(prompt);
    try {
      final response = await Gemini.instance.prompt(parts: [Part.text(prompt)]);
      print(response?.output);
      final String? output = _cleanResponseText(response?.output);
      print(output);

      if (output == null || output.isEmpty) {
        throw Exception("Empty response from Gemini");
      }

      final Map<String, dynamic> json = jsonDecode(output);
      return json;
    } catch (e) {
      print("Error generating word data: $e");
      throw Exception("Empty response from Gemini");
    }
  }

  String _getTypeOfWorkOut(DateTime date) {
    const days = [
      'Legs + Abs',
      'Chest + Cardio',
      'Back + Biceps',
      'Cardio',
      'Shoulder + Abs',
      'Rest',
      'Full Body + Cardio',
    ];
    return days[date.weekday - 1];
  }

  Future<String> generateExplanation(String text) async {
    final prompt = 'giải thích khái niệm:  $text đơn giản và ví dụ';
    final response = await Gemini.instance.prompt(parts: [Part.text(prompt)]);
    return response?.output ?? '';
  }

  Future<Map<String, dynamic>> generateWordData(String word) async {
    final prompt =
        '''
        You will receive an input which may be a single word or a phrase in English or Japanese. Return a valid JSON object with the following fields:
          - "example": A natural sentence using the input phrase in its original language.
          - "meaning": The meaning of the input phrase translated into Vietnamese if words is English, into English if words is Japanese (not the meaning of the example).
          - "type": Either "English" or "Japanese" — the language of the input phrase.
          - "question": A multiple-choice question testing the user's meaning of the input phrase.
          - "choices": An array of 4 choices (strings). If the input is English, choices should be in Vietnamese. If the input is Japanese, choices should be in English.
          - "correctIndex": The index (0–3) of the correct answer inside the "choices" array.
        Only respond with a valid JSON object. Do not add explanations, extra text, or formatting.
        Let's start with the input: $word
        ''';
    try {
      final response = await Gemini.instance.prompt(parts: [Part.text(prompt)]);
      final String? output = _cleanResponseText(response?.output);
      if (output == null || output.isEmpty) {
        throw Exception("Empty response from Gemini");
      }

      final Map<String, dynamic> json = jsonDecode(output);
      return json;
    } catch (e) {
      print("Error generating word data: $e");
      throw Exception("Empty response from Gemini");
    }
  }

  String _cleanResponseText(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .replaceAll('`', '')
        .trim();
  }
}
