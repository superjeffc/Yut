import 'player.dart';

class Computer {
  static final Set<int> shortcuts = {0, 5, 10, 22};

  // Selects the best move for the computer (Player index 1)
  // Returns [pieceIndex, destinationTile]
  // Note: pieceIndex = -1 indicates moving a piece from off-board onto the board
  static List<int> selectMove(List<Player> players, List<int> rollArray) {
    Player human = players[0];
    Player computer = players[1];

    // List of list of destinations for each of the 4 computer pieces
    List<List<int>> moves = List.generate(4, (_) => []);

    for (int i = 0; i < 4; i++) {
      if (computer.pieces[i].location != 32) {
        List<List<int>> moveSet = computer.pieces[i].calculateMoveset(rollArray);

        for (var move in moveSet) {
          int dest = move[0];
          if (dest != -1) {
            moves[i].add(dest);
          }
        }
      }
    }

    // 1. Capture enemy piece (highest priority)
    for (int i = 0; i < moves.length; i++) {
      for (int dest in moves[i]) {
        for (int k = 0; k < 4; k++) {
          if (human.pieces[k].location == dest) {
            // If piece is off board and can move onto board to capture at tile <= 5
            if (computer.numPieces < 4 && dest <= 5) {
              if (computer.pieces[i].location == -1) {
                return [-1, dest];
              }
            }
            if (computer.pieces[i].location != -1 && computer.pieces[i].location != 32) {
              return [i, dest];
            }
          }
        }
      }
    }

    // 2. Stack pieces
    for (int i = 0; i < moves.length; i++) {
      for (int dest in moves[i]) {
        for (int k = 0; k < 4; k++) {
          if (computer.pieces[k].location == dest && k != i) {
            if (computer.numPieces < 4 && dest <= 5) {
              if (computer.pieces[i].location == -1) {
                return [-1, dest];
              }
            }
            if (computer.pieces[i].location != -1 && computer.pieces[i].location != 32) {
              return [i, dest];
            }
          }
        }
      }
    }

    // 3. Finish pieces
    for (int i = 0; i < moves.length; i++) {
      for (int dest in moves[i]) {
        if (dest == 32) {
          return [i, dest];
        }
      }
    }

    // 4. Take shortcuts
    for (int i = 0; i < moves.length; i++) {
      for (int dest in moves[i]) {
        if (shortcuts.contains(dest)) {
          if (computer.numPieces < 4 && dest == 5) {
            if (computer.pieces[i].location == -1) {
              return [-1, dest];
            }
          }
          if (computer.pieces[i].location != -1 && computer.pieces[i].location != 32) {
            return [i, dest];
          }
        }
      }
    }

    // 5. Fallback: Take first available move
    List<int> nonZeroRolls = rollArray.where((r) => r != 0).toList();

    // Check for single -1 roll (cannot move new pieces onto the board with a negative roll)
    if (nonZeroRolls.length == 1 && nonZeroRolls[0] == -1) {
      for (int i = 0; i < 4; i++) {
        if (computer.pieces[i].location != -1 && computer.pieces[i].location != 32) {
          if (moves[i].isNotEmpty) {
            return [i, moves[i][0]];
          }
        }
      }
    }

    // Use off-board piece if available
    if (computer.numPieces < 4) {
      for (int i = 0; i < 4; i++) {
        if (computer.pieces[i].location == -1 && moves[i].isNotEmpty) {
          return [-1, moves[i][0]]; // -1 indicates off board piece
        }
      }
    }

    // Use on-board piece
    for (int i = 0; i < 4; i++) {
      if (computer.pieces[i].location != -1 && computer.pieces[i].location != 32) {
        if (moves[i].isNotEmpty) {
          return [i, moves[i][0]];
        }
      }
    }

    return [-2, -2]; // Error state
  }
}
