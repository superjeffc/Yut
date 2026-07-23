import 'dart:async';
import 'package:flutter/foundation.dart';
import 'board.dart';
import 'piece.dart';
import 'player.dart';
import 'computer.dart';
import 'shop.dart';

class GameController extends ChangeNotifier {
  late List<Player> players;
  late Board board;
  
  int turn = 0; // 0 = Player 1, 1 = Player 2 / Computer
  int get oppTurn => (turn + 1) % 2;

  bool isComputerPlaying = true;
  bool isGameOver = false;
  
  bool isRollInProgress = false;
  bool isMoveInProgress = false;
  int currentRollValue = 0; // Value of last rolled sticks
  
  int? selectedPieceIndex; // Nullable, index of piece selected to move (0-3, or -1 for off-board)
  int? animatingPieceIndex;
  int? animatingPlayerIndex;
  List<List<int>> currentMoveSet = []; // Current destinations [[dest, rollAmount]]
  Set<int> highlightedTiles = {}; // Destination tiles to highlight

  String statusText = "Player 1's Turn";
  String tipsText = "Roll the sticks!";

  bool soundOn = true;

  bool isMultiplayer = false;
  int myPlayerIndex = 0; // 0 for Player 1, 1 for Player 2
  String? multiplayerRoomId;
  Function(Map<String, dynamic>)? onSendMultiplayerAction;

  GameController({required this.isComputerPlaying}) {
    board = Board();
    players = [Player(), Player()];
    resetGame();
  }

  void resetGame() {
    isGameOver = false;
    isRollInProgress = false;
    isMoveInProgress = false;
    turn = 0;
    selectedPieceIndex = null;
    currentMoveSet = [];
    highlightedTiles.clear();
    board.reset();
    players[0].reset();
    players[1].reset();
    statusText = "Player 1's Turn";
    tipsText = "Roll the sticks!";
    notifyListeners();
  }

  void toggleSound() {
    soundOn = !soundOn;
    notifyListeners();
  }

  // Executes stick throwing
  Future<void> rollSticks() async {
    if (isRollInProgress || isMoveInProgress || isGameOver) return;
    
    // Check if player is allowed to roll
    int currentIndex = board.rollIndex;
    if (currentIndex >= 5) return;

    isRollInProgress = true;
    currentRollValue = board.throwSticks();
    
    statusText = "Rolling...";
    tipsText = "";
    notifyListeners();

    // Simulate stick rolling animation delay
    await Future.delayed(const Duration(milliseconds: 1200));

    board.addRoll(currentRollValue);
    isRollInProgress = false;

    if (isMultiplayer && onSendMultiplayerAction != null && turn == myPlayerIndex) {
      onSendMultiplayerAction!({
        "type": "ROLL_RESULT",
        "rollName": getRollName(currentRollValue),
      });
    }

    // Check roll rules
    bool canRollAgain = false;
    bool isEndTurnImmediately = false;

    if ((currentRollValue == 4 || currentRollValue == 5) && currentIndex < 4) {
      canRollAgain = true;
    } else if (currentRollValue == -1 && currentIndex == 0 && players[turn].hasNoPiecesOnBoard()) {
      isEndTurnImmediately = true;
    }

    if (isEndTurnImmediately) {
      statusText = "Rolled Back-Do (-1) with no pieces on board!";
      tipsText = "Turn ends.";
      notifyListeners();

      if (isMultiplayer && onSendMultiplayerAction != null && turn == myPlayerIndex) {
        onSendMultiplayerAction!({
          "type": "MOVE",
          "p1Pieces": players[0].pieces.map((p) => p.location).toList(),
          "p2Pieces": players[1].pieces.map((p) => p.location).toList(),
          "p1Values": players[0].pieces.map((p) => p.value).toList(),
          "p2Values": players[1].pieces.map((p) => p.value).toList(),
          "rollUsed": "Back-Do",
          "nextTurn": oppTurn,
        });
      }

      await Future.delayed(const Duration(milliseconds: 1500));
      endTurn();
    } else if (canRollAgain) {
      statusText = "Rolled ${rollName(currentRollValue)}!";
      tipsText = "Roll again!";
      notifyListeners();
      
      // If computer turn, wait and roll again
      if (turn == 1 && isComputerPlaying) {
        await Future.delayed(const Duration(milliseconds: 1000));
        rollSticks();
      }
    } else {
      statusText = "Rolled ${rollName(currentRollValue)}!";
      tipsText = "Select a piece to move.";
      notifyListeners();

      // If computer turn, let computer select its move
      if (turn == 1 && isComputerPlaying) {
        await Future.delayed(const Duration(milliseconds: 1000));
        executeComputerMove();
      }
    }
  }

