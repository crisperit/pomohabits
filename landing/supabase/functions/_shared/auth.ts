import { createClient, type User } from "npm:@supabase/supabase-js@^2";

// ---------------------------------------------------------------------------
// Boot-time env validation
// ---------------------------------------------------------------------------

// Supabase auto-injects SUPABASE_PUBLISHABLE_KEYS (JSON dict) as the new default
// and SUPABASE_ANON_KEY as legacy-but-still-supported. Local CLI still ships
// the legacy var only as of 2026-05-24; the fallback keeps `supabase functions
// serve` working until the local stack catches up.
function resolveProjectKey(): string {
  const dictRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (dictRaw && dictRaw.length > 0) {
    let dict: Record<string, string>;
    try {
      dict = JSON.parse(dictRaw);
    } catch (err) {
      throw new Error(
        `SUPABASE_PUBLISHABLE_KEYS must be valid JSON: ${(err as Error).message}`,
      );
    }
    const key = dict["default"];
    if (!key) {
      throw new Error(`SUPABASE_PUBLISHABLE_KEYS has no "default" entry`);
    }
    return key;
  }
  const legacy = Deno.env.get("SUPABASE_ANON_KEY");
  if (legacy && legacy.length > 0) return legacy;
  throw new Error(
    "Neither SUPABASE_PUBLISHABLE_KEYS nor SUPABASE_ANON_KEY is set",
  );
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
if (!SUPABASE_URL) throw new Error("SUPABASE_URL must be set");

const SUPABASE_PROJECT_KEY = resolveProjectKey();

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

export class UnauthorizedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "UnauthorizedError";
  }
}

// ---------------------------------------------------------------------------
// A base anon client used only to validate incoming JWTs.
// It carries no user context of its own.
// ---------------------------------------------------------------------------

const baseClient = createClient(SUPABASE_URL, SUPABASE_PROJECT_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// ---------------------------------------------------------------------------
// authenticate
//
// Extracts the Bearer JWT from the incoming request, validates it against
// Supabase Auth (getUser), and returns both the resolved User and the raw JWT
// string so callers can build a per-request client with full row-level-security
// context.
//
// Throws UnauthorizedError when the header is absent or the token is invalid.
// ---------------------------------------------------------------------------

export async function authenticate(
  req: Request,
): Promise<{ user: User; jwt: string }> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new UnauthorizedError("Missing or malformed Authorization header");
  }

  const jwt = authHeader.slice("Bearer ".length).trim();
  if (!jwt) {
    throw new UnauthorizedError("Empty JWT in Authorization header");
  }

  const { data, error } = await baseClient.auth.getUser(jwt);
  if (error || !data.user) {
    throw new UnauthorizedError(
      error?.message ?? "JWT validation failed: no user returned",
    );
  }

  return { user: data.user, jwt };
}

// ---------------------------------------------------------------------------
// clientForUser
//
// Creates a supabase-js client that forwards the caller's JWT in the
// Authorization header. Because the RPC functions are security invoker and
// call auth.uid() internally, every RPC must be invoked through this client
// rather than a service-role client.
// ---------------------------------------------------------------------------

export function clientForUser(jwt: string) {
  return createClient(SUPABASE_URL!, SUPABASE_PROJECT_KEY!, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
