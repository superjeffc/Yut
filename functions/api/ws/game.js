export async function onRequest(context) {
  const request = context.request;
  const env = context.env;

  if (request.headers.get("Upgrade") !== "websocket") {
    return new Response("Expected Upgrade: websocket", { status: 426 });
  }

  const url = new URL(request.url);
  const room = url.searchParams.get("room");
  if (!room) {
    return new Response("Missing room parameter", { status: 400 });
  }

  // Route to the YUT_GAME_ROOM Durable Object instance for this room
  const id = env.YUT_GAME_ROOM.idFromName(room);
  const stub = env.YUT_GAME_ROOM.get(id);

  return stub.fetch(request);
}