  String rollName(int val) {
    switch (val) {
      case -1: return "Back-Do (-1)";
      case 1: return "Do (1)";
      case 2: return "Gae (2)";
      case 3: return "Geol (3)";
      case 4: return "Yut (4)";
      case 5: return "Mo (5)";
      default: return "";
    }
  }

  // Highlight tiles for a piece index (-1 for off-board start, or 0-3 for on-board piece)
  void selectPiece(int pieceIndex) {
    if (isMoveInProgress || isRollInProgress || isGameOver) return;
    if (turn == 1 && isComputerPlaying) return;

    selectedPieceIndex = pieceIndex;
    highlightedTiles.clear();

    Piece piece;
    if (pieceIndex == -1) {
      int available = players[turn].findAvailablePiece();
      if (available == -1) return; // No pieces off-board
      piece = players[turn].pieces[available];
    } else {
      piece = players[turn].pieces[pieceIndex];
      if (piece.location == -1 || piece.location == 32) return;
    }

    currentMoveSet = piece.calculateMoveset(board.rollArray);
    for (var move in currentMoveSet) {
      int dest = move[0];
      if (dest != -1) {
        highlightedTiles.add(dest);
      }
    }

    tipsText = "Click highlighted tile to move.";
    notifyListeners();
  }

  void cancelSelection() {
    selectedPieceIndex = null;
    highlightedTiles.clear();
    currentMoveSet.clear();
    tipsText = "Select a piece to move.";
    notifyListeners();
  }

