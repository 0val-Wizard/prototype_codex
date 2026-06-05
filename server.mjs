import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import {
  addToCart,
  applyBestVoucher,
  checkoutPreview,
  classifyNeed,
  getBootstrap,
  getCartSnapshot,
  getToolDefinitions,
  runAgent,
  searchCatalog,
} from "./commerce.mjs";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const port = Number(process.env.PORT || 3000);

const env = await loadEnv(join(__dirname, ".env"));
const apiKey = process.env.OPENAI_API_KEY || env.OPENAI_API_KEY;
const model = process.env.OPENAI_REALTIME_MODEL || env.OPENAI_REALTIME_MODEL || "gpt-realtime-2";
const voice = process.env.OPENAI_REALTIME_VOICE || env.OPENAI_REALTIME_VOICE || "marin";
const safetyIdentifier =
  process.env.OPENAI_SAFETY_IDENTIFIER || env.OPENAI_SAFETY_IDENTIFIER || "demo-user";

const sessionConfig = JSON.stringify({
  type: "realtime",
  model,
  audio: {
    output: {
      voice,
    },
  },
  instructions:
    "You are Shopee's universal shopping agent. Use the available tools to classify need, search the catalog, and add items to cart. Do not invent products or prices.",
  tool_choice: "auto",
  tools: getToolDefinitions(),
});

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
};

const server = createServer(async (req, res) => {
  try {
    if (!req.url || !req.method) {
      respondText(res, 400, "Bad request");
      return;
    }

    const url = new URL(req.url, `http://${req.headers.host || "127.0.0.1"}`);

    if (req.method === "POST" && url.pathname === "/session") {
      await handleSession(req, res);
      return;
    }

    if (url.pathname === "/api/bootstrap" && req.method === "GET") {
      respondJson(res, 200, getBootstrap(url.searchParams.get("userId") || "u_001"));
      return;
    }

    if (url.pathname === "/api/cart" && req.method === "GET") {
      respondJson(
        res,
        200,
        getCartSnapshot({
          userId: url.searchParams.get("userId") || "u_001",
          category: url.searchParams.get("category") || undefined,
        })
      );
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/agent") {
      const body = await parseJsonBody(req);
      respondJson(res, 200, runAgent(body));
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/tools/classify-need") {
      const body = await parseJsonBody(req);
      respondJson(res, 200, classifyNeed(body));
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/tools/search-catalog") {
      const body = await parseJsonBody(req);
      respondJson(res, 200, searchCatalog(body));
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/tools/add-to-cart") {
      const body = await parseJsonBody(req);
      const cartResult = addToCart(body);
      const voucherResult = applyBestVoucher({
        cart: cartResult.cart,
        category: body.category,
      });
      const preview = checkoutPreview({
        cart: cartResult.cart,
        voucher: voucherResult.voucher,
      });
      respondJson(res, 200, {
        ...cartResult,
        appliedVoucher: voucherResult.voucher,
        discount: voucherResult.discount,
        checkoutPreview: preview,
      });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/tools/apply-voucher") {
      const body = await parseJsonBody(req);
      respondJson(res, 200, applyBestVoucher(body));
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/tools/checkout-preview") {
      const body = await parseJsonBody(req);
      respondJson(res, 200, checkoutPreview(body));
      return;
    }

    if (req.method === "GET") {
      await handleStatic(url.pathname, res);
      return;
    }

    respondText(res, 405, "Method not allowed");
  } catch (error) {
    console.error(error);
    respondJson(res, 500, { error: "Internal server error", detail: error.message });
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Shopee agent server listening on http://0.0.0.0:${port}`);
});

async function handleSession(req, res) {
  if (!apiKey) {
    respondJson(res, 500, { error: "Server is missing OPENAI_API_KEY" });
    return;
  }

  const sdp = await readRequestBody(req);
  const formData = new FormData();
  formData.set("sdp", sdp);
  formData.set("session", sessionConfig);

  const openAIResponse = await fetch("https://api.openai.com/v1/realtime/calls", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "OpenAI-Safety-Identifier": safetyIdentifier,
    },
    body: formData,
  });

  const responseText = await openAIResponse.text();
  if (!openAIResponse.ok) {
    res.writeHead(openAIResponse.status, {
      "Content-Type": "text/plain; charset=utf-8",
    });
    res.end(responseText);
    return;
  }

  res.writeHead(200, {
    "Content-Type": "application/sdp",
  });
  res.end(responseText);
}

async function handleStatic(pathname, res) {
  const safePath = pathname === "/" ? "/index.html" : pathname;
  const normalized = normalize(safePath).replace(/^(\.\.[/\\])+/, "");
  const filePath = join(__dirname, normalized);

  try {
    const contents = await readFile(filePath);
    res.writeHead(200, {
      "Content-Type": mimeTypes[extname(filePath)] || "application/octet-stream",
    });
    res.end(contents);
  } catch {
    respondText(res, 404, "Not found");
  }
}

function respondText(res, statusCode, body) {
  res.writeHead(statusCode, {
    "Content-Type": "text/plain; charset=utf-8",
  });
  res.end(body);
}

function respondJson(res, statusCode, body) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
  });
  res.end(JSON.stringify(body));
}

async function readRequestBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function parseJsonBody(req) {
  const text = await readRequestBody(req);
  return text ? JSON.parse(text) : {};
}

async function loadEnv(filePath) {
  try {
    const contents = await readFile(filePath, "utf8");
    return Object.fromEntries(
      contents
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line && !line.startsWith("#") && line.includes("="))
        .map((line) => {
          const index = line.indexOf("=");
          return [line.slice(0, index), line.slice(index + 1)];
        })
    );
  } catch {
    return {};
  }
}
