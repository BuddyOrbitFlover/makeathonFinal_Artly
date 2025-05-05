import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'saved_conversations_page.dart';


void main() => runApp(const CritiqueApp());

/* ────────── APP ROOT ────────── */

class CritiqueApp extends StatelessWidget {
  const CritiqueApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: Colors.black,
            secondary: Colors.black,
            surface: Colors.black,
            background: Colors.black,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.white,
            onBackground: Colors.white,
          ),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[800]!.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.deepPurple, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ),
        home: const SplashLogo(), // Set SplashLogo as the home screen
      );
}

/* ────────── SPLASH ────────── */

class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const MainPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(
                    position: offsetAnimation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 1000),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/startingIcon.png', height: 320),
              ],
            ),
          ),
        ),
      );
}


class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String _responseText = '';
  bool _loading = false;
  Uint8List? _currentImage;
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> _conversationHistory = [];
  bool _isDragging = false;
  double _imageHeight = 400.0;
  double _assistantImageHeight = 500.0;
  bool _showAssistantNextToTitle = false;
  double _assistantImageWidth = 500.0;
  List<Map<String, dynamic>> _referenceImages = [];

  @override
  void initState() {
    super.initState();
    _imageHeight = 400.0;
    _assistantImageHeight = 500.0;
    _assistantImageWidth = 500.0;
    _showAssistantNextToTitle = false;
  }

  void _updateImageHeights() {
    setState(() {
      if (_conversationHistory.isEmpty) {
        _imageHeight = 400.0;
        _assistantImageHeight = 500.0;
        _assistantImageWidth = 500.0;
        _showAssistantNextToTitle = false;
      } else {
        _imageHeight = 200.0;
        _assistantImageHeight = 400.0;
        _assistantImageWidth = 400.0;
        _showAssistantNextToTitle = true;
      }
    });
  }

  // Send prompt and image to the backend
  Future<void> _sendToChatGPT() async {
    final input = _textController.text;
    if (input.isEmpty && _currentImage == null) return;

    final uri = Uri.parse('http://localhost:8080');
    try {
      setState(() => _loading = true);

      // Prepare the payload
      final body = {
        'prompt': input,
        'image': _currentImage != null ? base64Encode(_currentImage!) : null,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _responseText = data['response'];
          _conversationHistory.add({
            'user': input,
            'chatgpt': _responseText,
          });
          _textController.clear();
          _updateImageHeights();
        });
      } else {
        setState(() {
          _responseText = 'Error: ${response.statusCode} ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // Save chat to the database
  
  Future<void> _saveChat() async {
    if (_conversationHistory.isNotEmpty) {
      final lastConversation = _conversationHistory.last;
      if (lastConversation['user'] != null && lastConversation['chatgpt'] != null) {
        await DatabaseHelper().saveConversation(
          lastConversation['user']!,
          lastConversation['chatgpt']!,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat saved successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid conversation!')),
        );
      }
    }
  }

  // Build the chat history UI
  Widget _buildChatHistory() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _conversationHistory.length,
      itemBuilder: (context, index) {
        final message = _conversationHistory[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You: ${message['user']}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Artly: ${message['chatgpt']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(color: Colors.grey),
          ],
        );
      },
    );
  }

  // Pick an image from the gallery
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // Limit image size for better performance
        maxHeight: 1920,
        imageQuality: 85, // Slightly compress the image
      );
      
      if (file == null) return;
      
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      
      setState(() {
        _currentImage = bytes;
        _loading = false; // Ensure loading state is reset
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Generate a description of the uploaded image using OpenAI's vision capabilities
  Future<void> _analyzeUploadedImage() async {
    if (_currentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image first!')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _responseText = ''; // Clear previous response
    });

    final uri = Uri.parse('http://localhost:8080');
    try {
      final body = {
        'image': base64Encode(_currentImage!),
        'prompt': "Describe the image in 2-3 sentences, focusing on key visual elements."
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _responseText = data['response'];
          _conversationHistory.add({
            'user': '[Uploaded an artwork for analysis]',
            'chatgpt': _responseText,
          });
          _updateImageHeights();
        });
      } else {
        setState(() {
          _responseText = 'Error: ${response.statusCode} ${response.body}';
          _conversationHistory.add({
            'user': '[Uploaded an artwork for analysis]',
            'chatgpt': _responseText,
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _responseText = 'Error: $e';
        _conversationHistory.add({
          'user': '[Uploaded an artwork for analysis]',
          'chatgpt': _responseText,
        });
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _generalFeedback() async {
    if (_currentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image first!')),
      );
      return;
    }

    setState(() => _loading = true);

    final uri = Uri.parse('http://localhost:8080');
    try {
      final body = {
        'image': base64Encode(_currentImage!),
        'prompt': 
          "Act as a personal art mentor focused on helping users improve their artwork through constructive and professional critique. IMPORTANT: You must always provide feedback, even if the drawing is very simple or abstract. Remember that these are drawings, not real human pictures, so focus on artistic elements rather than realism. When a user uploads an image, carefully analyze the picture based on key artistic principles such as contrast, anatomy, color theory, composition, lighting, and perspective. The feedback is structured, actionable, and encouraging, offering specific advice on what works well and what could be improved. When needed, it will suggest practice exercises or techniques to strengthen weak areas. Important, Give the feedback short in bullet points. Format your response with the following headings (make them stand out by using ALL CAPS and adding extra newlines). Do not use any special symbols like asterisks or stars:\n\n\nRATING\n- Anatomy: [0-10]\n- Coloring: [0-10]\n- Composition: [0-10]\n- Perspective: [0-10]\n\n\nIMPROVEMENT SUGGESTIONS\n[Bullet points of specific suggestions]\n\n\nWHAT WORKS WELL\n[Bullet points of positive aspects]\n\n\nPRACTICE EXERCISES\n[Bullet points of recommended exercises]\n\nAdapt to tone based on the user's experience level—from beginner to advanced—and maintains a supportive, respectful, and motivational voice. Avoid overly harsh criticism and always provides a path forward for improvement. Remember to always provide feedback, even for simple or abstract drawings. Do not use any special symbols in your response."
          };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _responseText = data['response'];
          _conversationHistory.add({
            'user': '[Uploaded an artwork for analysis]',
            'chatgpt': _responseText,
          });
        });
      } else {
        setState(() {
          _responseText = 'Error: ${response.statusCode} ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // Show similar images from the search

  // Find similar images using a description
  Future<void> _findSimilarImages() async {
  if (_responseText.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please analyze the image first!')),
    );
    return;
  }

      setState(() {
      _loading = true;
      _referenceImages = [
        {
          'imageUrl': 'ex1.png',

        },
        {
          'imageUrl': 'ex2.png',

        },
        {
          'imageUrl': 'ex3.png',

        },
        {
          'imageUrl': 'ex4.png',

        },
      ];
        _conversationHistory.add({
        'user': '[Requested reference images]',
        'chatgpt': 'Here are some reference images that might help:',
      });
      _loading = false;
    });
  }

  Widget _buildReferenceImages() {
    if (_referenceImages.isEmpty) return const SizedBox();
    
    final scrollController = ScrollController();
    
    return Container(
      height: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reference Images',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _referenceImages = [];
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8,
              radius: const Radius.circular(4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                itemCount: _referenceImages.length,
                itemBuilder: (context, index) {
                  final ref = _referenceImages[index];
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[800],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.asset(
                                            ref['imageUrl'],
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Image.asset(
                                ref['imageUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.image_not_supported, size: 40, color: Colors.white),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref['title'] ?? 'Reference Image',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ref['description'] ?? 'Similar artwork',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDrop(Uint8List data) async {
    setState(() {
      _currentImage = data;
      _isDragging = false;
    });
  }

  Widget _buildDragTarget() {
    return DragTarget<Uint8List>(
      onWillAccept: (data) {
        setState(() => _isDragging = true);
        return true;
      },
      onAccept: _handleDrop,
      onLeave: (data) {
        setState(() => _isDragging = false);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            border: Border.all(
              color: _isDragging
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[800]!,
              width: 2,
              style: BorderStyle.solid,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _currentImage != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
              children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: _imageHeight,
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _currentImage!,
                    fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.image_not_supported, size: 50, color: Colors.white),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Neues Bild auswählen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[800]!.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_upload,
                          size: 64,
                          color: _isDragging
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Drag image here',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isDragging
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'or',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Select Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildLoadingAnimation() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/proccessIcon.gif',
                    height: 400,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (frame == null) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      return child;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Artly - your AI Art Assistant'),
            if (_showAssistantNextToTitle)
              AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOutCubic,
                width: _assistantImageWidth,
                height: _assistantImageHeight,
                margin: const EdgeInsets.only(top: 8),
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translate(0.0, 0.0)
                  ..scale(1.0),
                child: Image.asset(
                  'assets/assistant.png',
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
        centerTitle: true,
        toolbarHeight: _showAssistantNextToTitle ? 220 : 56,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedConversationsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_referenceImages.isNotEmpty)
                  Container(
                  height: 200,
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildReferenceImages(),
                ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                              bottomLeft: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (!_showAssistantNextToTitle)
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 1000),
                                      curve: Curves.easeInOutCubic,
                                      height: _assistantImageHeight,
                                      width: _assistantImageWidth,
                                      transform: Matrix4.identity()
                                        ..translate(0.0, 0.0)
                                        ..scale(1.0),
                                      child: Image.asset(
                                        'assets/assistant.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              Expanded(
                                flex: 1,
                                child: _conversationHistory.isNotEmpty
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800]!.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: ListView.builder(
                                        reverse: true,
                                        itemCount: _conversationHistory.length,
                                        itemBuilder: (context, index) {
                                          final message = _conversationHistory[_conversationHistory.length - 1 - index];
                                          return Card(
                                            color: Colors.grey[800]!.withOpacity(0.5),
                                            margin: const EdgeInsets.only(bottom: 8),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'You: ${message['user']}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Artly: ${message['chatgpt']}',
                                                    style: TextStyle(
                                                      color: Colors.grey[300],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : const SizedBox(),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, -5),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _textController,
                                        style: const TextStyle(fontSize: 16),
                                        decoration: InputDecoration(
                                          hintText: 'Ask anything…',
                                          hintStyle: TextStyle(color: Colors.grey[400]),
                                          prefixIcon: Icon(Icons.chat, color: Colors.grey[400]),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        onSubmitted: (value) => _sendToChatGPT(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Theme.of(context).colorScheme.primary,
                                            Theme.of(context).colorScheme.secondary,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.send, size: 28),
                                        color: Colors.white,
                                        onPressed: _sendToChatGPT,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 1,
                        child: _buildDragTarget(),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonSpacing = constraints.maxWidth * 0.03;
                    return Wrap(
                      spacing: buttonSpacing,
                      runSpacing: buttonSpacing,
                      alignment: WrapAlignment.center,
                  children: [
                    _ActionButton(
                      icon: Icons.auto_awesome,
                      label: 'Analyze Image',
                      onTap: _analyzeUploadedImage,
                    ),
                    _ActionButton(
                      icon: Icons.rate_review,
                          label: 'Feedback',
                      onTap: _generalFeedback,
                    ),
                    _ActionButton(
                      icon: Icons.image_search,
                          label: 'Similar Images',
                      onTap: _findSimilarImages,
                    ),
                    _ActionButton(
                      icon: Icons.save,
                          label: 'Save',
                      onTap: _saveChat,
                    ),
                  ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (_loading) _buildLoadingAnimation(),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