  // Execute movement to highlighted destination
  Future<void> makeMove(int dest) async {
    if (selectedPieceIndex == null || !highlightedTiles.contains(dest)) return;

    int pieceIdx = selectedPieceIndex!;
    animatingPieceIndex = pieceIdx;
    animatingPlayerIndex = turn;
    selectedPieceIndex = null;
    highlightedTiles.clear();

    int startPieceIndex = pieceIdx;
    if (pieceIdx == -1) {
      startPieceIndex = players[turn].findAvailablePiece();
      players[turn].numPieces += 1;
    }

    final piece = players[turn].pieces[startPieceIndex];
    int startLocation = piece.location;
    bool wasMyTurn = (turn == myPlayerIndex);

    // Find the roll amount used to reach this destination
    int rollUsed = 0;
    for (var move in currentMoveSet) {
      if (move[0] == dest) {
        rollUsed = move[1];
        break;
      }
    }

    currentMoveSet.clear();
    isMoveInProgress = true;
    statusText = "Moving...";
    tipsText = "";
    notifyListeners();
    print("DEBUG: makeMove dest=$dest, turn=$turn, myPlayerIndex=$myPlayerIndex, isMultiplayer=$isMultiplayer");

    // Get sequential animation path
    List<String> pathChars = board.calculatePath(startLocation, dest, rollUsed);
    
    // We animate tile-by-tile using helper coordinates.
    // Build a list of intermediate tiles
    List<int> tilePath = calculateIntermediateTiles(startLocation, dest, pathChars);

    for (int nextTile in tilePath) {
      await Future.delayed(const Duration(milliseconds: 200));
      piece.location = nextTile;
      notifyListeners();
    }

    piece.location = dest;
    board.removeRoll(rollUsed);

    // Check capture/stack rules
    bool isCapture = false;
    bool isStack = false;

    if (dest != 32 && dest != -1) {
      // Check stack (same team)
      for (int i = 0; i < 4; i++) {
        if (players[turn].pieces[i].location == dest && i != startPieceIndex) {
          isStack = true;
          piece.addValue(players[turn].pieces[i].value);
          players[turn].pieces[i].location = -1;
          players[turn].pieces[i].resetValue();
        }
      }

      // Check capture (opponent team)
      for (int i = 0; i < 4; i++) {
        if (players[oppTurn].pieces[i].location == dest) {
          isCapture = true;
          players[oppTurn].numPieces -= players[oppTurn].pieces[i].value;
          players[oppTurn].pieces[i].location = -1;
          players[oppTurn].pieces[i].resetValue();
        }
      }
    }

    isMoveInProgress = false;
    animatingPieceIndex = null;
    animatingPlayerIndex = null;

    // Check if finished
    if (dest == 32) {
      players[turn].score += piece.value;
      piece.location = 32;
      piece.resetValue();
    }

    recalculatePlayerStats();

    if (players[turn].hasWon()) {
      isGameOver = true;
      statusText = turn == 0 ? "Player 1 Wins!" : (isComputerPlaying ? "Computer Wins!" : "Player 2 Wins!");
      awardCoins();
      
      // Stats tracking (only recorded when playing against the computer)
      if (isComputerPlaying) {
        Shop.instance.incrementGames();
        if (turn == 0) {
          Shop.instance.incrementWins();
        } else {
          Shop.instance.incrementLosses();
        }
      }

      notifyListeners();
      
      if (isMultiplayer && onSendMultiplayerAction != null && wasMyTurn) {
        onSendMultiplayerAction!({
          "type": "MOVE",
          "p1Pieces": players[0].pieces.map((p) => p.location).toList(),
          "p2Pieces": players[1].pieces.map((p) => p.location).toList(),
          "p1Values": players[0].pieces.map((p) => p.value).toList(),
          "p2Values": players[1].pieces.map((p) => p.value).toList(),
          "rollUsed": getRollName(rollUsed),
          "nextTurn": turn,
          "isCapture": isCapture,
          "isGameOver": true,
        });
      }
      return;
    }

    if (isCapture) {
      statusText = "Captured Opponent's Piece!";
      tipsText = "Roll again!";
      // Opponent capture gives another roll
      board.resetRollArray();
      notifyListeners();
      if (turn == 1 && isComputerPlaying) {
        await Future.delayed(const Duration(milliseconds: 1000));
        rollSticks();
      }
    } else {
      if (board.rollEmpty() || (board.hasOnlyNegativeRoll() && players[turn].hasNoPiecesOnBoard())) {
        endTurn();
      } else {
        statusText = turn == 0 ? "Player 1's Move" : "Player 2's Move";
        tipsText = "Select next piece to move.";
        notifyListeners();
        
        if (turn == 1 && isComputerPlaying) {
          await Future.delayed(const Duration(milliseconds: 1000));
          executeComputerMove();
        }
      }
    }

    if (isMultiplayer && onSendMultiplayerAction != null && wasMyTurn) {
      print("DEBUG: sending MOVE action p1=${players[0].pieces.map((p) => p.location).toList()} p2=${players[1].pieces.map((p) => p.location).toList()} p1Val=${players[0].pieces.map((p) => p.value).toList()} p2Val=${players[1].pieces.map((p) => p.value).toList()}");
      onSendMultiplayerAction!({
        "type": "MOVE",
        "p1Pieces": players[0].pieces.map((p) => p.location).toList(),
        "p2Pieces": players[1].pieces.map((p) => p.location).toList(),
        "p1Values": players[0].pieces.map((p) => p.value).toList(),
        "p2Values": players[1].pieces.map((p) => p.value).toList(),
        "rollUsed": getRollName(rollUsed),
        "nextTurn": turn,
        "isCapture": isCapture,
      });
    }
  }

