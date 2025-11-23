import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';

class StockfishService {
  late Stockfish _engine;

  // 1. Add a flag to track if the engine is already running
  bool _isInitialized = false;

  final Completer<void> _readyCompleter = Completer<void>();

  // Singleton pattern
  static final StockfishService _instance = StockfishService._internal();
  factory StockfishService() => _instance;
  StockfishService._internal();

  /// Initialize the engine (Safe version)
  void init() {
    // 2. CHECK: If already running, do nothing!
    if (_isInitialized) return;

    try {
      _engine = Stockfish();
      _isInitialized = true; // Mark as running

      // Setup listener for "ready" state
      void onStateChange() {
        // Safety check if engine was disposed (unlikely in singleton but good practice)
        if (!_isInitialized) return;

        final state = _engine.state.value;
        if (kDebugMode) print("Stockfish State: $state");

        if (state == StockfishState.ready && !_readyCompleter.isCompleted) {
          _readyCompleter.complete();
          _engine.stdin = 'uci';
          _engine.stdin = 'isready';
          _engine.state.removeListener(onStateChange);
        }
      }

      _engine.state.addListener(onStateChange);

      if (_engine.state.value == StockfishState.ready && !_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    } catch (e) {
      print("Stockfish init error: $e");
      // This catches the "Multiple instances" error if it happens during Hot Restart
    }
  }

  Future<String> computeMove(String fen, int difficulty) async {
    if (!_isInitialized) init(); // Try to init if missing

    if (!_readyCompleter.isCompleted) {
      await _readyCompleter.future;
    }

    final completer = Completer<String>();

    int depth = 1;
    if (difficulty == 2) depth = 5;
    if (difficulty == 3) depth = 12;

    StreamSubscription? subscription;
    subscription = _engine.stdout.listen((output) {
      if (kDebugMode) print("Stockfish Out: $output");

      if (output.startsWith('bestmove')) {
        final parts = output.split(' ');
        if (parts.length > 1) {
          final bestMove = parts[1];
          if (!completer.isCompleted) {
            completer.complete(bestMove);
          }
        }
        subscription?.cancel();
      }
    });

    _engine.stdin = 'position fen $fen';
    _engine.stdin = 'go depth $depth';

    return completer.future;
  }

  void dispose() {
    // 3. We NEVER dispose the engine in this version
    // Keeping it alive prevents the crash when you come back to the screen.
  }
}