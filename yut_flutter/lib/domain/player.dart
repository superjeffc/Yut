import 'piece.dart';

class Player {
  int score = 0;      // First to 4 wins
  int numPieces = 0;  // Number of active pieces on the board

  late List<Piece> pieces;

  Player() {
    pieces = List.generate(4, (_) => Piece());
  }

  // Finds the next available piece (from index 0 to 3) off the board
  int findAvailablePiece() {
    for (int i = 0; i < 4; i++) {
      if (pieces[i].location == -1) {
        return i;
      }
    }
    return -1; // No pieces off-board
  }

  bool hasNoPiecesOnBoard() {
    return numPieces == score;
  }

  bool hasAllPiecesOnBoard() {
    return numPieces == 4;
  }

  bool hasWon() {
    return score == 4;
  }

  void reset() {
    score = 0;
    numPieces = 0;
    for (var piece in pieces) {
      piece.reset();
    }
  }
}
