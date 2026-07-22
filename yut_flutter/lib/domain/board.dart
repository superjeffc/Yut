import 'dart:math';

class Board {
  static const int maxRolls = 5;
  List<int> rollArray = List.filled(maxRolls, 0);
  int rollIndex = 0;
  int playerTurn = 0; // 0 = Player 1, 1 = Player 2

  static final Set<int> specialTiles = {
    0, 1, 5, 10, 15, 20, 21, 22, 23, 24, 25, 26, 27
  };

  // Outer path animation directions (19 entries)
  static const List<String> outerMoves = [
    'U', 'U', 'U', 'U', 'U', 
    'L', 'L', 'L', 'L', 'L', 
    'D', 'D', 'D', 'D', 'D', 
    'R', 'R', 'R', 'R'
  ];

  Board() {
    resetRollArray();
  }

  // Simulates throwing 4 Yut sticks. 
  // Probabilities: (1): 3/16, (2): 6/16, (3): 4/16, (4): 1/16, (5): 1/16, (-1): 1/16.
  int throwSticks() {
    final random = Random();
    int num = random.nextInt(16) + 1; // 1 to 16

    if (num == 1) return -1;       // Back-do (move back 1)
    if (num > 1 && num <= 4) return 1;   // Do
    if (num > 4 && num <= 10) return 2;  // Gae
    if (num > 10 && num <= 14) return 3; // Geol
    if (num > 14 && num <= 15) return 4; // Yut (roll again)
    return 5;                            // Mo (roll again)
  }

  void addRoll(int roll) {
    rollArray[rollIndex] = roll;
    if (rollIndex < 4) {
      rollIndex++;
    }
  }

  int getNonZeroRollCount() {
    return rollArray.where((r) => r != 0).length;
  }

  int getPosRollCount() {
    return rollArray.where((r) => r != 0 && r != -1).length;
  }

  void reset() {
    playerTurn = 0;
    rollIndex = 0;
    resetRollArray();
  }

  void resetRollArray() {
    rollIndex = 0;
    rollArray.fillRange(0, maxRolls, 0);
  }

  void endTurn() {
    playerTurn = (playerTurn + 1) % 2;
    resetRollArray();
  }

  void removeRoll(int rollVal) {
    bool wasFull = (maxRolls == getNonZeroRollCount());

    // Find the first occurrence of the roll and set it to 0
    for (int j = 0; j < rollArray.length; ++j) {
      if (rollArray[j] == rollVal) {
        rollArray[j] = 0;
        break;
      }
    }

    // Shift all non-zero entries to the left
    for (int k = 0; k < rollArray.length; ++k) {
      if (rollArray[k] == 0) {
        int index = k + 1;
        while (index < rollArray.length && rollArray[index] == 0) {
          index += 1;
        }
        if (index == rollArray.length) {
          index--;
        }
        if (rollArray[index] == 0) {
          break;
        }
        rollArray[k] = rollArray[index];
        rollArray[index] = 0;
      }
    }

    if (!wasFull && rollIndex > 0) {
      rollIndex--;
    }
  }

  bool rollEmpty() {
    return rollArray.every((r) => r == 0);
  }

  bool hasOnlyNegativeRoll() {
    return rollArray.every((r) => r == 0 || r == -1);
  }

