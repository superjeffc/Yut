export async function onRequest(context) {
  const request = context.request;
  const env = context.env;

  if (request.headers.get("Upgrade") !== "websocket") {
    return new Response("Expected Upgrade: websocket", { status: 426 });
  }

  // Route to the YUT_LOBBY Durable Object singleton instance
  const id = env.YUT_LOBBY.idFromName("global_lobby");
  const stub = env.YUT_LOBBY.get(id);

  return stub.fetch(request);
}
