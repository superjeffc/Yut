import 'board.dart';

class Piece {
  int location = -1; // Current location on the board. -1 is off-board, 32 is finished.
  int value = 1;     // Number of stacked pieces on this slot.

  List<List<int>> calculateMoveset(List<int> moves) {
    List<List<int>> moveList = []; // List of [destination, rollAmount]

    for (int roll in moves) {
      if (roll != 0) {
        // Get all places the piece can move to with this roll starting at this location
        moveList.addAll(Board.calculateLocation(roll, location));
      }
    }

    return moveList;
  }

  void resetValue() {
    value = 1;
  }

  void addValue(int v) {
    value += v;
  }

  void reset() {
    location = -1;
    value = 1;
  }
}
