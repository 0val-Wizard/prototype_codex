import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

const [products, sellers, vouchers, users] = await Promise.all([
  loadJson("data/products.json"),
  loadJson("data/sellers.json"),
  loadJson("data/vouchers.json"),
  loadJson("data/users.json"),
]);

const sessions = new Map();

const playbooks = {
  home_repair:
    "Prioritize compatibility, size, material, safety, and short repair bundles. Add a brief caution if the fix may need measurement verification.",
  beauty:
    "Prioritize skin type, routine fit, delivery speed, and non-medical language. Keep suggestions simple and practical.",
  fashion:
    "Prioritize color matching, style coherence, fit, and outfit compatibility with the user's existing pieces.",
  electronics:
    "Prioritize device compatibility, ports, seller reliability, and delivery speed. Ask a short clarifying question if the device port is unclear.",
  grocery:
    "Prioritize replenishment, price per unit, stock, and fast delivery.",
  home_decor:
    "Prioritize color palette, dimensions, and bundle potential.",
  general:
    "Help the user discover suitable products quickly and ask one clarifying question only if confidence is low.",
};

export function getBootstrap(userId = "u_001") {
  const cartSnapshot = getCartSnapshot({ userId });
  return {
    cartSnapshot,
    scenarios: [
      "My sink is leaking. What do I buy?",
      "I'm running low on moisturizer before an interview.",
      "What pants match these boots and a black jacket?",
    ],
  };
}

export function classifyNeed({ message = "", imageDescription = "" }) {
  const text = `${message} ${imageDescription}`.toLowerCase();
  const categoryMatchers = [
    ["home_repair", ["sink", "pipe", "leak", "repair", "pvc", "plumbing"]],
    ["beauty", ["moisturizer", "skincare", "dry skin", "barrier", "interview"]],
    ["fashion", ["boots", "jacket", "pants", "jeans", "outfit", "style"]],
    ["electronics", ["monitor", "laptop", "usb-c", "hdmi", "adapter", "cable"]],
    ["grocery", ["oats", "pantry", "grocery", "replenish", "breakfast"]],
    ["home_decor", ["decor", "room", "cushion", "lamp", "rug"]],
  ];

  let best = { category: "general", confidence: 0.35, reasoning: "No strong category signal found." };
  for (const [category, keywords] of categoryMatchers) {
    const matches = keywords.filter((keyword) => text.includes(keyword));
    if (!matches.length) {
      continue;
    }

    const confidence = Math.min(0.55 + matches.length * 0.1, 0.95);
    if (confidence > best.confidence) {
      best = {
        category,
        confidence,
        reasoning: `Matched keywords: ${matches.join(", ")}`,
      };
    }
  }

  return best;
}

export function extractVisualClues({ message = "", imageBase64 = "" }) {
  const text = message.toLowerCase();
  const clues = [];
  const possibleProducts = [];

  if (text.includes("sink") || text.includes("pipe") || text.includes("leak")) {
    clues.push("pipe", "leak", "PVC", "coupling");
    possibleProducts.push("PVC coupling", "sealant tape");
  }
  if (text.includes("moisturizer") || text.includes("skincare") || text.includes("dry skin")) {
    clues.push("moisturizer", "barrier repair", "dry skin");
    possibleProducts.push("barrier moisturizer", "facial mist");
  }
  if (text.includes("boots") || text.includes("jacket") || text.includes("pants")) {
    clues.push("dark denim", "smart casual", "boots");
    possibleProducts.push("dark denim jeans", "black belt");
  }
  if (text.includes("monitor") || text.includes("laptop")) {
    clues.push("display output", "adapter", "USB-C", "HDMI");
    possibleProducts.push("USB-C to HDMI adapter");
  }

  if (imageBase64) {
    clues.push("user image attached");
  }

  return {
    visualClues: clues,
    possibleProducts,
    uncertainty: clues.length ? "" : "No strong visual clues inferred from input.",
  };
}

export function searchCatalog({
  query = "",
  category,
  visualClues = [],
  budgetMax,
  minRating = 0,
  deliveryPreference = "any",
}) {
  const tokens = tokenize([query, ...visualClues].join(" "));
  const scored = products
    .map((product) => {
      let score = 0;
      const categoryMatch = Boolean(category && product.category === category);
      const keywordMatches = product.keywords.filter((keyword) => tokens.includes(keyword.toLowerCase()));

      if (categoryMatch) {
        score += 5;
      }
      score += keywordMatches.length * 2;
      if (product.rating >= 4.7) {
        score += 1;
      }
      if (product.delivery === "same_day" || product.delivery === "next_day") {
        score += 1;
      }
      if (product.stock > 0) {
        score += 1;
      } else {
        score -= 10;
      }
      if (deliveryPreference !== "any" && product.delivery === deliveryPreference) {
        score += 2;
      }
      if (budgetMax && product.price > budgetMax) {
        score -= 4;
      }
      if (product.rating < minRating) {
        score -= 5;
      }

      const enrichedProduct = enrichProduct(product);

      return {
        ...enrichedProduct,
        categoryMatch,
        reason: buildReason({
          ...enrichedProduct,
          keywordMatches,
        }),
        score,
        keywordMatches,
      };
    })
    .filter((product) => product.score > 0)
    .filter((product) => product.keywordMatches.length > 0 || (product.categoryMatch && product.score >= 7))
    .sort((a, b) => b.score - a.score)
    .slice(0, 5);

  return {
    products: scored,
    uiAction: scored.length ? "SHOW_PRODUCTS" : "ASK_CLARIFYING_QUESTION",
  };
}

