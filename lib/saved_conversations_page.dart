import 'package:flutter/material.dart';
import 'database_helper.dart';

class SavedConversationsPage extends StatelessWidget {
  const SavedConversationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Conversations'),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: DatabaseHelper().getConversations(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data!;
          if (conversations.isEmpty) {
            return const Center(child: Text('No saved conversations.'));
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return ListTile(
                title: Text('User: ${conversation['user']}'),
                subtitle: Text('ChatGPT: ${conversation['chatgpt']}'),
              );
            },
          );
        },
      ),
    );
  }
}