  // Returns a list of [destination, roll] lists
  static List<List<int>> calculateLocation(int move, int location) {
    List<List<int>> moveList = [];
    int dest = location;

    if (move != 0) {
      if (specialTiles.contains(location)) {
        if (location == 0) {
          if (move >= 1) {
            dest = 32;
          } else {
            dest = 19;
            moveList.add([28, move]); // Rolling -1 on bottom-right gives second choice
          }
        } else if (location == 1) {
          dest = 1 + move;
        } else if (location == 5) {
          if (move >= 1) {
            dest = 19 + move;
          } else {
            dest--;
          }
          if (move >= 1) {
            moveList.add([5 + move, move]); // Rolling positive on top-right corner gives second choice
          }
        } else if (location == 10) {
          if (move == 1 || move == 2) {
            dest = 24 + move;
          } else if (move == 3) {
            dest = 22;
          } else if (move == 4 || move == 5) {
            dest = 23 + move;
          } else {
            dest--;
          }
          if (move >= 1) {
            moveList.add([10 + move, move]); // Rolling positive on top-left corner gives second choice
          }
        } else if (location == 15) {
          if (move > 0 && move < 5) {
            dest += move;
          } else if (move == 5) {
            dest = 0;
          } else {
            dest--;
            moveList.add([24, move]); // Rolling -1 on bottom-left gives second choice
          }
        } else if (location == 20) {
          if (move >= 1 && move <= 4) {
            dest = 20 + move;
          } else if (move == -1) {
            dest = 5;
          } else if (move == 5) {
            dest = 15;
          }
        } else if (location == 21) {
          if (move >= 1 && move <= 3) {
            dest = 21 + move;
          } else if (move == -1) {
            dest--;
          } else if (move == 4) {
            dest = 15;
          } else if (move == 5) {
            dest = 16;
          }
        } else if (location == 22) {
          if (move == 1 || move == 2 || move == 3) {
            dest = 26 + move;
          } else if (move > 3) {
            dest = 32;
          } else {
            dest = 21;
            moveList.add([26, move]); // Rolling -1 on center gives second choice
          }
          if (move >= 1) {
            int secondDest = 22;
            if (move == 1 || move == 2) {
              secondDest = 22 + move;
            } else if (move == 3) {
              secondDest = 15;
            } else if (move == 4) {
              secondDest = 16;
            } else if (move == 5) {
              secondDest = 17;
            }
            moveList.add([secondDest, move]); // Rolling positive on center gives second choice
          }
        } else if (location == 23) {
          if (move == 1) {
            dest++;
          } else if (move == -1) {
            dest--;
          } else if (move >= 2 && move <= 4) {
            dest = 13 + move;
          } else if (move == 5) {
            dest = 18;
          }
        } else if (location == 24) {
          if (move >= 1) {
            dest = 14 + move;
          } else if (move == -1) {
            dest--;
          }
        } else if (location == 25) {
          if (move == 1) {
            dest = 26;
          } else if (move == 2) {
            dest = 22;
          } else if (move == 3 || move == 4) {
            dest = 24 + move;
          } else if (move == 5) {
            dest = 0;
          } else {
            dest = 10;
          }
        } else if (location == 26) {
          if (move == 1) {
            dest = 22;
          } else if (move == 2 || move == 3) {
            dest = 25 + move;
          } else if (move == 4) {
            dest = 0;
          } else if (move == 5) {
            dest = 32;
          } else {
            dest--;
          }
        } else if (location == 27) {
          if (move >= 1) {
            dest += move;
          } else {
            dest = 22;
          }
        }
      } else if (location >= 15 && location <= 19) {
        if (location + move == 20) {
          dest = 0;
        } else if (location + move < 20) {
          dest += move;
        } else {
          dest = 32;
        }
      } else if (location == -1) {
        if (move >= 1) {
          dest = move;
        }
      } else {
        dest += move;
      }
    } else {
      dest = -1;
    }

    if (dest == 29) {
      dest = 0;
    } else if (dest > 29) {
      dest = 32;
    }

    moveList.add([dest, move]);
    return moveList;
  }

