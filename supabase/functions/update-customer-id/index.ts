Deno.serve(async (req: Request): Promise<Response> => {
  const badRequest = (msg: string) =>
    new Response(JSON.stringify({ error: msg }), { status: 400 });

  const serverError = (msg: string) =>
    new Response(JSON.stringify({ error: msg }), { status: 500 });

  try {
    const textBody = await req.text();
    const { user_id, stripe_customer_id } = JSON.parse(textBody);

    if (!user_id || !stripe_customer_id) {
      return badRequest("Missing user_id or stripe_customer_id");
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    const headers = {
      apikey: supabaseKey!,
      Authorization: `Bearer ${supabaseKey}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    };

    const updateRes = await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${user_id}`, {
      method: "PATCH",
      headers,
      body: JSON.stringify({ stripe_customer_id }),
    });

    const resBody = await updateRes.json();

    return new Response(
      JSON.stringify({ success: true, data: resBody }),
      { status: updateRes.status }
    );

  } catch (e) {
    return serverError(e instanceof Error ? e.message : String(e));
  }
});
