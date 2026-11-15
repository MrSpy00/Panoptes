// ============================================================================
// PANOPTES — OPTIONAL SUPABASE EDGE FUNCTION (osint-worker)
// Executes heavy multi-platform username & domain probes when invoked by client
// ============================================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

interface ReconRequest {
  handle: string;
  fullName?: string;
  city?: string;
}

const TARGET_SITES = [
  { name: "GitHub", url: (u: string) => `https://api.github.com/users/${u}` },
  { name: "GitLab", url: (u: string) => `https://gitlab.com/api/v4/users?username=${u}` },
  { name: "Keybase", url: (u: string) => `https://keybase.io/_/api/1.0/user/lookup.json?usernames=${u}` },
  { name: "Reddit", url: (u: string) => `https://www.reddit.com/user/${u}/about.json` },
  { name: "Dev.to", url: (u: string) => `https://dev.to/api/users/by_username?url=${u}` },
];

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const body = (await req.json()) as ReconRequest;
    const handle = (body.handle || "").trim().replace(/^@/, "");
    if (!handle) {
      return new Response(JSON.stringify({ error: "Missing handle" }), { status: 400 });
    }

    const checks = await Promise.all(
      TARGET_SITES.map(async (site) => {
        try {
          const resp = await fetch(site.url(encodeURIComponent(handle)), {
            headers: { "User-Agent": "Panoptes-Edge-Worker/1.0" },
          });
          return {
            source: site.name,
            url: site.url(handle),
            status: resp.status,
            found: resp.status === 200,
          };
        } catch {
          return { source: site.name, url: site.url(handle), status: 0, found: false };
        }
      }),
    );

    return new Response(
      JSON.stringify({
        handle,
        timestamp: new Date().toISOString(),
        results: checks.filter((c) => c.found),
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