  // Returns character array paths for step-by-step UI translations
  List<String> calculatePath(int start, int dest, int numMoves) {
    List<String> path = [];

    if (numMoves > 0) {
      path = List.filled(numMoves, '');
    } else {
      path = List.filled(1, '');
    }

    int j = 0;

    if (numMoves == -1) {
      // Double choices cases
      if (start == 0 && dest == 28) path[0] = 'E';
      else if (start == 0 && dest == 19) path[0] = 'L';
      else if (start == 15 && dest == 14) path[0] = 'U';
      else if (start == 15 && dest == 24) path[0] = 'A';
      else if (start == 22 && dest == 26) path[0] = 'E';
      else if (start == 22 && dest == 21) path[0] = 'A';
      // Single choices cases
      else if (start > 0 && start <= 5) path[0] = 'D';
      else if (start > 5 && start <= 10) path[0] = 'R';
      else if (start > 10 && start <= 14) path[0] = 'U';
      else if (start > 15 && start <= 19) path[0] = 'L';
      else if (start > 19 && start <= 24) path[0] = 'A';
      else if (start > 24 && start <= 28) path[0] = 'E';
    } 
    else if (start == 0) {
      for (int i = 0; i < numMoves; i++) path[j++] = 'F';
    } 
    else if (start == 5) {
      if (dest >= 20) {
        for (int i = 0; i < numMoves; i++) path[j++] = 'C';
      } else {
        for (int i = 0; i < numMoves; i++) path[j++] = 'L';
      }
    } 
    else if (start == 10) {
      if (dest >= 22) {
        for (int i = 0; i < numMoves; i++) path[j++] = 'B';
      } else {
        for (int i = 0; i < numMoves; i++) path[j++] = 'D';
      }
    } 
    else if (start == 20) {
      for (int i = 0; i < numMoves; i++) path[j++] = 'C';
    } 
    else if (start == 21) {
      if (numMoves < 5) {
        for (int i = 0; i < numMoves; i++) path[j++] = 'C';
      } else {
        for (int i = 0; i < numMoves - 1; i++) path[j++] = 'C';
        path[j] = 'R';
      }
    } 
    else if (start == 22) {
      if (dest >= 27 || dest == 0) {
        if (numMoves <= 3) {
          for (int i = 0; i < numMoves; i++) path[j++] = 'B';
        } else {
          for (int i = 0; i < 3; i++) path[j++] = 'B';
          for (int i = 3; i < numMoves; i++) path[j++] = 'F';
        }
      } else {
        if (numMoves <= 3) {
          for (int i = 0; i < numMoves; i++) path[j++] = 'C';
        } else {
          for (int i = 0; i < 3; i++) path[j++] = 'C';
          for (int i = 3; i < numMoves; i++) path[j++] = 'R';
        }
      }
    } 
    else if (start == 23) {
      if (numMoves <= 2) {
        for (int i = 0; i < numMoves; i++) path[j++] = 'C';
      } else {
        for (int i = 0; i < 2; i++) path[j++] = 'C';
        for (int i = 2; i < numMoves; i++) path[j++] = 'R';
      }
    } 
    else if (start == 24) {
      path[j++] = 'C';
      if (numMoves > 1) {
        for (int i = 1; i < numMoves; i++) path[j++] = 'R';
      }
    } 
    else if (start == 25) {
      for (int i = 0; i < numMoves; i++) path[j++] = 'B';
    } 
    else if (start == 26) {
      if (numMoves < 5) {
        for (int i = 0; i < numMoves; i++) path[j++] = 'B';
      } else {
        for (int i = 0; i < numMoves - 1; i++) path[j++] = 'B';
        path[j] = 'F';
      }
    } 
    else if (start == 27) {
      if (numMoves <= 2) {
        for (int i = 0; i < numMoves; i++) path[j++] = 'B';
      } else {
        for (int i = 0; i < 2; i++) path[j++] = 'B';
        for (int i = 2; i < numMoves; i++) path[j++] = 'F';
      }
    } 
    else if (start == 28) {
      path[j++] = 'B';
      if (numMoves > 1) {
        for (int i = 1; i < numMoves; i++) path[j++] = 'F';
      }
    } 
    else {
      int s = start;
      if (s == -1) s++;

      if (dest == 0 || dest == 32) {
        if (s == 15) {
          for (int i = 0; i < numMoves; i++) path[j++] = 'R';
        } else if (s == 16) {
          if (numMoves <= 4) {
            for (int i = 0; i < numMoves; i++) path[j++] = 'R';
          } else {
            for (int i = 0; i < 4; i++) path[j++] = 'R';
            for (int i = 4; i < numMoves; i++) path[j++] = 'F';
          }
        } else if (s == 17) {
          if (numMoves <= 3) {
            for (int i = 0; i < numMoves; i++) path[j++] = 'R';
          } else {
            for (int i = 0; i < 3; i++) path[j++] = 'R';
            for (int i = 3; i < numMoves; i++) path[j++] = 'F';
          }
        } else if (s == 18) {
          if (numMoves <= 2) {
            for (int i = 0; i < numMoves; i++) path[j++] = 'R';
          } else {
            for (int i = 0; i < 2; i++) path[j++] = 'R';
            for (int i = 2; i < numMoves; i++) path[j++] = 'F';
          }
        } else if (s == 19) {
          if (numMoves <= 1) {
            for (int i = 0; i < numMoves; i++) path[j++] = 'R';
          } else {
            for (int i = 0; i < 1; i++) path[j++] = 'R';
            for (int i = 1; i < numMoves; i++) path[j++] = 'F';
          }
        }
      } else {
        for (int i = s; i < dest; i++) {
          path[j++] = outerMoves[i];
        }
      }
    }

    return path;
  }
}
