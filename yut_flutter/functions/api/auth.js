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

  // Handle client_id action (GET)
  if (request.method === "GET" && action === "client_id") {
    return new Response(
      JSON.stringify({ clientId: env.GOOGLE_CLIENT_ID || "" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const db = env.DB;
    if (!db) {
      return new Response(JSON.stringify({ error: "Database binding DB not found" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await request.json();

    if (action === "google") {
      const { token } = body;
      if (!token) {
        return new Response(JSON.stringify({ error: "Google ID Token is required" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Verify token with Google's tokeninfo API
      const verifyRes = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${token}`);
      if (!verifyRes.ok) {
        return new Response(JSON.stringify({ error: "Invalid Google ID Token" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const payload = await verifyRes.json();
      const googleId = payload.sub;
      const email = payload.email;
      const name = payload.name || "";

      // Check if user exists in D1 SQL
      let user = await db.prepare("SELECT * FROM users WHERE google_id = ?").bind(googleId).first();

      const localCoins = body.coins || 0;
      const localAnimals = (body.unlockedAnimals || "Seal Penguin").split(" ").filter(Boolean);
      const localGames = body.games || 0;
      const localWins = body.wins || 0;
      const localLosses = body.losses || 0;

      if (!user) {
        // Create user
        await db.prepare(
          "INSERT INTO users (google_id, email, name, coins, unlocked_animals, games, wins, losses) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(googleId, email, name, localCoins, localAnimals.join(" "), localGames, localWins, localLosses)
        .run();

        user = {
          coins: localCoins,
          unlocked_animals: localAnimals.join(" "),
          games: localGames,
          wins: localWins,
          losses: localLosses
        };
      }

      const dbCoins = user.coins || 0;
      const dbAnimals = (user.unlocked_animals || "Seal Penguin").split(" ").filter(Boolean);
      const dbGames = user.games || 0;
      const dbWins = user.wins || 0;
      const dbLosses = user.losses || 0;

      // Merge (take max/union)
      const mergedCoins = Math.max(localCoins, dbCoins);
      const mergedAnimalsSet = new Set([...localAnimals, ...dbAnimals]);
      const mergedAnimals = Array.from(mergedAnimalsSet).join(" ");
      const mergedGames = Math.max(localGames, dbGames);
      const mergedWins = Math.max(localWins, dbWins);
      const mergedLosses = Math.max(localLosses, dbLosses);

      await db.prepare(
        "UPDATE users SET coins = ?, unlocked_animals = ?, games = ?, wins = ?, losses = ? WHERE google_id = ?"
      )
      .bind(mergedCoins, mergedAnimals, mergedGames, mergedWins, mergedLosses, googleId)
      .run();

      return new Response(
        JSON.stringify({
          success: true,
          googleId,
          email,
          name,
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
