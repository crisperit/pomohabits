import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { McpServer } from "npm:@modelcontextprotocol/sdk@^1/server/mcp.js";
import { WebStandardStreamableHTTPServerTransport } from "npm:@modelcontextprotocol/sdk@^1/server/webStandardStreamableHttp.js";
import { Hono } from "npm:hono@^4";
import { z } from "npm:zod@^4";
import {
  authenticate,
  clientForUser,
  UnauthorizedError,
} from "../_shared/auth.ts";

// ---------------------------------------------------------------------------
// Hono app
//
// A fresh McpServer is created per request so that tool handlers can close
// over the validated per-request JWT. The MCP SDK does not expose a
// per-request context channel through registerTool, so building the server
// inside the handler is the correct pattern when auth context is required.
// ---------------------------------------------------------------------------

const app = new Hono();

app.all("*", async (c) => {
  // 1. Authenticate before the MCP transport sees anything.
  let jwt: string;
  try {
    const result = await authenticate(c.req.raw);
    jwt = result.jwt;
  } catch (err) {
    if (err instanceof UnauthorizedError) {
      return c.json({ error: "unauthorized" }, 401);
    }
    console.error("Unexpected auth error:", err);
    return c.json({ error: "internal_server_error" }, 500);
  }

  // 2. Build a request-scoped MCP server whose tool handlers close over jwt.
  const server = new McpServer({
    name: "taskodoro-mcp",
    version: "0.1.0",
  });

  // Tool: list_tasks
  server.registerTool(
    "list_tasks",
    {
      title: "List Tasks",
      description:
        "List the caller's tasks with per-task completion flags for today and ever.",
      inputSchema: {
        timezone: z
          .string()
          .optional()
          .default("UTC")
          .describe(
            "IANA timezone name used to compute completed_today (default: UTC).",
          ),
      },
    },
    async ({ timezone }) => {
      const client = clientForUser(jwt);
      const { data, error } = await client.rpc("list_tasks", {
        p_timezone: timezone ?? "UTC",
      });
      if (error) {
        return {
          isError: true,
          content: [{ type: "text", text: error.message }],
        };
      }
      return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
      };
    },
  );

  // Tool: add_task
  server.registerTool(
    "add_task",
    {
      title: "Add Task",
      description:
        "Insert a new task scoped to the caller. Returns the inserted row.",
      inputSchema: {
        name: z.string().min(1),
        category: z.enum(["one_time", "daily", "unlimited"]),
        applicable_break_window: z.enum(["short", "long", "both"]),
        always_shown: z.boolean(),
        icon: z.string().max(16).optional(),
      },
    },
    async ({ name, category, applicable_break_window, always_shown, icon }) => {
      const client = clientForUser(jwt);
      const { data, error } = await client.rpc("add_task", {
        p_name: name,
        p_category: category,
        p_applicable_break_window: applicable_break_window,
        p_always_shown: always_shown,
        p_icon: icon ?? null,
      });
      if (error) {
        return {
          isError: true,
          content: [{ type: "text", text: error.message }],
        };
      }
      return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
      };
    },
  );

  // Tool: complete_task
  server.registerTool(
    "complete_task",
    {
      title: "Complete Task",
      description:
        "Record a completion event for the given task. Caller must own the task.",
      inputSchema: {
        task_id: z.string().uuid(),
      },
    },
    async ({ task_id }) => {
      const client = clientForUser(jwt);
      const { data, error } = await client.rpc("complete_task", {
        p_task_id: task_id,
      });
      if (error) {
        return {
          isError: true,
          content: [{ type: "text", text: error.message }],
        };
      }
      return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
      };
    },
  );

  // 3. Connect a fresh transport and handle the request.
  try {
    const transport = new WebStandardStreamableHTTPServerTransport();
    await server.connect(transport);
    return transport.handleRequest(c.req.raw);
  } catch (err) {
    console.error("MCP transport error:", err);
    return c.json({ error: "internal_server_error" }, 500);
  }
});

Deno.serve(app.fetch);
