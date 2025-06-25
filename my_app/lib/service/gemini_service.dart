import 'package:flutter_gemini/flutter_gemini.dart';
import 'dart:convert';

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


  Future<String> generateExplanation(String text) async{
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
