const screen = document.querySelector(".screen");
const stateLabel = document.querySelector("#state-label");
const agentLine = document.querySelector("#agent-line");
const customerLine = document.querySelector("#customer-line");
const assistantMessage = document.querySelector("#assistant-message");
const messageInput = document.querySelector("#message");
const imageInput = document.querySelector("#image-input");
const cameraButton = document.querySelector("#camera-button");
const micButton = document.querySelector("#mic-button");
const sendButton = document.querySelector("#send-button");
const productsPanel = document.querySelector(".products-panel");
const productsGrid = document.querySelector("#products-grid");
const addBundleButton = document.querySelector("#add-bundle-button");
const closeRecommendationsButton = document.querySelector("#close-recommendations-button");
const recommendationsTab = document.querySelector("#recommendations-tab");
const recommendationsTabCount = document.querySelector("#recommendations-tab-count");
const recommendationsCountChip = document.querySelector("#recommendations-count-chip");
const cartItems = document.querySelector("#cart-items");
const cartCount = document.querySelector("#cart-count");
const cartLinkCount = document.querySelector("#cart-link-count");
const checkoutSummary = document.querySelector("#checkout-summary");
const remoteAudio = document.querySelector("#remote-audio");

const userId = "u_001";
let currentState = "idle";
let peerConnection = null;
let dataChannel = null;
let localStream = null;
let latestAgentPayload = null;
let currentImageBase64 = "";
let cartState = [];
let recommendationState = {
  hasProducts: false,
  dismissed: false,
  count: 0,
};

async function requestNativeCameraSnapshot(question = "") {
  if (!window.captureNativeCameraView) {
    throw new Error("Camera capture is unavailable in this view.");
  }

  return window.captureNativeCameraView({ question });
}

function syncRecommendationsDrawer() {
  const isOpen = recommendationState.hasProducts && !recommendationState.dismissed;
  productsPanel.dataset.state = isOpen ? "open" : "closed";
  productsPanel.setAttribute("aria-hidden", String(!isOpen));
  recommendationsCountChip.textContent = `${recommendationState.count} item${recommendationState.count === 1 ? "" : "s"}`;
  recommendationsTabCount.textContent = String(recommendationState.count);
  recommendationsTab.hidden = !recommendationState.hasProducts || !recommendationState.dismissed;
}

function resetRecommendationsDrawer() {
  recommendationState = {
    hasProducts: false,
    dismissed: false,
    count: 0,
  };
  productsGrid.innerHTML = "";
  addBundleButton.hidden = true;
  syncRecommendationsDrawer();
}

function showRecommendations(products = [], bundle = [], shouldOpen = false) {
  renderProducts(products, bundle);
  recommendationState = {
    hasProducts: products.length > 0,
    dismissed: products.length > 0 ? !shouldOpen : false,
    count: products.length,
  };
  syncRecommendationsDrawer();
}

function dismissRecommendations() {
  if (!recommendationState.hasProducts) {
    return;
  }

  recommendationState.dismissed = true;
  syncRecommendationsDrawer();
}

function reopenRecommendations() {
  if (!recommendationState.hasProducts) {
    return;
  }

  recommendationState.dismissed = false;
  syncRecommendationsDrawer();
}

function updateCartBadges(cart = []) {
  const count = cart.reduce((total, item) => total + Number(item.quantity || 0), 0);
  const label = `${count} item${count === 1 ? "" : "s"}`;

  if (cartCount) {
    cartCount.textContent = label;
  }
  if (cartLinkCount) {
    cartLinkCount.textContent = String(count);
  }
}

function renderState(name, overrides = {}) {
  const states = {
    idle: {
      label: "Disconnected",
      agentLine: "Tap the mic to start voice, or type a shopping problem below.",
      customerLine: "Built for repair, skincare, fashion, and more.",
    },
    connecting: {
      label: "Connecting",
      agentLine: "Opening microphone access and setting up the live session.",
      customerLine: "The realtime voice agent is negotiating WebRTC now.",
    },
    listening: {
      label: "Listening",
      agentLine: "Voice session is live. Ask what to buy and I'll use the shopping tools.",
      customerLine: "Mic is open only while this session is active.",
    },
    thinking: {
      label: "Thinking",
      agentLine: "Working through classification, search, and cart logic.",
      customerLine: "The agent is deciding which commerce tools to call.",
    },
    speaking: {
      label: "Speaking",
      agentLine: "The agent is speaking back through the realtime session.",
      customerLine: "You can interrupt by speaking again or stop with the mic button.",
    },
    error: {
      label: "Error",
      agentLine: "The voice session failed to initialize.",
      customerLine: "Use text mode or retry the mic once the backend is ready.",
    },
  };

  const next = { ...states[name], ...overrides };
  screen.dataset.state = name;
  stateLabel.textContent = next.label;
  agentLine.textContent = next.agentLine;
  customerLine.textContent = next.customerLine;
  currentState = name;
}