  void endTurn() {
    board.endTurn();
    turn = board.playerTurn;
    statusText = turn == 0 ? "Player 1's Turn" : (isComputerPlaying ? "Computer's Turn" : "Player 2's Turn");
    tipsText = "Roll the sticks!";
    notifyListeners();

    if (turn == 1 && isComputerPlaying) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        rollSticks();
      });
    }
  }

  void awardCoins() {
    if (isComputerPlaying && players[0].hasWon()) {
      Shop.instance.addCoins(3);
    } else {
      Shop.instance.addCoins(1);
    }
  }

  // Helper to generate the exact list of tiles between start and destination
  List<int> calculateIntermediateTiles(int start, int dest, List<String> pathChars) {
    List<int> path = [];
    int current = start;

    for (String dir in pathChars) {
      if (dir == 'F') {
        current = dest; // Jump straight to destination (visibility off)
      } else {
        current = getNextTileInDirection(current, dir);
      }
      path.add(current);
    }

    // Ensure final element is dest
    if (path.isEmpty || path.last != dest) {
      path.add(dest);
    }
    return path;
  }

  int getNextTileInDirection(int current, String dir) {
    // Ported from Board coordinate jumps
    if (current == -1) return 1;

    switch (dir) {
      case 'U': // Up
        if (current >= 0 && current < 5) return current + 1;
        if (current >= 10 && current < 15) return current - 1;
        break;
      case 'D': // Down
        if (current >= 5 && current < 10) return current + 1;
        if (current >= 15 && current < 20) return current - 1;
        break;
      case 'L': // Left
        if (current >= 5 && current < 10) return current + 1;
        if (current == 20) return 5;
        if (current == 21) return 20;
        if (current == 22) return 21;
        break;
      case 'R': // Right
        if (current >= 15 && current < 20) return (current + 1 == 20) ? 0 : current + 1;
        if (current == 23) return 27;
        if (current == 24) return 23;
        break;
      case 'A': // Up-Right (Diagonal)
        if (current == 0) return 28;
        if (current == 15) return 24;
        if (current == 24) return 23;
        if (current == 23) return 22;
        if (current == 22) return 21;
        if (current == 21) return 20;
        if (current == 20) return 5;
        break;
      case 'B': // Down-Right (Diagonal)
        if (current == 10) return 25;
        if (current == 25) return 26;
        if (current == 26) return 22;
        if (current == 22) return 27;
        if (current == 27) return 28;
        if (current == 28) return 0;
        break;
      case 'C': // Down-Left (Diagonal)
        if (current == 5) return 20;
        if (current == 20) return 21;
        if (current == 21) return 22;
        if (current == 22) return 23;
        if (current == 23) return 24;
        if (current == 24) return 15;
        break;
      case 'E': // Up-Left (Diagonal)
        if (current == 0) return 28;
        if (current == 28) return 27;
        if (current == 27) return 22;
        if (current == 22) return 26;
        if (current == 26) return 25;
        if (current == 25) return 10;
        break;
    }
    return current;
  }

  // Executes AI computer move
  Future<void> executeComputerMove() async {
    if (isGameOver) return;

    List<int> decision = Computer.selectMove(players, board.rollArray);
    int pieceIdx = decision[0];
    int dest = decision[1];

    if (pieceIdx == -2) {
      // Error or no moves: end turn
      endTurn();
      return;
    }

    selectedPieceIndex = pieceIdx;

    // Build computer move set
    Piece piece = pieceIdx == -1 
        ? players[1].pieces[players[1].findAvailablePiece()] 
        : players[1].pieces[pieceIdx];
    currentMoveSet = piece.calculateMoveset(board.rollArray);
    highlightedTiles = {dest};

    statusText = "Computer is choosing...";
    tipsText = "";
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1000));
    await makeMove(dest);
  }

  String getRollName(int val) {
    switch (val) {
      case -1: return "Back-Do";
      case 1: return "Do";
      case 2: return "Gae";
      case 3: return "Geol";
      case 4: return "Yut";
      case 5: return "Mo";
      default: return "";
    }
  }

  int getRollValue(String name) {
    switch (name) {
      case "Back-Do": return -1;
      case "Do": return 1;
      case "Gae": return 2;
      case "Geol": return 3;
      case "Yut": return 4;
      case "Mo": return 5;
      default: return 0;
    }
  }

  void syncMultiplayerState(Map<String, dynamic> state) {
    int newTurn = state["turn"] ?? 0;
    List<dynamic> p1Pos = state["p1Pieces"] ?? [-1, -1, -1, -1];
    List<dynamic> p2Pos = state["p2Pieces"] ?? [-1, -1, -1, -1];
    List<dynamic> p1Val = state["p1Values"] ?? [1, 1, 1, 1];
    List<dynamic> p2Val = state["p2Values"] ?? [1, 1, 1, 1];
    List<dynamic> rolls = state["rollsLeft"] ?? [];
    bool newIsGameOver = state["isGameOver"] ?? false;
    int winnerIdx = state["winnerIndex"] ?? -1;

    for (int i = 0; i < 4; i++) {
      players[0].pieces[i].location = p1Pos[i] as int;
      players[0].pieces[i].resetValue();
      players[0].pieces[i].addValue((p1Val[i] as int) - 1);

      players[1].pieces[i].location = p2Pos[i] as int;
      players[1].pieces[i].resetValue();
      players[1].pieces[i].addValue((p2Val[i] as int) - 1);
    }

    recalculatePlayerStats();

    if (players[0].hasWon()) {
      newIsGameOver = true;
      winnerIdx = 0;
    } else if (players[1].hasWon()) {
      newIsGameOver = true;
      winnerIdx = 1;
    }

    board.rollArray = List<int>.filled(5, 0);
    for (int i = 0; i < rolls.length; i++) {
      if (i < 5) {
        board.rollArray[i] = getRollValue(rolls[i] as String);
      }
    }
    board.rollIndex = rolls.length;
    
    turn = newTurn;
    board.playerTurn = newTurn;
    isGameOver = newIsGameOver;

    bool canRoll = state["canRoll"] ?? true;
    bool lastActionWasCapture = state["lastActionWasCapture"] ?? false;

    print("DEBUG: syncMultiplayerState turn=$turn, p1=$p1Pos, p2=$p2Pos, p1Val=$p1Val, p2Val=$p2Val, rolls=$rolls, canRoll=$canRoll, lastActionWasCapture=$lastActionWasCapture");

    if (isGameOver) {
      statusText = winnerIdx == 0 ? "Player 1 Wins!" : "Player 2 Wins!";
      tipsText = "Game Over.";
    } else {
      if (board.rollEmpty()) {
        if (lastActionWasCapture) {
          statusText = turn == myPlayerIndex ? "Captured Opponent's Piece!" : "Opponent Captured Your Piece!";
          tipsText = turn == myPlayerIndex ? "Roll again!" : "Opponent is rolling again...";
        } else {
          statusText = turn == myPlayerIndex ? "Your Turn" : "Opponent's Turn";
          tipsText = turn == myPlayerIndex ? "Roll the sticks!" : "Waiting for opponent...";
        }
      } else {
        if (canRoll && turn == myPlayerIndex) {
          statusText = "Rolled ${rolls.isNotEmpty ? rolls.last : ''}!";
          tipsText = "Roll again!";
        } else {
          statusText = turn == myPlayerIndex ? "Your Move" : "Opponent's Move";
          tipsText = turn == myPlayerIndex ? "Select a piece to move." : "Opponent is choosing...";
        }
      }
    }

    notifyListeners();
  }

  void recalculatePlayerStats() {
    for (int p = 0; p < 2; p++) {
      int totalEntered = 0;
      int scoreVal = 0;

      for (int i = 0; i < 4; i++) {
        if (players[p].pieces[i].location != -1) {
          totalEntered += players[p].pieces[i].value;
          if (players[p].pieces[i].location == 32) {
            scoreVal += players[p].pieces[i].value;
          }
        }
      }

      players[p].numPieces = totalEntered;
      players[p].score = scoreVal;
    }
  }

  void _recalculateStacks() {
    for (int p = 0; p < 2; p++) {
      for (int i = 0; i < 4; i++) {
        players[p].pieces[i].resetValue();
      }

      Map<int, List<int>> locMap = {};
      for (int i = 0; i < 4; i++) {
        int loc = players[p].pieces[i].location;
        if (loc != -1 && loc != 32) {
          locMap.putIfAbsent(loc, () => []).add(i);
        }
      }

      for (var entry in locMap.entries) {
        var indices = entry.value;
        if (indices.length > 1) {
          int masterIdx = indices.first;
          int totalVal = indices.length;
          players[p].pieces[masterIdx].addValue(totalVal - 1);
          for (int j = 1; j < indices.length; j++) {
            players[p].pieces[indices[j]].location = -1;
            players[p].pieces[indices[j]].resetValue();
          }
        }
      }
    }

    recalculatePlayerStats();
  }
}
