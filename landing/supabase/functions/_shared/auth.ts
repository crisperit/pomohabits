import { createClient, type User } from "npm:@supabase/supabase-js@^2";

// ---------------------------------------------------------------------------
// Boot-time env validation
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY must be set");
}

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

const baseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
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
  return createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
