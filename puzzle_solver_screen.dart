import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chess/chess.dart' as chess_lib; // Necessary for types

class PuzzleSolverScreen extends StatefulWidget {
  final String category;
  final String displayTitle;

  const PuzzleSolverScreen({
    super.key,
    required this.category,
    required this.displayTitle,
  });

  @override
  State<PuzzleSolverScreen> createState() => _PuzzleSolverScreenState();
}

class _PuzzleSolverScreenState extends State<PuzzleSolverScreen> {
  ChessBoardController controller = ChessBoardController();

  // Game State
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _currentPuzzle;
  List<dynamic> _solution = [];
  int _currentMoveIndex = 0;
  bool _isSolved = false;

  @override
  void initState() {
    super.initState();
    _fetchPuzzle();
    controller.addListener(_onBoardChange);
  }

  @override
  void dispose() {
    controller.removeListener(_onBoardChange);
    super.dispose();
  }

  Future<void> _fetchPuzzle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('puzzles')
          .where('category', isEqualTo: widget.category)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No puzzles found for ${widget.displayTitle}.";
        });
        return;
      }

      final randomIndex = Random().nextInt(snapshot.docs.length);
      final puzzleDoc = snapshot.docs[randomIndex];
      final puzzleData = puzzleDoc.data();

      setState(() {
        _currentPuzzle = puzzleData;
        _solution = puzzleData['solution'] as List<dynamic>;
        _currentMoveIndex = 0;
        _isSolved = false;
        _isLoading = false;
      });

      if (puzzleData['fen'] != null) {
        controller.loadFen(puzzleData['fen']);
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading puzzle: $e";
      });
    }
  }

  // --- THIS IS THE FIXED FUNCTION ---
  void _onBoardChange() {
    if (_isLoading || _isSolved || _currentPuzzle == null) return;

    final moves = controller.getSan();
    if (moves.isEmpty) return;

    String lastMove = moves.last!;

    // Check if this is a "player" move (Even index = Player)
    if (_currentMoveIndex % 2 == 0) {
      String expectedMove = _solution[_currentMoveIndex];

      // 1. Print to Console for Debugging
      // Look at your "Run" tab in VS Code to see exactly what is being compared!
      print("User Played: '$lastMove' | Expected: '$expectedMove'");

      // 2. Clean the strings (Remove '#' and '+')
      // This ensures "Qe8#" matches "Qe8"
      String cleanPlayed = lastMove.replaceAll('#', '').replaceAll('+', '');
      String cleanExpected = expectedMove.replaceAll('#', '').replaceAll('+', '');

      if (cleanPlayed == cleanExpected) {
        // CORRECT MOVE
        _handleCorrectMove();
      } else {
        // WRONG MOVE - Undo immediately
        Future.delayed(const Duration(milliseconds: 200), () {
          controller.undoMove();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Incorrect move. Try again!"),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(milliseconds: 800),
              ),
            );
          }
        });
      }
    }
  }

  void _handleCorrectMove() {
    _currentMoveIndex++; // Move to opponent's turn

    if (_currentMoveIndex >= _solution.length) {
      _handlePuzzleSolved();
      return;
    }

    // Opponent's Turn (Auto-play)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      String opponentMove = _solution[_currentMoveIndex];

      try {
        // Use internal engine to move
        controller.game.move({'san': opponentMove});
        controller.loadFen(controller.game.fen);

        _currentMoveIndex++; // Back to player's turn

        if (_currentMoveIndex >= _solution.length) {
          _handlePuzzleSolved();
        }
      } catch (e) {
        print("Error making opponent move: $e");
      }
    });
  }

  void _handlePuzzleSolved() {
    setState(() {
      _isSolved = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Puzzle Solved!"),
        content: const Text("Great job! You found the winning sequence."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text("Back to Menu"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _fetchPuzzle();
            },
            child: const Text("Next Puzzle"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate turn safely
    bool isWhiteTurn = controller.game.turn == chess_lib.Color.WHITE;
    String turnText = isWhiteTurn ? "White" : "Black";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.displayTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _currentPuzzle?['title'] ?? 'Solve this',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              _isSolved ? "Solved!" : "Your Turn ($turnText)",
              style: TextStyle(
                color: _isSolved ? Colors.green : Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Center(
                child: ChessBoard(
                  controller: controller,
                  boardColor: BoardColor.darkBrown,
                  boardOrientation: _getOrientation(),
                  enableUserMoves: !_isSolved,
                ),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    if (_currentPuzzle != null) {
                      controller.loadFen(_currentPuzzle!['fen']);
                      setState(() {
                        _currentMoveIndex = 0;
                        _isSolved = false;
                      });
                    }
                  },
                  tooltip: "Reset Puzzle",
                ),
                ElevatedButton.icon(
                  onPressed: _fetchPuzzle,
                  icon: const Icon(Icons.skip_next),
                  label: const Text("Skip"),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  PlayerColor _getOrientation() {
    if (_currentPuzzle != null && _currentPuzzle!['fen'].toString().contains(" b ")) {
      return PlayerColor.black;
    }
    return PlayerColor.white;
  }
}