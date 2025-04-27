import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

// Deinen OpenAI API Key hier eintragen
final String openAiApiKey = dotenv.dotenv.env['OPENAI_API_KEY'] ?? '';

Future<Response> handleRequest(Request request) async {
  if (request.method == 'OPTIONS') {
    return Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
  }

  if (request.method != 'POST') {
    return Response.notFound('Nur POST erlaubt');
  }

  try {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    final prompt = data['prompt'] ?? '';
    final base64Image = data['image'];

    final systemMessage = 
      "You are a helpful assistant that describes images accurately and gives direct, factual responses without hallucinating.";

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final userContent = [
      {
        'type': 'text',
        'text': prompt.isNotEmpty ? prompt : 'Please describe what you see in this image.',
      },
      if (base64Image != null)
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$base64Image',
          }
        }
    ];

    final requestPayload = {
      'model': 'gpt-4o',
      'messages': [
        {
          'role': 'system',
          'content': systemMessage,
        },
        {
          'role': 'user',
          'content': userContent,
        },
      ],

      'max_tokens': 300,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $openAiApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestPayload),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      final reply = result['choices'][0]['message']['content'];
      return Response.ok(
        jsonEncode({'response': reply}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } else {
      print('🔴 Fehler von OpenAI API: ${response.statusCode}');
      print('🔴 Antwort: ${response.body}');
      return Response.internalServerError(body: 'Fehler bei OpenAI: ${response.body}');
    }
  } catch (e) {
    print('🔴 Ausnahmefehler: $e');
    return Response.internalServerError(body: 'Exception: $e');
  }
}

void main() async {
  await dotenv.dotenv.load(fileName: '.env');
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(handleRequest);

  final server = await io.serve(handler, 'localhost', 8080);
  print('✅ Server läuft auf http://${server.address.host}:${server.port}');
}