import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  // Speichere Konversation (Web oder Desktop)
  Future<void> saveConversation(String userInput, String chatGPTResponse) async {
    if (kIsWeb) {
      // Web: Speichere in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final conversations = prefs.getStringList('conversations') ?? [];
      conversations.add(jsonEncode({'user': userInput, 'chatgpt': chatGPTResponse}));
      await prefs.setStringList('conversations', conversations);
    } else {
      // Desktop: Speichere in SQLite
      final db = await _getDatabase();
      await db.insert('conversations', {
        'userInput': userInput,
        'chatGPTResponse': chatGPTResponse,
      });
    }
  }

  // Lade Konversationen (Web oder Desktop)
  Future<List<Map<String, String>>> getConversations() async {
    if (kIsWeb) {
      // Web: Lade aus SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final conversations = prefs.getStringList('conversations') ?? [];
      return conversations
          .map((e) => Map<String, String>.from(jsonDecode(e)))
          .toList();
    } else {
      // Desktop: Lade aus SQLite
      final db = await _getDatabase();
      final result = await db.query('conversations', orderBy: 'id DESC');
      return result.map((e) => {
            'user': e['userInput'] as String,
            'chatgpt': e['chatGPTResponse'] as String,
          }).toList();
    }
  }

  // SQLite-Datenbank initialisieren (nur für Desktop)
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'conversations.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userInput TEXT,
            chatGPTResponse TEXT
          )
        ''');
      },
    );
    return _database!;
  }
}