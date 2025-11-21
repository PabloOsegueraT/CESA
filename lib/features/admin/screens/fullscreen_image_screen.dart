import 'package:flutter/material.dart';

class FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;
  final Map<String, String>? headers;

  const FullscreenImageScreen({
    super.key,
    required this.imageUrl,
    this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Imagen',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          minScale: 0.8,
          child: Image.network(
            imageUrl,
            headers: headers,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}