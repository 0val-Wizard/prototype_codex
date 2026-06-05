import { createServer as createHttpServer } from "node:http";
import { createServer as createHttpsServer } from "node:https";
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
const visionModel = process.env.OPENAI_VISION_MODEL || env.OPENAI_VISION_MODEL || "gpt-4.1-mini";
const safetyIdentifier =
  process.env.OPENAI_SAFETY_IDENTIFIER || env.OPENAI_SAFETY_IDENTIFIER || "demo-user";
const host = process.env.HOST || env.HOST || "0.0.0.0";
const httpsPort = Number(process.env.HTTPS_PORT || env.HTTPS_PORT || port);
const tlsKeyPath = process.env.SSL_KEY_FILE || env.SSL_KEY_FILE;
const tlsCertPath = process.env.SSL_CERT_FILE || env.SSL_CERT_FILE;

const sessionConfig = JSON.stringify({
  type: "realtime",
  model,
  audio: {
    output: {
      voice,
    },
  },
  instructions:
    "You are Shopee's universal shopping agent. Use the available tools to classify need, analyze surroundings when the user asks about what they are seeing, search the catalog, and add items to cart. Do not invent products or prices.",
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

const requestHandler = async (req, res) => {
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

    if (req.method === "POST" && url.pathname === "/api/tools/analyze-surroundings") {
      const body = await parseJsonBody(req);
      respondJson(res, 200, await analyzeSurroundings(body));
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
};

const httpsOptions = await loadHttpsOptions();
if (httpsOptions) {
  const server = createHttpsServer(httpsOptions, requestHandler);
  server.listen(httpsPort, host, () => {
    console.log(`Shopee agent server listening on https://${host}:${httpsPort}`);
  });
} else {
  const server = createHttpServer(requestHandler);
  server.listen(port, host, () => {
    console.log(`Shopee agent server listening on http://${host}:${port}`);
    console.log("HTTPS is disabled. Set SSL_KEY_FILE and SSL_CERT_FILE in .env to enable TLS.");
  });
}

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

async function loadHttpsOptions() {
  if (!tlsKeyPath || !tlsCertPath) {
    return null;
  }

  return {
    key: await readFile(resolvePath(tlsKeyPath)),
    cert: await readFile(resolvePath(tlsCertPath)),
  };
}

function resolvePath(filePath) {
  return filePath.startsWith("/") ? filePath : join(__dirname, filePath);
}

async function analyzeSurroundings({ question = "", imageBase64 = "", mimeType = "image/jpeg" }) {
  if (!question.trim()) {
    return {
      summary: "No camera question was provided.",
      visualClues: [],
      suggestedSearchTerms: [],
    };
  }

  if (!imageBase64) {
    return {
      summary: "Camera capture is unavailable. Open the camera view and try again.",
      visualClues: [],
      suggestedSearchTerms: [],
    };
  }

  if (!apiKey) {
    return {
      summary: "The backend is missing OPENAI_API_KEY, so surroundings analysis is unavailable.",
      visualClues: [],
      suggestedSearchTerms: [],
    };
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "OpenAI-Safety-Identifier": safetyIdentifier,
    },
    body: JSON.stringify({
      model: visionModel,
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text:
                "You analyze mobile camera scenes for a shopping assistant. Return JSON only with keys: summary (string), visualClues (array of short strings), suggestedSearchTerms (array of short strings), and confidence (number from 0 to 1). Be concrete, avoid overclaiming, and mention uncertainty when visibility is limited.",
            },
          ],
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: `User question: ${question}`,
            },
            {
              type: "input_image",
              image_url: `data:${mimeType};base64,${imageBase64}`,
            },
          ],
        },
      ],
    }),
  });

  const responseText = await response.text();
  if (!response.ok) {
    return {
      summary: `Surroundings analysis failed: ${responseText}`,
      visualClues: [],
      suggestedSearchTerms: [],
    };
  }

  const payload = JSON.parse(responseText);
  const outputText = payload.output_text || extractResponseText(payload);

  try {
    const parsed = JSON.parse(outputText);
    return {
      summary: parsed.summary || "I analyzed the current scene.",
      visualClues: Array.isArray(parsed.visualClues) ? parsed.visualClues : [],
      suggestedSearchTerms: Array.isArray(parsed.suggestedSearchTerms) ? parsed.suggestedSearchTerms : [],
      confidence: typeof parsed.confidence === "number" ? parsed.confidence : undefined,
    };
  } catch {
    return {
      summary: outputText || "I analyzed the current scene, but the response could not be structured.",
      visualClues: [],
      suggestedSearchTerms: [],
    };
  }
}

function extractResponseText(payload) {
  if (!Array.isArray(payload?.output)) {
    return "";
  }

  const parts = [];
  for (const item of payload.output) {
    if (!Array.isArray(item?.content)) {
      continue;
    }

    for (const contentItem of item.content) {
      if (typeof contentItem?.text === "string") {
        parts.push(contentItem.text);
      }
    }
  }

  return parts.join("\n").trim();
}
