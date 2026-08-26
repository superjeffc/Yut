# Yut (윷놀이) - Strategic Board Game & Real-Time Multiplayer Platform

A full-stack, cross-platform implementation of Yut (pronounced *yoot*), a traditional Korean strategic board game with mechanics similar to games like "Sorry!". Built with Flutter for multi-platform client rendering and powered by a serverless backend on Cloudflare Workers, Durable Objects, and D1 Database for real-time WebSocket multiplayer.

---

## Official Links & Resources

- **Live Web Application (PWA):** [https://superjeffc.github.io/yut/](https://superjeffc.github.io/yut/)
- **Google Play Store (Android):** [https://play.google.com/store/apps/details?id=com.jeffreychan.yunnori](https://play.google.com/store/apps/details?id=com.jeffreychan.yunnori)
- **More Information About Yut:** [https://en.wikipedia.org/wiki/Yut](https://en.wikipedia.org/wiki/Yut)

---

## Game Overview and How to Play

Yut Nori is a race-based strategy board game played between two players or teams.

### Objective

The first player to move all 4 of his or her pieces all the way around the board and return home wins the game.

### 1. Roll Phase (Yut Sticks)

During your turn, you will be prompted to throw four wooden Yut sticks using the roll button. Each stick has a flat side and a rounded side. The combination of flat sides facing up determines your movement score:

| Outcome Name | Korean | Flat Sides Up | Movement Score | Extra Turn Granted? |
| :--- | :--- | :---: | :---: | :---: |
| **Do** | 도 | 1 | Move 1 tile forward | No |
| **Gae** | 개 | 2 | Move 2 tiles forward | No |
| **Geol** | 걸 | 3 | Move 3 tiles forward | No |
| **Yut** | 윷 | 4 | Move 4 tiles forward | **Yes** |
| **Mo** | 모 | 0 (All Round) | Move 5 tiles forward | **Yes** |
| **Back Do** | 빠도 / 뒷도 | 1 (Special) | Move 1 tile backward | No |

- **Extra Roll Rule:** If you roll a 4 (**Yut**) or a 5 (**Mo**), you get to roll again. In addition, if you land on an opponent's piece, you also get to roll again. Rolls accumulate in your turn queue, allowing you to choose which roll to assign to which piece.

### 2. Move Phase & Board Mechanics

Your available movement options are displayed on screen.

- **Piece Selection:** To move, click any one of your available pieces (indicated by jumping animations).
- **Tile Selection:** Highlighted yellow tiles indicate possible target locations you can move to with that piece based on your current rolls.
- **Shortcuts:** Landing exactly on the corner nodes allows a piece to take shorter diagonal routes across the center of the board.
- **Stacking (Carrying):** If your piece lands on a tile occupied by another piece of yours, the pieces stack together and move as a combined unit on subsequent turns.
- **Capturing:** Landing on a tile occupied by an opponent's piece captures that piece, sending it off-board back to the start and granting you an extra roll.

---

## Application Features

- **Real-Time Online Multiplayer:** Low-latency peer matchmaking and custom room creation using WebSocket connections routed through Cloudflare Durable Objects.
- **Single-Player vs AI:** Heuristic decision engine prioritizing captures, optimal shortcut routing, piece stacking, and defensive spacing.
- **Local Pass & Play:** Multiplayer support on a single shared device.
- **Google OAuth Authentication:** Secure account management and profile synchronization via Google Sign-In.
- **In-Game Economy & Customization:** Earn coins through gameplay to unlock custom board skins, piece designs, and player avatars.
- **Progressive Web App (PWA) & Mobile Cross-Platform:** Fluid 60 FPS performance on Web browsers, Android, iOS, Windows, macOS, and Linux.

---

## System Architecture

```text
[ Flutter Client (Web / Android / iOS / Desktop) ]
       |                                |
       | HTTPS (OAuth & REST)           | WebSockets (Real-time State)
       v                                v
[ Cloudflare Pages / Functions ]    [ Cloudflare Durable Objects ]
  - /api/auth.js (Google OAuth)       - YutLobby (Matchmaking Queue)
  - /api/ws (WebSocket Proxy)         - YutGameRoom (Game State & Broadcasts)
       |                                |
       +------------+  +----------------+
                    |  |
                    v  v
           [ Cloudflare D1 Database ]
            (SQLite User & Stats DB)
```

### Technology Stack

- **Client Application:** Flutter (Dart), Provider state management, HTML5/Canvas & Native graphics pipelines.
- **Backend Services:** Cloudflare Workers, Cloudflare Pages Functions, Cloudflare Durable Objects (WebSocket state handling), Cloudflare D1 (Serverless SQLite).
- **Authentication:** Google OAuth 2.0 API.
- **Continuous Integration & Delivery:** GitHub Actions (Automated web builds, Android AAB keystore signing, deployment workflows).

---

## Directory Structure

```text
.
├── yut_flutter/        # Main cross-platform Flutter application source code
│   ├── lib/
│   │   ├── domain/     # Core game engine logic (board topology, AI bot, rules)
│   │   └── main.dart   # UI layer, game screens, shop, and state management
│   ├── assets/         # Audio clips, board themes, piece textures, and icons
│   └── web/            # PWA manifest, service workers, and index.html
├── yut_multiplayer/    # Real-time WebSocket game server (Cloudflare Durable Objects)
│   └── src/
│       └── index.js    # YutGameRoom and YutLobby Durable Object definitions
├── functions/          # Cloudflare Pages Functions API endpoints
│   └── api/
│       ├── auth.js     # Google Sign-In backend verification & account sync
│       └── ws/         # Edge WebSocket connection dispatcher
├── app/                # Native Android module
├── wrangler.toml       # Cloudflare Pages configuration & D1/Durable Object bindings
└── README.md           # Project documentation
```

---

## How to Work with the Source Code

### Prerequisites

Ensure you have the following tools installed on your development system:

- **Flutter SDK** (v3.12.0 or higher)
- **Dart SDK** (v3.0.0 or higher)
- **Node.js** (v18.0.0 or higher) and **npm**
- **Android Studio** (for Android builds and native code editing)
- **Wrangler CLI** (Cloudflare developer platform CLI): `npm install -g wrangler`

---

### Running the Flutter Client

1. Navigate to the Flutter project directory:
   ```bash
   cd yut_flutter
   ```

2. Fetch project dependencies:
   ```bash
   flutter pub get
   ```

3. Launch the application:
   ```bash
   # Run on Chrome (Web)
   flutter run -d chrome

   # Run on connected Android device or emulator
   flutter run -d android
   ```

4. Build release binaries:
   ```bash
   # Web PWA release build
   flutter build web --release

   # Android App Bundle (.aab) release build
   flutter build appbundle --release
   ```

---

### Working in Android Studio

To work with the project directly inside Android Studio:

1. Download Android Studio and ensure all required SDK Tools are updated.
2. Clone or extract the repository files.
3. Open Android Studio and select **"Open an existing Android Studio project"** (or **"Open..."**).
4. Select the project root folder (or `yut_flutter/android` for the Flutter Android target) and click **OK**.
5. If Gradle flags any SDK or version updates, follow the prompts to sync and update Gradle dependencies.

---

### Running the Multiplayer Backend

1. Navigate to the multiplayer directory:
   ```bash
   cd yut_multiplayer
   ```

2. Install Node dependencies:
   ```bash
   npm install
   ```

3. Start the local Cloudflare Worker development environment:
   ```bash
   npx wrangler dev
   ```

---

## License & Copyright Notice

Copyright (c) 2026 Jeffrey Chan. All Rights Reserved.

This project, including all source code, assets, graphics, and documentation, is proprietary software belonging to Jeffrey Chan. Unintended copying, redistribution, modification, or commercial exploitation without explicit written permission is strictly prohibited.