function renderProducts(products = [], bundle = []) {
  if (!products.length) {
    productsGrid.innerHTML = '<div class="empty-state">No relevant recommendations available yet.</div>';
    addBundleButton.hidden = true;
    return;
  }

  const bundleIds = new Set(bundle.map((item) => item.id));
  productsGrid.innerHTML = products
    .map(
      (product) => `
        <article class="product-card">
          <div class="product-card-head">
            <div>
              <div class="product-badge">${bundleIds.has(product.id) ? "Bundle item" : "Best match"}</div>
              <h3>${escapeHtml(product.title)}</h3>
            </div>
            <button class="mini-icon-button" type="button" data-add-product="${product.id}" aria-label="Add ${escapeHtml(product.title)} to cart">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path
                  d="M7 5h-2.2a.8.8 0 0 0 0 1.6h1.6l1.5 7.1a2.2 2.2 0 0 0 2.2 1.8h6.8a2.2 2.2 0 0 0 2.1-1.6l1.3-4.6a.8.8 0 0 0-.8-1H9.3l-.5-2.4A1.8 1.8 0 0 0 7 5Zm4.9 4.2a.8.8 0 0 0-1.6 0v1.4H8.9a.8.8 0 0 0 0 1.6h1.4v1.4a.8.8 0 1 0 1.6 0v-1.4h1.4a.8.8 0 1 0 0-1.6h-1.4V9.2Zm-1.5 9.1a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4Zm7 0a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4Z"
                />
              </svg>
            </button>
          </div>
          <p>${escapeHtml(product.description || "")}</p>
          <div class="product-tags">
            <span class="product-tag">$${Number(product.price).toFixed(2)}</span>
            <span class="product-tag">${product.rating}★ rating</span>
            <span class="product-tag">${escapeHtml(product.delivery)}</span>
          </div>
          <div class="product-footer">
            <strong>${escapeHtml(product.seller)}</strong>
            <span class="product-meta">${escapeHtml(product.reason || "")}</span>
          </div>
        </article>
      `
    )
    .join("");

  addBundleButton.hidden = false;
}

function renderCart(cart = [], summary = null, voucher = null) {
  cartState = cart;
  updateCartBadges(cart);

  if (!cartItems || !checkoutSummary) {
    return;
  }

  if (!cart.length) {
    cartItems.innerHTML = '<div class="empty-state">Your cart is empty. Use the basket icons on matching products.</div>';
    checkoutSummary.innerHTML = "";
    return;
  }

  const previewItems = cart.slice(0, 2);
  cartItems.innerHTML = previewItems
    .map(
      (item) => `
        <div class="cart-row">
          <div>
            <div class="cart-name">${escapeHtml(item.title || item.productId)}</div>
            <div class="product-meta">${item.quantity} × $${Number(item.price || 0).toFixed(2)}</div>
          </div>
          <strong>$${(Number(item.price || 0) * Number(item.quantity || 0)).toFixed(2)}</strong>
        </div>
      `
    )
    .join("");

  if (cart.length > previewItems.length) {
    cartItems.insertAdjacentHTML(
      "beforeend",
      `<div class="compact-note">Plus ${cart.length - previewItems.length} more item${cart.length - previewItems.length === 1 ? "" : "s"} in cart.</div>`
    );
  }

  if (!summary) {
    checkoutSummary.innerHTML = "";
    return;
  }

  checkoutSummary.innerHTML = `
    <div class="summary-row"><span>Subtotal</span><strong>$${summary.subtotal.toFixed(2)}</strong></div>
    <div class="summary-row"><span>Discount${voucher ? ` (${escapeHtml(voucher.code)})` : ""}</span><strong>-$${summary.discount.toFixed(2)}</strong></div>
    <div class="summary-row"><span>Shipping</span><strong>$${summary.shipping.toFixed(2)}</strong></div>
    <div class="summary-row"><span>Total</span><strong>$${summary.total.toFixed(2)}</strong></div>
  `;
}

function openCameraExperience() {
  if (window.webkit?.messageHandlers?.cameraTapped) {
    return;
  }

  renderState("idle", {
    agentLine: "Open this demo in the iOS app to use the AR camera.",
    customerLine: "The camera button is wired to the native AR screen.",
  });
}

async function bootstrap() {
  const response = await fetch(`/api/bootstrap?userId=${encodeURIComponent(userId)}`);
  const data = await response.json();
  resetRecommendationsDrawer();
  renderCart(data.cartSnapshot?.cart || [], data.cartSnapshot?.checkoutPreview || null, data.cartSnapshot?.appliedVoucher || null);
  assistantMessage.textContent = "Try the repair, skincare, or fashion demo prompts.";
}