export function rankProducts({ products: inputProducts = [], userPreference = {} }) {
  const rankedProducts = inputProducts
    .map((product) => {
      let score = product.score ?? 0;

      if (userPreference.deliveryPriority === "fast" && product.delivery === "same_day") {
        score += 2;
      }
      if (userPreference.budgetSensitivity === "high" && product.price < 15) {
        score += 1;
      }
      if (userPreference.budgetSensitivity === "low" && product.rating >= 4.7) {
        score += 1;
      }

      return {
        ...product,
        score,
        reason: buildReason(product),
      };
    })
    .sort((a, b) => b.score - a.score);

  return { rankedProducts };
}

export function recommendBundle({ primaryProductId }) {
  const primary = products.find((product) => product.id === primaryProductId);
  if (!primary?.bundleItems?.length) {
    return { bundle: [] };
  }

  return {
    bundle: primary.bundleItems
      .map((itemId) => products.find((product) => product.id === itemId))
      .filter(Boolean)
      .map(enrichProduct),
  };
}

export function addToCart({ userId = "u_001", cart, productIds = [] }) {
  const session = getSession(userId, cart);
  for (const productId of productIds) {
    const existing = session.cart.find((item) => item.productId === productId);
    if (existing) {
      existing.quantity += 1;
    } else {
      session.cart.push({ productId, quantity: 1 });
    }
  }

  return { cart: session.cart };
}

export function getCartSnapshot({ userId = "u_001", category } = {}) {
  const session = getSession(userId);
  const voucherResult = applyBestVoucher({
    cart: session.cart,
    category,
  });

  return {
    cart: hydrateCart(session.cart),
    appliedVoucher: voucherResult.voucher,
    discount: voucherResult.discount,
    checkoutPreview: checkoutPreview({
      cart: session.cart,
      voucher: voucherResult.voucher,
    }),
  };
}

export function applyBestVoucher({ cart = [], category }) {
  const cartProducts = hydrateCart(cart);
  const subtotal = cartProducts.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const eligible = vouchers
    .filter((voucher) => !voucher.category || voucher.category === category)
    .filter((voucher) => !voucher.minSpend || subtotal >= voucher.minSpend)
    .map((voucher) => ({
      voucher,
      discount: calculateVoucherDiscount(voucher, subtotal),
    }))
    .sort((a, b) => b.discount - a.discount);

  const best = eligible[0];
  return {
    voucher: best?.voucher,
    discount: best?.discount ?? 0,
  };
}

export function checkoutPreview({ cart = [], voucher }) {
  const cartProducts = hydrateCart(cart);
  const subtotal = cartProducts.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const discount = voucher ? calculateVoucherDiscount(voucher, subtotal) : 0;
  const shippingBase = subtotal > 0 ? 2.99 : 0;
  const shipping = voucher?.discountType === "free_shipping" ? 0 : shippingBase;
  const total = Math.max(0, subtotal - discount + shipping);
  const estimatedDelivery = cartProducts.some((item) => item.delivery === "same_day")
    ? "Same day for eligible items"
    : "Next day delivery";

  return {
    subtotal: roundMoney(subtotal),
    discount: roundMoney(discount),
    shipping: roundMoney(shipping),
    total: roundMoney(total),
    estimatedDelivery,
  };
}

export function runAgent({ message = "", imageBase64 = "", cart = [], userId = "u_001" }) {
  const visualResult = extractVisualClues({ message, imageBase64 });
  const classification = classifyNeed({
    message,
    imageDescription: visualResult.visualClues.join(", "),
  });
  const user = users.find((entry) => entry.user_id === userId);
  const searchResult = searchCatalog({
    query: message,
    category: classification.category,
    visualClues: visualResult.visualClues,
    minRating: 4.5,
    deliveryPreference: user?.preferences?.delivery_priority === "fast" ? "same_day" : "any",
  });
  const ranked = rankProducts({
    products: searchResult.products,
    userPreference: user?.preferences
      ? {
          deliveryPriority: user.preferences.delivery_priority,
          budgetSensitivity: user.preferences.budget_sensitivity,
        }
      : {},
  });

  const primary = ranked.rankedProducts[0];
  const bundle = primary ? recommendBundle({ primaryProductId: primary.id }).bundle : [];
  const reply = buildReply({
    message,
    classification,
    primary,
    bundle,
    playbook: playbooks[classification.category] || playbooks.general,
  });

  return {
    reply,
    category: classification.category,
    confidence: classification.confidence,
    reasoning: classification.reasoning,
    playbook: playbooks[classification.category] || playbooks.general,
    products: ranked.rankedProducts.slice(0, 3),
    suggestedBundle: bundle,
    cart,
    uiAction: ranked.rankedProducts.length ? "SHOW_PRODUCTS" : "ASK_CLARIFYING_QUESTION",
  };
}

