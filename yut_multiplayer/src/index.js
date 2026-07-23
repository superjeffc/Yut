import { DurableObject } from "cloudflare:workers";

// Matchmaking Queue Lobby Singleton
export class YutLobby extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.waitingPlayer = null; // Stores { ws, email, name, avatar }
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket Upgrade", { status: 426 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    const url = new URL(request.url);
    const email = url.searchParams.get("email") || "";
    const name = url.searchParams.get("name") || "Player";
    const avatar = url.searchParams.get("avatar") || "seal";

    server.accept();

    // Check if another player is already waiting
    if (this.waitingPlayer && this.waitingPlayer.email !== email) {
      const matchRoomId = "room_" + Math.random().toString(36).substring(2, 10);
      
      const p1 = this.waitingPlayer;
      this.waitingPlayer = null;

      // Notify both players of match completion
      try {
        p1.ws.send(JSON.stringify({
          type: "matched",
          room: matchRoomId,
          playerIndex: 0,
          opponent: { name, avatar }
        }));
        p1.ws.close();
      } catch (_) {}

      try {
        server.send(JSON.stringify({
          type: "matched",
          room: matchRoomId,
          playerIndex: 1,
          opponent: { name: p1.name, avatar: p1.avatar }
        }));
        server.close();
      } catch (_) {}
    } else {
      // Put this player in the waiting slot
      this.waitingPlayer = {
        ws: server,
        email,
        name,
        avatar
      };
      
      server.send(JSON.stringify({ type: "waiting" }));

      server.addEventListener("close", () => {
        if (this.waitingPlayer && this.waitingPlayer.ws === server) {
          this.waitingPlayer = null;
        }
      });
    }

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
  }
}

// Stateful Game Room Object
export class YutGameRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.players = [null, null]; // [player0, player1] where player is { ws, email, name, avatar }
    this.gameState = {
      turn: 0,
      p1Pieces: [-1, -1, -1, -1],
      p2Pieces: [-1, -1, -1, -1],
      rollsLeft: [],
      canRoll: true,
      isGameOver: false,
      winnerIndex: -1
    };
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket Upgrade", { status: 426 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    const url = new URL(request.url);
    const playerIndex = parseInt(url.searchParams.get("playerIndex") || "0", 10);
    const email = url.searchParams.get("email") || "";
    const name = url.searchParams.get("name") || "Player";
    const avatar = url.searchParams.get("avatar") || "seal";

    server.accept();

    this.players[playerIndex] = {
      ws: server,
      email,
      name,
      avatar
    };

    // If both players connected, broadcast initialization
    if (this.players[0] && this.players[1]) {
      this.broadcast({
        type: "init",
        players: [
          { name: this.players[0].name, avatar: this.players[0].avatar },
          { name: this.players[1].name, avatar: this.players[1].avatar }
        ],
        state: this.gameState
      });
    }

    server.addEventListener("message", (msg) => {
      try {
        const action = JSON.parse(msg.data);
        this.handleGameAction(playerIndex, action);
      } catch (_) {}
    });

    server.addEventListener("close", () => {
      this.players[playerIndex] = null;
      this.broadcast({
        type: "opponent_disconnected",
        playerIndex
      });
    });

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
  }

  handleGameAction(playerIndex, action) {
    if (this.gameState.isGameOver) return;

    if (action.type === "ROLL_RESULT") {
      // Validate turn
      if (this.gameState.turn !== playerIndex || !this.gameState.canRoll) return;

      const roll = action.rollName;
      this.gameState.rollsLeft.push(roll);

      // Mo or Yut grants an extra roll
      if (roll === "Yut" || roll === "Mo") {
        this.gameState.canRoll = true;
      } else {
        this.gameState.canRoll = false;
      }

      this.broadcast({
        type: "state",
        state: this.gameState
      });
    } 
    else if (action.type === "MOVE") {
      // Validate turn
      if (this.gameState.turn !== playerIndex) return;

      this.gameState.p1Pieces = action.p1Pieces;
      this.gameState.p2Pieces = action.p2Pieces;

      // Remove consumed roll
      const rollIdx = this.gameState.rollsLeft.indexOf(action.rollUsed);
      if (rollIdx !== -1) {
        this.gameState.rollsLeft.splice(rollIdx, 1);
      }

      this.gameState.turn = action.nextTurn;

      // Check if all pieces finished (position 32)
      const p1Finished = this.gameState.p1Pieces.every(pos => pos === 32);
      const p2Finished = this.gameState.p2Pieces.every(pos => pos === 32);

      if (p1Finished) {
        this.gameState.isGameOver = true;
        this.gameState.winnerIndex = 0;
      } else if (p2Finished) {
        this.gameState.isGameOver = true;
        this.gameState.winnerIndex = 1;
      }

      // If no rolls left, allow rolling again
      if (this.gameState.rollsLeft.length === 0) {
        this.gameState.canRoll = true;
      }

      this.broadcast({
        type: "state",
        state: this.gameState
      });
    }
  }

  broadcast(message) {
    const payload = JSON.stringify(message);
    for (const player of this.players) {
      if (player && player.ws) {
        try {
          player.ws.send(payload);
        } catch (_) {}
      }
    }
  }
}

// Router worker
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/lobby") {
      const id = env.YUT_LOBBY.idFromName("global_lobby");
      const stub = env.YUT_LOBBY.get(id);
      return stub.fetch(request);
    } 
    else if (url.pathname === "/game") {
      const room = url.searchParams.get("room");
      if (!room) {
        return new Response("Missing room parameter", { status: 400 });
      }
      const id = env.YUT_GAME_ROOM.idFromName(room);
      const stub = env.YUT_GAME_ROOM.get(id);
      return stub.fetch(request);
    }

    return new Response("Not found", { status: 404 });
  }
};