async function sendAgentRequest() {
  const message = messageInput.value.trim();
  if (!message) {
    return;
  }

  resetRecommendationsDrawer();
  renderState("thinking");
  assistantMessage.textContent = "Working on it...";

  const response = await fetch("/api/agent", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      userId,
      message,
      imageBase64: currentImageBase64,
      cart: cartState.map((item) => ({ productId: item.productId || item.id, quantity: item.quantity })),
    }),
  });
  const data = await response.json();
  latestAgentPayload = data;
  assistantMessage.textContent = data.reply;
  showRecommendations(data.products, data.suggestedBundle || [], data.uiAction === "SHOW_PRODUCTS");
  renderState(
    "idle",
    data.uiAction === "SHOW_PRODUCTS"
      ? {
          agentLine: "Product recommendations are ready.",
          customerLine: `${data.category} playbook selected.`,
        }
      : {
          agentLine: "I need one more detail before recommending products.",
          customerLine: `${data.category} playbook selected.`,
        }
  );
}

function redirectToCart() {
  window.location.href = `/cart.html?userId=${encodeURIComponent(userId)}`;
}

async function addRecommendedItems() {
  if (!latestAgentPayload?.products?.length) {
    return;
  }

  const productIds = [
    latestAgentPayload.products[0]?.id,
    ...(latestAgentPayload.suggestedBundle || []).map((item) => item.id),
  ].filter(Boolean);

  const response = await fetch("/api/tools/add-to-cart", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      userId,
      category: latestAgentPayload.category,
      productIds,
    }),
  });
  const data = await response.json();
  const enrichedCart = attachProductDataToCart(data.cart, latestAgentPayload.products, latestAgentPayload.suggestedBundle);
  renderCart(enrichedCart, data.checkoutPreview, data.appliedVoucher);
  assistantMessage.textContent = "Added the recommended items and opened your cart.";
  redirectToCart();
}

function attachProductDataToCart(cart, primaryProducts = [], bundle = []) {
  const catalog = [...primaryProducts, ...(bundle || [])];
  return cart.map((item) => {
    const product = catalog.find((entry) => entry.id === item.productId) || {};
    return {
      ...item,
      ...product,
    };
  });
}

async function encodeSelectedImage() {
  const file = imageInput?.files?.[0];
  if (!file) {
    currentImageBase64 = "";
    return;
  }

  currentImageBase64 = await new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result || "");
      resolve(result.split(",")[1] || "");
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

async function toggleVoiceSession() {
  if (currentState === "idle" || currentState === "error") {
    await startSession();
    return;
  }

  stopSession();
}

async function startSession() {
  resetRecommendationsDrawer();
  renderState("connecting");

  try {
    localStream = await navigator.mediaDevices.getUserMedia({ audio: true });

    peerConnection = new RTCPeerConnection();
    peerConnection.ontrack = (event) => {
      remoteAudio.srcObject = event.streams[0];
    };

    peerConnection.onconnectionstatechange = () => {
      if (!peerConnection) {
        return;
      }
      if (peerConnection.connectionState === "connected") {
        renderState("listening");
      }
      if (["failed", "disconnected", "closed"].includes(peerConnection.connectionState)) {
        stopSession();
      }
    };

    for (const track of localStream.getTracks()) {
      peerConnection.addTrack(track, localStream);
    }

    dataChannel = peerConnection.createDataChannel("oai-events");
    dataChannel.addEventListener("open", () => {
      renderState("listening");
      sendRealtimeEvent({
        type: "session.update",
        session: {
          instructions:
            "You are Shopee's universal shopping agent. Use classify_need, search_catalog, add_to_cart, and analyze_surroundings when relevant. If the user asks about what they are currently seeing, visible objects, room context, style matching, or compatibility with the live camera scene, call analyze_surroundings before answering.",
        },
      });
    });
    dataChannel.addEventListener("message", async (event) => {
      const payload = JSON.parse(event.data);
      await handleRealtimeEvent(payload);
    });

    const offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);

    const response = await fetch("/session", {
      method: "POST",
      headers: { "Content-Type": "application/sdp" },
      body: offer.sdp,
    });

    if (!response.ok) {
      throw new Error(await response.text());
    }

    await peerConnection.setRemoteDescription({
      type: "answer",
      sdp: await response.text(),
    });
  } catch (error) {
    console.error(error);
    stopSession();
    renderState("error", {
      customerLine: error.message || "Voice setup failed",
    });
  }
}

