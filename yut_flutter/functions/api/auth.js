export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const action = url.searchParams.get("action");

  // Allow CORS
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, HEAD, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };

  if (request.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const body = await request.json();
    const { username, password } = body;

    if (!username || !password || username.trim() === "" || password.trim() === "") {
      return new Response(JSON.stringify({ error: "Username and password are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const db = env.DB;
    if (!db) {
      return new Response(JSON.stringify({ error: "Database binding DB not found" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const passwordHash = await hashPassword(password);

    if (action === "register") {
      // Check if user exists
      const existing = await db.prepare("SELECT username FROM users WHERE username = ?").bind(username).first();
      if (existing) {
        return new Response(JSON.stringify({ error: "Username already exists" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const coins = body.coins || 0;
      const unlockedAnimals = body.unlockedAnimals || "Seal Penguin";
      const games = body.games || 0;
      const wins = body.wins || 0;
      const losses = body.losses || 0;

      await db.prepare(
        "INSERT INTO users (username, password_hash, coins, unlocked_animals, games, wins, losses) VALUES (?, ?, ?, ?, ?, ?, ?)"
      )
      .bind(username, passwordHash, coins, unlockedAnimals, games, wins, losses)
      .run();

      return new Response(JSON.stringify({ success: true, message: "Account registered successfully!" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } 
    
    else if (action === "login" || action === "sync") {
      const user = await db.prepare("SELECT * FROM users WHERE username = ?").bind(username).first();
      if (!user) {
        return new Response(JSON.stringify({ error: "User not found" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if (user.password_hash !== passwordHash) {
        return new Response(JSON.stringify({ error: "Invalid password" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const localCoins = body.coins || 0;
      const localAnimals = (body.unlockedAnimals || "Seal Penguin").split(" ").filter(Boolean);
      const localGames = body.games || 0;
      const localWins = body.wins || 0;
      const localLosses = body.losses || 0;

      const dbCoins = user.coins || 0;
      const dbAnimals = (user.unlocked_animals || "Seal Penguin").split(" ").filter(Boolean);
      const dbGames = user.games || 0;
      const dbWins = user.wins || 0;
      const dbLosses = user.losses || 0;

      // Merge (take max of coins, wins, losses, games, union of unlocked animals)
      const mergedCoins = Math.max(localCoins, dbCoins);
      const mergedAnimalsSet = new Set([...localAnimals, ...dbAnimals]);
      const mergedAnimals = Array.from(mergedAnimalsSet).join(" ");
      const mergedGames = Math.max(localGames, dbGames);
      const mergedWins = Math.max(localWins, dbWins);
      const mergedLosses = Math.max(localLosses, dbLosses);

      await db.prepare(
        "UPDATE users SET coins = ?, unlocked_animals = ?, games = ?, wins = ?, losses = ? WHERE username = ?"
      )
      .bind(mergedCoins, mergedAnimals, mergedGames, mergedWins, mergedLosses, username)
      .run();

      return new Response(
        JSON.stringify({
          success: true,
          coins: mergedCoins,
          unlockedAnimals: mergedAnimals,
          games: mergedGames,
          wins: mergedWins,
          losses: mergedLosses,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ error: "Invalid action" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

async function hashPassword(password) {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
}
