import { spawn } from "node:child_process";
import { readFile, stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = fileURLToPath(new URL("../", import.meta.url));
const publicDir = fileURLToPath(new URL("./public/", import.meta.url));
const host = process.env.HOST ?? "127.0.0.1";
const port = Number(process.env.PORT ?? "4173");
const maxBytes = 256 * 1024;

const mimeByExt = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".txt", "text/plain; charset=utf-8"],
]);

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  res.end(JSON.stringify(payload));
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        reject(new Error("Request body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      try {
        const text = Buffer.concat(chunks).toString("utf-8");
        resolve(JSON.parse(text));
      } catch (error) {
        reject(new Error("Invalid JSON body"));
      }
    });
    req.on("error", reject);
  });
}

function runMoonRender(diagram) {
  return new Promise((resolve, reject) => {
    const args = ["run", "cmd/main", "--target", "js", "--", diagram];
    const child = spawn("moon", args, { cwd: rootDir });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf-8");
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf-8");
    });
    child.on("error", reject);

    child.on("close", (code) => {
      const output = stdout.trim();
      if (code !== 0) {
        const detail = [stderr.trim(), output].filter(Boolean).join("\n");
        resolve({ ok: false, error: detail || "Renderer process failed" });
        return;
      }
      if (output.startsWith("<svg")) {
        resolve({ ok: true, svg: output });
        return;
      }
      if (output.startsWith("Error:")) {
        resolve({ ok: false, error: output });
        return;
      }
      resolve({
        ok: false,
        error: output || stderr.trim() || "Unexpected renderer output",
      });
    });
  });
}

async function serveStatic(req, res) {
  const url = new URL(req.url ?? "/", `http://${host}:${port}`);
  let requestPath = url.pathname;
  if (requestPath === "/") {
    requestPath = "/index.html";
  }

  const fullPath = normalize(join(publicDir, requestPath));
  if (!fullPath.startsWith(publicDir)) {
    res.writeHead(403, { "content-type": "text/plain; charset=utf-8" });
    res.end("Forbidden");
    return;
  }

  let fileStat;
  try {
    fileStat = await stat(fullPath);
  } catch {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("Not Found");
    return;
  }

  if (!fileStat.isFile()) {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("Not Found");
    return;
  }

  const body = await readFile(fullPath);
  const ext = extname(fullPath);
  res.writeHead(200, {
    "content-type": mimeByExt.get(ext) ?? "application/octet-stream",
    "cache-control": "no-store",
  });
  res.end(body);
}

const server = createServer(async (req, res) => {
  try {
    const method = req.method ?? "GET";
    const url = new URL(req.url ?? "/", `http://${host}:${port}`);

    if (method === "POST" && url.pathname === "/api/render") {
      const body = await readJsonBody(req);
      if (typeof body?.diagram !== "string") {
        sendJson(res, 400, { ok: false, error: "Field `diagram` must be a string." });
        return;
      }
      if (body.diagram.length > 40_000) {
        sendJson(res, 413, { ok: false, error: "Diagram text is too large (max 40k chars)." });
        return;
      }
      const rendered = await runMoonRender(body.diagram);
      sendJson(res, rendered.ok ? 200 : 422, rendered);
      return;
    }

    if (method !== "GET" && method !== "HEAD") {
      res.writeHead(405, { "content-type": "text/plain; charset=utf-8" });
      res.end("Method Not Allowed");
      return;
    }

    await serveStatic(req, res);
  } catch (error) {
    sendJson(res, 500, {
      ok: false,
      error: error instanceof Error ? error.message : "Unknown server error",
    });
  }
});

server.listen(port, host, () => {
  console.log(`Mermaid playground: http://${host}:${port}`);
});