async function handleRealtimeEvent(event) {
  if (event.type === "input_audio_buffer.speech_started") {
    renderState("listening", {
      customerLine: "Speech detected. The live agent is listening now.",
    });
    return;
  }

  if (event.type === "response.created") {
    renderState("thinking");
    return;
  }

  if (event.type === "response.output_audio.delta" || event.type === "response.audio_transcript.delta") {
    renderState("speaking");
    return;
  }

  if (event.type === "response.done") {
    renderState("listening");
    return;
  }

  const item = event.item;
  if (
    (event.type === "conversation.item.created" || event.type === "response.output_item.done") &&
    item?.type === "function_call"
  ) {
    await runRealtimeTool(item);
  }
}

async function runRealtimeTool(item) {
  const parsedArgs = safeJsonParse(item.arguments || "{}");
  let endpoint = "";
  if (item.name === "classify_need") {
    endpoint = "/api/tools/classify-need";
  } else if (item.name === "search_catalog") {
    endpoint = "/api/tools/search-catalog";
    resetRecommendationsDrawer();
  } else if (item.name === "add_to_cart") {
    endpoint = "/api/tools/add-to-cart";
    parsedArgs.userId = parsedArgs.userId || userId;
  } else if (item.name === "analyze_surroundings") {
    renderState("thinking", {
      agentLine: "Inspecting the live camera view.",
      customerLine: "Capturing a snapshot for visual analysis.",
    });

    const snapshot = await requestNativeCameraSnapshot(parsedArgs.question || "");
    endpoint = "/api/tools/analyze-surroundings";
    parsedArgs.imageBase64 = snapshot.imageBase64;
    parsedArgs.mimeType = snapshot.mimeType || "image/jpeg";
  } else {
    return;
  }

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(parsedArgs),
  });
  const result = await response.json();

  if (item.name === "search_catalog") {
    latestAgentPayload = {
      ...(latestAgentPayload || {}),
      category: parsedArgs.category || latestAgentPayload?.category,
      products: result.products || [],
      suggestedBundle: latestAgentPayload?.suggestedBundle || [],
      uiAction: result.uiAction,
    };
    showRecommendations(result.products || [], [], result.uiAction === "SHOW_PRODUCTS");
  }

  if (item.name === "analyze_surroundings" && result.summary) {
    assistantMessage.textContent = result.summary;
  }

  if (item.name === "add_to_cart" && result.cart) {
    const combinedProducts = latestAgentPayload
      ? [...(latestAgentPayload.products || []), ...(latestAgentPayload.suggestedBundle || [])]
      : [];
    renderCart(attachProductDataToCart(result.cart, combinedProducts, []), result.checkoutPreview, result.appliedVoucher);
  }

  sendRealtimeEvent({
    type: "conversation.item.create",
    item: {
      type: "function_call_output",
      call_id: item.call_id,
      output: JSON.stringify(result),
    },
  });
  sendRealtimeEvent({ type: "response.create" });
}

function sendRealtimeEvent(payload) {
  if (dataChannel?.readyState === "open") {
    dataChannel.send(JSON.stringify(payload));
  }
}

function stopSession() {
  if (dataChannel) {
    dataChannel.close();
    dataChannel = null;
  }
  if (peerConnection) {
    peerConnection.close();
    peerConnection = null;
  }
  if (localStream) {
    for (const track of localStream.getTracks()) {
      track.stop();
    }
    localStream = null;
  }
  remoteAudio.srcObject = null;
  renderState("idle");
}

function safeJsonParse(value) {
  try {
    return JSON.parse(value);
  } catch {
    return {};
  }
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

if (imageInput) {
  imageInput.addEventListener("change", encodeSelectedImage);
}
if (cameraButton) {
  cameraButton.addEventListener("click", openCameraExperience);
}
sendButton.addEventListener("click", sendAgentRequest);
messageInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    sendAgentRequest();
  }
});
addBundleButton.addEventListener("click", addRecommendedItems);
closeRecommendationsButton.addEventListener("click", dismissRecommendations);
recommendationsTab.addEventListener("click", reopenRecommendations);
productsGrid.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-add-product]");
  if (!button) {
    return;
  }

  const productId = button.getAttribute("data-add-product");
  const response = await fetch("/api/tools/add-to-cart", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      userId,
      category: latestAgentPayload?.category,
      productIds: [productId],
    }),
  });
  const data = await response.json();
  const combinedProducts = latestAgentPayload
    ? [...(latestAgentPayload.products || []), ...(latestAgentPayload.suggestedBundle || [])]
    : [];
  renderCart(attachProductDataToCart(data.cart, combinedProducts, []), data.checkoutPreview, data.appliedVoucher);
  redirectToCart();
});
micButton.addEventListener("click", toggleVoiceSession);

renderState("idle");
resetRecommendationsDrawer();
bootstrap().catch((error) => {
  console.error(error);
  assistantMessage.textContent = "Failed to load the storefront bootstrap data.";
});