export function getToolDefinitions() {
  return [
    {
      type: "function",
      name: "classify_need",
      description: "Classify the user's shopping need into a category before searching products.",
      parameters: {
        type: "object",
        properties: {
          message: { type: "string" },
          imageDescription: { type: "string" }
        },
        required: ["message"]
      }
    },
    {
      type: "function",
      name: "search_catalog",
      description: "Search the Shopee mock catalog using query, category, budget, rating, and delivery preferences.",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string" },
          category: { type: "string" },
          visualClues: { type: "array", items: { type: "string" } },
          budgetMax: { type: "number" },
          minRating: { type: "number" },
          deliveryPreference: { type: "string", enum: ["same_day", "next_day", "any"] }
        },
        required: ["query"]
      }
    },
    {
      type: "function",
      name: "add_to_cart",
      description: "Add one or more product IDs to the active user's mock cart.",
      parameters: {
        type: "object",
        properties: {
          userId: { type: "string" },
          productIds: { type: "array", items: { type: "string" } }
        },
        required: ["productIds"]
      }
    }
  ];
}

export function runTool(name, args = {}) {
  switch (name) {
    case "classify_need":
      return classifyNeed({
        message: args.message,
        imageDescription: args.imageDescription,
      });
    case "search_catalog":
      return searchCatalog({
        query: args.query,
        category: args.category,
        visualClues: args.visualClues || [],
        budgetMax: args.budgetMax,
        minRating: args.minRating,
        deliveryPreference: args.deliveryPreference || "any",
      });
    case "add_to_cart":
      return addToCart({
        userId: args.userId || "u_001",
        productIds: args.productIds || [],
      });
    default:
      throw new Error(`Unsupported tool: ${name}`);
  }
}

function getSession(userId, cart = []) {
  if (!sessions.has(userId)) {
    sessions.set(userId, { cart: [...cart] });
  }
  return sessions.get(userId);
}

function hydrateCart(cart) {
  return cart
    .map((item) => {
      const product = products.find((entry) => entry.id === item.productId);
      if (!product) {
        return null;
      }
      return {
        ...enrichProduct(product),
        quantity: item.quantity,
      };
    })
    .filter(Boolean);
}

function buildReply({ classification, primary, bundle }) {
  if (!primary) {
    return "I need one short detail before I recommend products. What should I optimize for: fit, compatibility, or delivery speed?";
  }

  let intro = "";
  if (classification.category === "home_repair") {
    intro = "This looks like a small sink repair job.";
  } else if (classification.category === "beauty") {
    intro = "I found a fast skincare restock option.";
  } else if (classification.category === "fashion") {
    intro = "I found a clean match for that outfit.";
  } else {
    intro = "I found a likely match.";
  }

  const bundleText = bundle.length
    ? ` I would also pair it with ${bundle.map((item) => item.title).join(" and ")}.`
    : "";

  return `${intro} Start with ${primary.title} from ${primary.seller} at $${primary.price.toFixed(2)}.${bundleText} Should I add the recommended items to cart?`;
}

function buildReason(product) {
  const parts = [];
  if (product.keywordMatches?.length) {
    parts.push(`Matches ${product.keywordMatches.slice(0, 2).join(" and ")}`);
  }
  if (product.delivery === "same_day") {
    parts.push("same-day delivery");
  } else if (product.delivery === "next_day") {
    parts.push("next-day delivery");
  }
  if (product.rating >= 4.7) {
    parts.push(`rated ${product.rating}`);
  }
  return parts.join(", ");
}

function calculateVoucherDiscount(voucher, subtotal) {
  if (!voucher) {
    return 0;
  }
  if (voucher.discountType === "percent") {
    return roundMoney((subtotal * voucher.value) / 100);
  }
  if (voucher.discountType === "fixed" || voucher.discountType === "free_shipping") {
    return roundMoney(voucher.value);
  }
  return 0;
}

function enrichProduct(product) {
  const seller = sellers.find((entry) => entry.id === product.sellerId);
  return {
    ...product,
    seller: seller?.name || "Unknown seller",
    sellerRating: seller?.rating || 0,
  };
}

function roundMoney(value) {
  return Math.round(value * 100) / 100;
}

function tokenize(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, " ")
    .split(/\s+/)
    .filter(Boolean);
}

async function loadJson(relativePath) {
  const contents = await readFile(join(__dirname, relativePath), "utf8");
  return JSON.parse(contents);
}
