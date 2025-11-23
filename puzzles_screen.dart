import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'puzzle_solver_screen.dart';
import 'stockfish_service.dart';

class PuzzlesScreen extends StatefulWidget {
  // 1. Add optional FEN parameter
  final String? initialFen;

  const PuzzlesScreen({super.key, this.initialFen});

  @override
  State<PuzzlesScreen> createState() => _PuzzlesScreenState();
}

class _PuzzlesScreenState extends State<PuzzlesScreen> {
  final ChessBoardController _controller = ChessBoardController();
  final StockfishService _stockfish = StockfishService();

  PlayerColor _boardOrientation = PlayerColor.white;
  bool _isComputerThinking = false;
  int _difficultyLevel = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onBoardChange);
    _stockfish.init();

    // 2. Load the scanned FEN if provided
    if (widget.initialFen != null) {
      // Use a small delay to ensure controller is ready
      Future.delayed(Duration.zero, () {
        _controller.loadFen(widget.initialFen!);
      });
    }
  }

  // ... (Keep the dispose, _onBoardChange, and _makeComputerMove methods EXACTLY as they were in Task 1) ...
  @override
  void dispose() {
    _controller.removeListener(_onBoardChange);
    super.dispose();
  }

  void _onBoardChange() {
    if (mounted) setState(() {});
    if (_controller.game.in_checkmate || _controller.game.in_draw || _isComputerThinking) return;
    final isWhiteTurn = _controller.game.turn == chess_lib.Color.WHITE;
    final isPlayerWhite = _boardOrientation == PlayerColor.white;
    if (isWhiteTurn != isPlayerWhite) _makeComputerMove();
  }

  Future<void> _makeComputerMove() async {
    setState(() => _isComputerThinking = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    try {
      String bestMove = await _stockfish.computeMove(_controller.game.fen, _difficultyLevel);
      final from = bestMove.substring(0, 2);
      final to = bestMove.substring(2, 4);
      final promotion = bestMove.length > 4 ? bestMove.substring(4, 5) : null;
      _controller.game.move({'from': from, 'to': to, 'promotion': promotion ?? 'q'});
      _controller.loadFen(_controller.game.fen);
    } catch (e) {
      print("Stockfish Error: $e");
    }
    setState(() => _isComputerThinking = false);
  }
  // ... (End of copied methods) ...

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Play & Solve'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Play Board'),
              Tab(text: 'Puzzles'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPlayableBoardTab(),
            _buildCustomPuzzleTab(context), // Use context
          ],
        ),
      ),
    );
  }

  // ... (Keep _buildPlayableBoardTab, _buildCustomPuzzleTab, and _buildCategoryCard EXACTLY as before) ...

  Widget _buildPlayableBoardTab() {
    // Check if game started OR if we loaded a custom FEN
    bool isGameNotStarted = _controller.getSan().isEmpty && widget.initialFen == null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isGameNotStarted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Stockfish Level:", style: TextStyle(fontSize: 16)),
                  DropdownButton<int>(
                    value: _difficultyLevel,
                    dropdownColor: Colors.grey.shade800,
                    underline: Container(),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("Easy (Depth 1)")),
                      DropdownMenuItem(value: 2, child: Text("Medium (Depth 5)")),
                      DropdownMenuItem(value: 3, child: Text("Hard (Depth 12)")),
                    ],
                    onChanged: (value) => setState(() => _difficultyLevel = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: Center(
              child: ChessBoard(
                controller: _controller,
                boardColor: BoardColor.darkBrown,
                boardOrientation: _boardOrientation,
                enableUserMoves: !_isComputerThinking,
              ),
            ),
          ),

          if (_isComputerThinking)
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Center(child: Text("Stockfish is thinking...", style: TextStyle(color: Colors.blueAccent, fontStyle: FontStyle.italic))),
            ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isGameNotStarted && !_isComputerThinking) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Flip Board'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() => _boardOrientation = _boardOrientation == PlayerColor.white ? PlayerColor.black : PlayerColor.white);
                    if (_boardOrientation == PlayerColor.black) _makeComputerMove();
                  },
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart'),
                  onPressed: () {
                    _controller.resetBoard();
                    setState(() {
                      _isComputerThinking = false;
                      _boardOrientation = PlayerColor.white;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPuzzleTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Categories', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildCategoryCard(context, 'Checkmate in 2', 'Find the winning sequence', Icons.flag, 'checkmate-in-2'),
        _buildCategoryCard(context, 'Tactical Motifs', 'Pins, forks & skewers', Icons.star, 'tactical'),
        _buildCategoryCard(context, 'Endgame Practice', 'Master the endgame', Icons.shield, 'endgame'),
        _buildCategoryCard(context, 'Opening Traps', 'Learn common traps', Icons.warning, 'opening'),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, String subtitle, IconData icon, String categoryId) {
    return Card(
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PuzzleSolverScreen(category: categoryId, displayTitle: title)));
        },
      ),
    );
  }
}