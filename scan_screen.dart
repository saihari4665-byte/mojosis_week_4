import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart'; // <--- NEW IMPORT
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'puzzles_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isScanning = false;

  // --- 1. PICK PDF FUNCTION ---
  Future<void> _pickAndScanPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        _processPdf(filePath);
      }
    } catch (e) {
      _showError("Error picking file: $e");
    }
  }

  // --- 2. CONVERT PDF TO IMAGE (Using pdfx) ---
  Future<void> _processPdf(String path) async {
    setState(() {
      _isScanning = true;
    });

    try {
      // Open the PDF document
      final document = await PdfDocument.openFile(path);

      // Get the 1st page (pdfx uses 1-based indexing)
      final page = await document.getPage(1);

      // Render the page as a PNG image
      final pageImage = await page.render(
        width: page.width * 2,   // Scale up for quality
        height: page.height * 2,
        format: PdfPageImageFormat.png, // <--- This now works!
      );

      // Close the page/doc to free memory
      await page.close();
      await document.close();

      if (pageImage == null) throw Exception("Could not render PDF page");

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/scanned_board.png');
      await tempFile.writeAsBytes(pageImage.bytes);

      // Send to AI
      await _analyzeImage(tempFile);

    } catch (e) {
      _showError("Failed to process PDF: $e");
      setState(() { _isScanning = false; });
    }
  }

  // --- 3. SEND TO YOUR CLOUD SERVER ---
  Future<void> _analyzeImage(File imageFile) async {
    final String serverUrl = "https://chess-vision-api.onrender.com/predict-fen";
    final url = Uri.parse(serverUrl);

    try {
      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var streamResponse = await request.send();
      var response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['fen'] != null) {
          String fen = data['fen'];

          // --- FIX: Auto-complete the FEN if parts are missing ---
          // If the AI returns just the board (no spaces), add standard ending
          if (!fen.contains(' ')) {
            fen += " w - - 0 1";
          }

          // Now verify it has the basic slash structure of a chess board
          if (fen.contains('/')) {
            _navigateToBoard(fen);
          } else {
            _showError("AI Failed: Could not detect a chess board.");
          }
        } else {
          _showError("AI could not find a board.");
        }
      } else {
        _showError("Server Error (${response.statusCode}).");
      }
    } catch (e) {
      _showError("Connection failed. Check internet.");
    }

    if (mounted) setState(() { _isScanning = false; });
  }

  void _navigateToBoard(String fen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzlesScreen(initialFen: fen),
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a Board')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Import Position',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_isScanning)
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Scanning PDF...", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("AI is analyzing...", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else ...[
              _buildScanButton(
                context: context,
                title: 'Upload PDF',
                subtitle: 'Import from a chess diagram PDF',
                icon: Icons.picture_as_pdf,
                onTap: _pickAndScanPdf,
              ),
              const SizedBox(height: 20),
              _buildScanButton(
                context: context,
                title: 'Use Camera',
                subtitle: 'Coming soon',
                icon: Icons.camera_alt,
                onTap: () => _showError("Camera coming soon!"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}