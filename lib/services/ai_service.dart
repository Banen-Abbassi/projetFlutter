import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  final String apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? "";

  Future<String> askAI(String message) async {
    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": "meta-llama/llama-3.1-8b-instruct",
        "messages": [
          {"role": "system", "content": "Tu es un assistant gentil et utile."},
          {"role": "user", "content": message},
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"];
    } else {
      return "Erreur IA : ${response.body}";
    }
  }
}
