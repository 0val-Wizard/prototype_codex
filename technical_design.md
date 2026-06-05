# Shopee Voice Agent — Technical Design Document

> **Purpose**: This document specifies every component of the Shopee Voice Agent prototype in enough detail for a developer or coding agent to replicate the system from scratch. It covers the backend, web frontend, iOS AR app, data schemas, API contracts, protocols, and setup instructions.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [Environment & Configuration](#3-environment--configuration)
4. [Backend Server (`server.mjs`)](#4-backend-server-servermjs)
5. [Commerce Logic Engine (`commerce.mjs`)](#5-commerce-logic-engine-commercemjs)
6. [Mock Data Schemas](#6-mock-data-schemas)
7. [Web Frontend](#7-web-frontend)
8. [iOS AR App (`ShopeeARDemo`)](#8-ios-ar-app-shoppeeardemo)
9. [WebRTC Voice Session Protocol](#9-webrtc-voice-session-protocol)
10. [Native ↔ Web Camera Bridge](#10-native--web-camera-bridge)
11. [Setup & Running Instructions](#11-setup--running-instructions)

---

## 1. Project Overview

**Product**: A voice-first, camera-aware shopping agent for Shopee.  
**Stack**: Node.js backend (no framework, raw `http`/`https`), vanilla HTML/CSS/JS web client, native iOS app in SwiftUI + RealityKit + ARKit.  
**AI**: OpenAI Realtime API (`gpt-realtime-2`) for voice, OpenAI Vision API (`gpt-4.1-mini`) for camera scene analysis.  
**Protocol**: WebRTC (voice + data channel between client and OpenAI), REST (tool execution between client and our server).

The core loop:
1. User speaks a shopping problem (or types it).
2. OpenAI Realtime API processes speech, decides which tools to call.
3. Client receives tool call events over WebRTC data channel.
4. Client calls our backend HTTP tool endpoints.
5. Backend runs commerce logic (classify → search → rank → bundle → cart → voucher).
6. Results go back to client, then to OpenAI as `function_call_output`.
7. OpenAI speaks a response with product recommendations.

---

## 2. Repository Structure

```
Codex_Proto/
├── .env                              # API keys and runtime config (gitignored)
├── .gitignore
├── server.mjs                        # Node.js HTTP/HTTPS server (390 lines)
├── commerce.mjs                      # Shopping logic engine (521 lines)
├── index.html                        # Main web UI (134 lines)
├── ui.js                             # Web client JS: WebRTC, DOM, tool execution (621 lines)
├── styles.css                        # Design system and responsive layout (686 lines)
├── cart.html                         # Dedicated cart page (46 lines)
├── cart.js                           # Cart page JS (84 lines)
├── certs/                            # TLS certificates for local HTTPS (gitignored)
├── data/
│   ├── products.json                 # 9 products across 6 categories
│   ├── sellers.json                  # 6 sellers
│   ├── vouchers.json                 # 3 voucher rules
│   └── users.json                    # 1 demo user with preferences
└── ios/
    ├── project.yml                   # XcodeGen project spec
    ├── README.md
    └── ShopeeARDemo/
        ├── ARShoppingApp.swift       # @main App entry point
        ├── RootView.swift            # Root SwiftUI view (alternative entry)
        ├── ContentView.swift         # Main view: web agent + camera agent mode (504 lines)
        ├── DesignSystem.swift        # Color palette, typography, modifiers (213 lines)
        ├── ShopeeARDemoApp.swift     # Stub app entry (unused, ARShoppingApp.swift is @main)
        ├── Info.plist                # Permissions + AgentBaseURL config
        ├── Models/
        │   ├── Product.swift         # Product data model (iOS-specific schema)
        │   └── CartItem.swift        # Cart item model
        ├── Services/
        │   ├── CartService.swift     # ObservableObject cart state manager
        │   ├── CatalogService.swift  # Loads products + sellers from bundle JSON
        │   ├── ProductCatalogService.swift  # Keyword-based local product search
        │   ├── OpenAIService.swift   # Placeholder for server-side AI ranking
        │   └── VoiceSearchService.swift    # On-device SFSpeechRecognizer integration
        ├── ViewModels/
        │   ├── AgentViewModel.swift  # Drives the camera-agent experience
        │   └── ShoppingViewModel.swift     # Full shopping flow state management (257 lines)
        ├── Features/
        │   ├── AR/
        │   │   ├── ARViewContainer.swift   # RealityKit AR view with plane detection + model placement (267 lines)
        │   │   ├── ARPreviewContainer.swift
        │   │   ├── ARShoppingView.swift
        │   │   └── ProductCarousel.swift
        │   ├── Cart/
        │   │   └── CartSheet.swift         # Native cart overlay sheet (185 lines)
        │   ├── Discovery/
        │   │   ├── DiscoveryView.swift
        │   │   └── ProductCard.swift
        │   └── Recommendations/
        │       └── AgentOrb.swift          # Animated voice indicator orb (99 lines)
        └── Resources/
            ├── Products.json               # iOS-specific product catalog (4 items with 3D model refs)
            ├── sellers.json                # iOS-specific seller data
            ├── DslrCamera.usdz            # 3D model (~35MB)
            ├── VintageMovieCamera.usdz    # 3D model (~31MB)
            ├── MovieBoomMicrophone.usdz   # 3D model (~32MB)
            └── MovieStudioSpotlight.usdz  # 3D model (~30MB)
```

---

## 3. Environment & Configuration

### `.env` file (root of project)

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENAI_API_KEY` | **Yes** | — | OpenAI API key with Realtime API access |
| `OPENAI_REALTIME_MODEL` | No | `gpt-realtime-2` | Model for voice sessions |
| `OPENAI_REALTIME_VOICE` | No | `marin` | Voice persona for the agent |
| `OPENAI_VISION_MODEL` | No | `gpt-4.1-mini` | Model for camera scene analysis |
| `OPENAI_SAFETY_IDENTIFIER` | No | `demo-user` | Safety identifier sent to OpenAI |
| `PORT` | No | `3000` | HTTP server port |
| `HOST` | No | `0.0.0.0` | Server bind address |
| `HTTPS_PORT` | No | same as `PORT` | HTTPS server port (when TLS is enabled) |
| `SSL_KEY_FILE` | No | — | Path to TLS private key (e.g. `certs/dev-key.pem`) |
| `SSL_CERT_FILE` | No | — | Path to TLS certificate (e.g. `certs/dev-cert.pem`) |

The `.env` file is loaded manually by a `loadEnv()` function (not via `dotenv`). Format: one `KEY=VALUE` per line, `#` for comments.

### iOS Configuration

- `Info.plist` → `AgentBaseURL`: The HTTPS URL of the Node.js server reachable from the iOS device (e.g. `https://192.168.1.73:3000`). This is read at app launch by `AppConfiguration`.
- Required permissions declared in `Info.plist`:
  - `NSCameraUsageDescription` — AR and camera snapshots
  - `NSMicrophoneUsageDescription` — Voice agent via WebRTC
  - `NSMotionUsageDescription` — AR world tracking

---

## 4. Backend Server (`server.mjs`)

A single-file Node.js server (no npm dependencies, pure ESM). Provides:

### 4.1 Server Startup

- Reads `.env` for config.
- If `SSL_KEY_FILE` and `SSL_CERT_FILE` are set, creates an HTTPS server. Otherwise, plain HTTP.
- Listens on configured `HOST:PORT`.

### 4.2 API Endpoints

| Method | Path | Handler | Description |
|---|---|---|---|
| `POST` | `/session` | `handleSession()` | WebRTC SDP relay to OpenAI Realtime API |
| `GET` | `/api/bootstrap` | `getBootstrap()` | Initial cart state + demo scenarios |
| `GET` | `/api/cart` | `getCartSnapshot()` | Current cart with voucher + checkout preview |
| `POST` | `/api/agent` | `runAgent()` | Text-mode full pipeline (classify → search → rank → bundle → reply) |
| `POST` | `/api/tools/classify-need` | `classifyNeed()` | Intent classification tool |
| `POST` | `/api/tools/search-catalog` | `searchCatalog()` | Product search + ranking tool |
| `POST` | `/api/tools/add-to-cart` | `addToCart()` + `applyBestVoucher()` + `checkoutPreview()` | Cart mutation with auto-voucher |
| `POST` | `/api/tools/analyze-surroundings` | `analyzeSurroundings()` | Camera vision analysis via OpenAI Vision API |
| `POST` | `/api/tools/apply-voucher` | `applyBestVoucher()` | Standalone voucher application |
| `POST` | `/api/tools/checkout-preview` | `checkoutPreview()` | Price calculation |
| `GET` | `/*` | `handleStatic()` | Static file server (HTML, CSS, JS, JSON, SVG) |

### 4.3 `/session` Endpoint — SDP Relay

This is the critical WebRTC handshake endpoint:

1. Receives raw SDP offer text as the POST body (content-type `application/sdp`).
2. Constructs a `FormData` with:
   - `sdp`: the client's SDP offer
   - `session`: a JSON string containing:
     - `type: "realtime"`
     - `model`: the configured model
     - `audio.output.voice`: the configured voice
     - `instructions`: system prompt for the shopping agent
     - `tool_choice: "auto"`
     - `tools`: array of tool definitions from `getToolDefinitions()`
3. POSTs to `https://api.openai.com/v1/realtime/calls` with `Authorization: Bearer <apiKey>`.
4. Returns the SDP answer to the client (content-type `application/sdp`).

### 4.4 `/api/tools/analyze-surroundings` — Vision Proxy

1. Receives `{ question, imageBase64, mimeType }`.
2. If any required data is missing, returns a graceful fallback message.
3. Calls `POST https://api.openai.com/v1/responses` with model `gpt-4.1-mini`:
   - System message instructs the model to return JSON with keys: `summary`, `visualClues[]`, `suggestedSearchTerms[]`, `confidence`.
   - User message contains the question text + the base64 image.
4. Parses the response and returns structured JSON.

### 4.5 Static File Server

Maps file extensions to MIME types: `.html`, `.css`, `.js`, `.json`, `.svg`. Serves from the project root directory. `GET /` maps to `/index.html`.

### 4.6 Utility Functions

- `loadEnv(filePath)` — Parses `.env` files without dependencies.
- `parseJsonBody(req)` — Reads request body and parses as JSON.
- `respondJson(res, statusCode, body)` / `respondText(res, statusCode, body)` — Response helpers.
- `extractResponseText(payload)` — Extracts text from OpenAI's nested response format.

---

## 5. Commerce Logic Engine (`commerce.mjs`)

Pure JavaScript module with no external dependencies. All data is loaded from JSON files at startup and held in memory.

### 5.1 Data Loading

At module load time, reads all four JSON files (`products.json`, `sellers.json`, `vouchers.json`, `users.json`) using `readFile` and `JSON.parse`. These become module-level constants.

### 5.2 Session Management

- `sessions`: an in-memory `Map<userId, { cart: CartItem[] }>`.
- `getSession(userId, cart?)`: returns or creates a session. `CartItem` shape: `{ productId: string, quantity: number }`.

### 5.3 Domain Playbooks

A `playbooks` object mapping category strings to instruction text:

| Category | Playbook Focus |
|---|---|
| `home_repair` | Compatibility, size, material, safety, repair bundles |
| `beauty` | Skin type, routine fit, delivery speed, non-medical language |
| `fashion` | Color matching, style coherence, fit, outfit compatibility |
| `electronics` | Device compatibility, ports, seller reliability, delivery speed |
| `grocery` | Replenishment, price per unit, stock, fast delivery |
| `home_decor` | Color palette, dimensions, bundle potential |
| `general` | Quick discovery, ask one clarifying question if low confidence |

### 5.4 Core Functions

#### `classifyNeed({ message, imageDescription }) → { category, confidence, reasoning }`

- Concatenates `message` and `imageDescription`, lowercases.
- Matches against keyword lists for 6 categories.
- Confidence = `min(0.55 + matchCount * 0.1, 0.95)`.
- Falls back to `{ category: "general", confidence: 0.35 }`.

#### `extractVisualClues({ message, imageBase64 }) → { visualClues[], possibleProducts[], uncertainty }`

- Keyword-based clue extraction from message text.
- Returns arrays of short string clues and possible product names.

#### `searchCatalog({ query, category, visualClues, budgetMax, minRating, deliveryPreference }) → { products[], uiAction }`

Scoring algorithm per product:
- `+5` if `product.category === category`
- `+2` per keyword match (product keywords vs. tokenized query + visualClues)
- `+1` if rating ≥ 4.7
- `+1` if delivery is `same_day` or `next_day`
- `+1` if stock > 0, `-10` if stock = 0
- `+2` if delivery matches preference
- `-4` if price > budgetMax
- `-5` if rating < minRating

Filters: `score > 0` AND (`keywordMatches > 0` OR (`categoryMatch` AND `score >= 7`)).  
Returns top 5 sorted by score descending.  
Each product is enriched with seller name/rating via `enrichProduct()`.  
`uiAction` is `"SHOW_PRODUCTS"` if results exist, else `"ASK_CLARIFYING_QUESTION"`.

#### `rankProducts({ products, userPreference }) → { rankedProducts[] }`

Re-ranks search results by user preferences:
- `+2` if user wants fast delivery and product is `same_day`
- `+1` if high budget sensitivity and price < $15
- `+1` if low budget sensitivity and rating ≥ 4.7

#### `recommendBundle({ primaryProductId }) → { bundle[] }`

Looks up `bundleItems` array on the primary product, resolves each to a full product.

#### `addToCart({ userId, cart, productIds }) → { cart[] }`

Adds product IDs to the user's session cart. Increments quantity if already present.

#### `getCartSnapshot({ userId, category }) → { cart[], appliedVoucher, discount, checkoutPreview }`

Hydrates the cart (replaces productIds with full product objects), applies the best voucher, and calculates checkout totals.

#### `applyBestVoucher({ cart, category }) → { voucher, discount }`

Filters eligible vouchers by:
- Category match (or no category restriction)
- Minimum spend threshold

Calculates discount per voucher type (`percent`, `fixed`, `free_shipping`), picks the highest.

#### `checkoutPreview({ cart, voucher }) → { subtotal, discount, shipping, total, estimatedDelivery }`

- Base shipping: `$2.99` if cart non-empty, `$0` for free_shipping vouchers.
- `total = max(0, subtotal - discount + shipping)`.
- `estimatedDelivery`: "Same day for eligible items" if any item has `same_day` delivery, else "Next day delivery".

#### `runAgent({ message, imageBase64, cart, userId }) → { reply, category, confidence, reasoning, playbook, products[], suggestedBundle[], cart, uiAction }`

The full text-mode pipeline:
1. `extractVisualClues()` from message
2. `classifyNeed()` using message + visual clues
3. Look up user preferences from `users.json`
4. `searchCatalog()` with category, visual clues, and user delivery preference
5. `rankProducts()` by user preferences
6. `recommendBundle()` for the top product
7. `buildReply()` to generate a natural language response
8. Returns the full payload including the playbook text.

#### `getToolDefinitions() → Tool[]`

Returns the 4 tool schemas for OpenAI Realtime API registration:

```json
[
  {
    "type": "function",
    "name": "classify_need",
    "parameters": { "message": "string", "imageDescription?": "string" }
  },
  {
    "type": "function",
    "name": "search_catalog",
    "parameters": {
      "query": "string",
      "category?": "string",
      "visualClues?": "string[]",
      "budgetMax?": "number",
      "minRating?": "number",
      "deliveryPreference?": "same_day|next_day|any"
    }
  },
  {
    "type": "function",
    "name": "add_to_cart",
    "parameters": { "userId?": "string", "productIds": "string[]" }
  },
  {
    "type": "function",
    "name": "analyze_surroundings",
    "parameters": { "question": "string" }
  }
]
```

#### `runTool(name, args) → result`

Dispatcher that routes tool name to the corresponding function. `analyze_surroundings` returns a message saying it must be handled by the server (because it needs the Vision API call).

---

## 6. Mock Data Schemas

### 6.1 `data/products.json` — Web/Backend Catalog

```typescript
interface Product {
  id: string;              // e.g. "HW001", "SK001", "FA001", "EL001", "GR001"
  title: string;
  category: "home_repair" | "beauty" | "fashion" | "electronics" | "grocery" | "home_decor";
  description: string;
  keywords: string[];      // Used for search matching
  price: number;           // USD
  rating: number;          // 0-5
  sellerId: string;        // FK to sellers.json
  delivery: "same_day" | "next_day" | "standard";
  stock: number;
  imageUrl: string;        // Unused in current UI (placeholder paths)
  attributes?: Record<string, string | string[]>;  // e.g. { size: "15mm", material: "PVC" }
  bundleItems?: string[];  // Array of product IDs for bundle recommendations
}
```

Current catalog: 9 products across home_repair (3), beauty (2), fashion (2), electronics (1), grocery (1).

### 6.2 `data/sellers.json`

```typescript
interface Seller {
  id: string;        // e.g. "S001"
  name: string;      // e.g. "SG Hardware Pro"
  rating: number;    // 0-5
  isPreferred: boolean;
  location: string;  // e.g. "Singapore"
}
```

### 6.3 `data/vouchers.json`

```typescript
interface Voucher {
  id: string;           // e.g. "V001"
  code: string;         // e.g. "FREESHIP", "REPAIR10", "BEAUTY5"
  description: string;
  discountType: "free_shipping" | "percent" | "fixed";
  value: number;        // Percentage (for percent) or dollar amount (for fixed/free_shipping)
  minSpend: number;     // Minimum cart subtotal to qualify
  category?: string;    // Optional: restrict to a specific category
}
```

### 6.4 `data/users.json`

```typescript
interface User {
  user_id: string;     // e.g. "u_001"
  location: string;
  preferences: {
    delivery_priority: "fast" | "standard";
    budget_sensitivity: "low" | "medium" | "high";
    preferred_sellers: string[];
  };
  order_history: Array<{
    product_id: string;
    category: string;
    purchased_at: string;  // ISO date
  }>;
}
```

### 6.5 `ios/ShopeeARDemo/Resources/Products.json` — iOS-Specific Catalog

The iOS app uses a **different product schema** with 3D model references:

```typescript
interface IOSProduct {
  id: string;            // e.g. "MON001"
  title: string;
  subtitle: string;
  price: number;
  keywords: string[];
  modelName: string;     // Name of bundled .usdz file (without extension)
  accentHex: string;     // Hex color for UI accents (e.g. "#3FD1FF")
}
```

4 products, each mapped to a bundled USDZ 3D model for AR placement.

---

## 7. Web Frontend

### 7.1 `index.html` — Main Page

The page is a single-screen mobile-first layout with 4 sections:

1. **Topbar**: Brand name ("Shop from uncertainty" in Shopee orange `#ee4d2d`), cart link with badge counter, connection status pill (dot + label like "Disconnected", "Listening", etc.).

2. **Hero / Voice Section**: Contains the animated voice orb (3 `<span>` elements inside nested `.orb-shell > .orb` divs with orbit rings), a waveform visualizer (8 `<i>` bars), and two text lines (`agent-line` and `customer-line`) that update based on state.

3. **Assistant Panel**: Shows the assistant's text message, a text input composer with camera button, mic button, and "Ask" submit button.

4. **Products Panel (Drawer)**: A bottom sheet with `data-state="open|closed"`. Contains a header ("Smart picks / Recommendations"), close button, item count chip, "Add all to cart" button, and a `products-grid` div populated dynamically with product cards.

5. **Recommendations Tab**: A floating button that appears when the drawer is dismissed but products exist, showing the count.

6. **Cart Panel**: Inline preview showing first 2 cart items, checkout summary (subtotal/discount/shipping/total).

7. **Audio element**: `<audio id="remote-audio" autoplay>` for WebRTC remote audio playback.

### 7.2 `ui.js` — Web Client Logic

#### State Machine

The UI tracks `currentState` with these values:

| State | Label | When |
|---|---|---|
| `idle` | Disconnected | No active voice session |
| `connecting` | Connecting | WebRTC negotiation in progress |
| `listening` | Listening | Voice session active, waiting for speech |
| `thinking` | Thinking | Agent is processing / tools are running |
| `speaking` | Speaking | Agent is streaming audio response |
| `error` | Error | Voice session failed |

State transitions update the `data-state` attribute on `.screen`, `stateLabel`, `agentLine`, and `customerLine`.

#### WebRTC Session Flow (`startSession()`)

1. `navigator.mediaDevices.getUserMedia({ audio: true })` to get mic stream.
2. Create `RTCPeerConnection`.
3. Set `ontrack` to pipe remote audio to `<audio id="remote-audio">`.
4. Set `onconnectionstatechange` to track connection lifecycle.
5. Add all local audio tracks to the peer connection.
6. Create a data channel named `"oai-events"`.
7. On data channel open: send a `session.update` event with updated instructions.
8. On data channel message: parse JSON and route to `handleRealtimeEvent()`.
9. Create SDP offer, set as local description.
10. `POST /session` with the SDP offer text.
11. Set the returned SDP answer as remote description.

#### Realtime Event Handling (`handleRealtimeEvent()`)

| Event Type | Action |
|---|---|
| `input_audio_buffer.speech_started` | Set state to `listening` |
| `response.created` | Set state to `thinking` |
| `response.output_audio.delta` or `response.audio_transcript.delta` | Set state to `speaking` |
| `response.done` | Set state to `listening` |
| `conversation.item.created` or `response.output_item.done` with `item.type === "function_call"` | Call `runRealtimeTool(item)` |

#### Tool Execution (`runRealtimeTool()`)

Routes tool calls to the correct backend endpoint:

| Tool Name | Endpoint | Special Handling |
|---|---|---|
| `classify_need` | `/api/tools/classify-need` | — |
| `search_catalog` | `/api/tools/search-catalog` | Resets recommendation drawer before calling |
| `add_to_cart` | `/api/tools/add-to-cart` | Defaults `userId` to `"u_001"` |
| `analyze_surroundings` | `/api/tools/analyze-surroundings` | Calls `requestNativeCameraSnapshot()` first to get base64 image from native iOS, then sends to server |

After receiving the result:
1. Updates UI (products grid, cart, assistant message) based on tool name.
2. Sends `conversation.item.create` with `type: "function_call_output"` and the JSON result.
3. Sends `response.create` to prompt the agent to speak the next response.

#### Text Mode (`sendAgentRequest()`)

Fallback for when voice is not available:
1. Takes text from the `#message` input.
2. `POST /api/agent` with `{ userId, message, imageBase64, cart }`.
3. Renders the full response (reply text, products, bundle).

#### Recommendation Drawer State

Managed by `recommendationState` object:
- `hasProducts`: whether products exist.
- `dismissed`: whether the user closed the drawer.
- `count`: number of items.

Three operations: `showRecommendations()`, `dismissRecommendations()`, `reopenRecommendations()`. The drawer visibility is controlled by `data-state="open|closed"` on `.products-panel`.

#### Product Card Rendering

Each product card contains:
- Badge ("Best match" or "Bundle item")
- Title
- Description
- Price tag, rating tag, delivery tag
- Seller name and match reasoning
- Add-to-cart icon button with `data-add-product="<productId>"`

Clicking any add-to-cart button: `POST /api/tools/add-to-cart` → update cart UI → redirect to `/cart.html`.

### 7.3 `styles.css` — Design System

CSS custom properties on `:root`:

```css
--bg-1: #ffffff;
--bg-2: #f8f9fa;
--panel: #ffffff;
--panel-border: rgba(0, 0, 0, 0.06);
--text: #111827;
--muted: #6b7280;
--accent: #8c7bff;
--accent-2: #a45cff;
--accent-3: #0fb9ff;
--shadow: 0 8px 30px rgba(0, 0, 0, 0.06);
```

Key design elements:
- **Light theme** with soft grays and purple/blue accents.
- **Brand color**: `#ee4d2d` (Shopee orange) for the H1 title.
- **Orb animation**: CSS `@keyframes orb-spin` (360° rotation over 6s), radial gradient fill using `--accent`, `--accent-2`, `--accent-3`.
- **Waveform**: 8 bars with staggered `animation-delay` (each bar offset by 0.1s), `@keyframes bar-bounce` for height oscillation.
- **State-driven visibility**: `.screen[data-state="listening"] .waveform` becomes visible, `.screen[data-state="thinking"] .orb` triggers pulse.
- **Products panel**: slide-up drawer using `transform: translateY()` with CSS transitions.
- **Responsive**: `@media (max-width: 480px)` placeholder for mobile tweaks.
- **Cart page**: separate `.cart-page` styles with `.cart-screen` max-width 600px centered layout.

### 7.4 `cart.html` + `cart.js` — Cart Page

Standalone page that:
1. Reads `userId` from URL query params (default `u_001`).
2. `GET /api/cart?userId=<userId>`.
3. Renders all cart items with title, description, quantity × price, rating, delivery, seller.
4. Renders checkout summary: subtotal, discount (with voucher code), shipping, total, estimated delivery.
5. "Back to agent" link returns to `/`.

---

## 8. iOS AR App (`ShopeeARDemo`)

### 8.1 Project Configuration

- **XcodeGen**: `project.yml` defines the Xcode project. Run `xcodegen generate` from `ios/` directory.
- **Target**: iOS 17.0+, Swift 5.10.
- **Bundle ID**: `com.prototype.shopee-ar-demo`.
- **Frameworks**: SwiftUI, RealityKit, ARKit, WebKit, Speech, AVFoundation.

### 8.2 App Architecture

```
ARShoppingApp (@main)
  └── ContentView
        ├── SharedAgentWebView (WKWebView showing the web UI from server)
        └── CameraAgentView (shown when camera button tapped)
              ├── ARViewContainer (RealityKit AR view)
              └── Agent Panel (frosted glass bottom sheet with AgentOrb + web view)
```

**Environment objects** injected at app root:
- `CartService` — ObservableObject managing cart items array.
- `AgentViewModel` — ObservableObject managing product recommendations, AR placement state, agent messages.

### 8.3 `ContentView.swift` — Main View (504 lines)

Two modes controlled by `showCameraExperience: Bool`:

**Mode 1 — Web Agent** (default): Full-screen `SharedAgentWebView` displaying the Node.js server's web UI inside a `WKWebView`. The web view handles all voice agent interaction.

**Mode 2 — Camera Agent**: A `ZStack` with:
- **Background**: `ARViewContainer` (full-screen AR camera)
- **Overlay top**: Header bar with back button, "AI Agent + Camera" label, agent message, cart button with badge
- **Overlay bottom**: Frosted glass agent panel with:
  - `AgentOrb` (animated voice indicator)
  - "Realtime Agent" label
  - Expand/collapse toggle
  - When expanded: shows the `SharedAgentWebView` in a 260pt frame inside the bottom panel

Transition between modes is triggered by the camera button in the web UI, intercepted by the native JavaScript bridge.

### 8.4 `AgentWebViewStore` — Native ↔ Web Bridge (inside ContentView.swift)

A `WKScriptMessageHandler` that:

1. **Injects JavaScript** at document load that:
   - Creates `window.captureNativeCameraView()` — a Promise-based function the web JS can call to request a camera snapshot.
   - Intercepts clicks on `#camera-button` or `.file-button` and posts a `cameraTapped` message to native.
   - Sets up `window.__resolveNativeCameraCapture()` and `window.__rejectNativeCameraCapture()` for async callback resolution.

2. **Handles native messages**:
   - `cameraTapped` → sets `showCameraExperience = true`
   - `captureSurroundings` → calls `cameraSnapshotProvider()` → resolves the JavaScript Promise via `evaluateJavaScript()`

3. **Camera snapshot provider**: Set by `ContentView` based on current mode:
   - When camera is NOT active: throws `cameraUnavailable`.
   - When camera IS active: calls `cameraSnapshotStore.captureSnapshotPayload()`.

4. **TLS handling**: Accepts self-signed certificates for local development (`didReceive challenge` always trusts server).

5. **Media permissions**: Auto-grants microphone access for `WKWebView` (`requestMediaCapturePermissionFor` returns `.grant`).

### 8.5 `ARCameraSnapshotStore` — Camera Capture (inside ContentView.swift)

- Holds a weak reference to the `ARView`.
- `captureSnapshotPayload()`:
  1. Calls `arView.snapshot(saveToHDR: false)` → `UIImage`
  2. Converts to JPEG data at 0.7 quality
  3. Base64 encodes
  4. Returns `{ "mimeType": "image/jpeg", "imageBase64": "<base64>" }`

### 8.6 `ARViewContainer.swift` — AR Scene (267 lines)

A `UIViewRepresentable` wrapping `ARView`:

- **Configuration**: `ARWorldTrackingConfiguration` with `.horizontal` plane detection and automatic environment texturing.
- **Coaching overlay**: `ARCoachingOverlayView` with `.horizontalPlane` goal.
- **Plane detection**: `ARSessionDelegate` tracks when horizontal planes are detected, reports back via `onPlaneDetectionChanged` callback.
- **Product placement**: When products are available AND a plane is detected:
  1. Clears any previously placed models.
  2. Places up to 4 products in a 2×2 grid layout with offsets `±0.18m` on x and `±0.12m` on z.
  3. Each product gets a `ModelEntity`:
     - First tries to load the bundled `.usdz` file by `product.modelName`.
     - Falls back to a procedurally generated 3D model (base platform + stand + screen + bezel) using the product's `accentHex` color.
     - Scaled to `0.18` of original size.
  4. Models get collision shapes for tap interaction.
- **Selection**: Tapping a model in AR fires `onModelSelected(productID)`. Selected model scales up to 1.08×.
- **Caching**: USDZ models are cached in `modelPrototypeCache` and cloned for reuse.

### 8.7 `DesignSystem.swift` — iOS Design Tokens (213 lines)

**Color palette** (`AppTheme` enum):
- `accent`: teal-cyan `HSB(0.52, 0.78, 0.92)`
- `accentSecondary`: softer blue `HSB(0.62, 0.55, 0.88)`
- `accentWarm`: warm orange CTA `HSB(0.08, 0.72, 0.98)`
- Surfaces: dark backgrounds with white opacity layers (0.06, 0.10)
- Text: white at 100%, 72%, 48% opacity levels

**Gradients** (`AppGradient` enum):
- `accentButton`: teal → blue linear gradient
- `headerScrim`: black 72% → 38% → 0% (top-to-bottom scrim over AR camera)
- `panelBackground`: dark panel gradient
- `orbGlow`: radial glow for the `AgentOrb`

**Spacing** (`Spacing` enum): `xs=4, sm=8, md=12, lg=16, xl=20, xxl=28`

**Corner Radius** (`CornerRadius` enum): `sm=10, md=16, lg=22, xl=28, pill=100`

**Typography** (`Font` extensions): `.appLargeTitle` (28pt bold rounded), `.appTitle` (22pt), `.appHeadline` (17pt semibold), `.appSubheadline` (15pt medium), `.appBody` (15pt regular), `.appCaption` (13pt medium), `.appPrice` (20pt bold), `.appPriceSmall` (16pt bold), `.appBadge` (11pt bold).

**View Modifiers**:
- `.frostedGlass()`: `.ultraThinMaterial` background with subtle white border stroke.
- `.appCard(isSelected:)`: card background with optional selected border highlight + glow shadow.
- `PressableButtonStyle`: scales to 0.96 + opacity 0.88 on press.

**Reusable Components**:
- `DragHandle`: 36×4pt white capsule at 28% opacity.
- `StatusDot`: 8pt circle with pulsing ring animation when active.

### 8.8 `AgentOrb.swift` — Voice Indicator (99 lines)

A `ZStack` of concentric circles:
1. **Outer glow pulse**: accent-colored circle at 12% opacity, blurred 8px, pulsing between 1.0×–1.18× scale.
2. **Middle ring**: `AngularGradient` stroke (rotating gradient of accent colors), 2pt line width, rotates 360° over 6s.
3. **Inner ring**: white 12% opacity stroke, 1pt.
4. **Core orb**: `RadialGradient` fill (3 HSB colors creating a glossy sphere effect), 52pt diameter.
5. **Specular highlight**: white radial gradient overlay simulating a light reflection.
6. **Center sparkle**: 6pt white dot at 90% opacity when active.

Animations start on appear or when `isActive` changes to `true`.

### 8.9 `CartSheet.swift` — Native Cart (185 lines)

A `NavigationStack` sheet with dark background:
- **Empty state**: Large cart icon in a circle with explanatory text.
- **Cart items list**: `LazyVStack` of `CartItemRow` views, each showing a gradient color indicator, product title, quantity × price, and line total.
- **Summary footer**: Item count, total price, and a gradient "Checkout" capsule button (placeholder action).

### 8.10 `AgentViewModel.swift` — Camera Agent ViewModel (72 lines)

- Manages `recommendedProducts`, `selectedProductID`, `isPlaneDetected`, `placementRequestID`, `agentMessage`.
- `bootstrap()`: loads products from bundled `Products.json` via `ProductCatalogService`, runs initial search.
- `runSearch()`: uses `ProductCatalogService.recommendProducts()` for keyword matching, then `OpenAIService.rankProducts()` (currently a passthrough).
- `setPlaneDetected()`: updates AR status messages.

### 8.11 `VoiceSearchService.swift` — On-Device Speech (144 lines)

Uses Apple's `SFSpeechRecognizer` for on-device voice-to-text:
1. Requests speech recognition and microphone authorization.
2. Configures `AVAudioSession` for recording.
3. Installs an audio tap on `AVAudioEngine.inputNode`.
4. Feeds audio buffers to `SFSpeechAudioBufferRecognitionRequest`.
5. Streams partial and final transcription results via `onTranscript` callback.
6. Reports recognizer availability changes via `onAvailabilityChange`.

> [!NOTE]
> This is a **separate** speech system from the WebRTC Realtime API voice. The `VoiceSearchService` is used for the native discovery/search flow, while the Realtime API handles the conversational agent voice.

### 8.12 Other iOS Files

- **`ProductCatalogService.swift`**: Loads `Products.json` from the app bundle. `recommendProducts()` does keyword matching + budget extraction (regex for "under/below/less than $X") and returns top N products sorted by score.
- **`CatalogService.swift`**: Alternative catalog loader that also loads `sellers.json` and returns a `CatalogPayload` with products + sellers dictionary.
- **`OpenAIService.swift`**: Stub — `rankProducts()` currently returns products unchanged. Designed as the hook for server-side AI re-ranking.
- **`CartService.swift`**: Simple `ObservableObject` with `items: [CartItem]` array and `add()` method that increments quantity or appends.
- **`Product.swift`**: iOS product model (different from web schema — has `subtitle`, `modelName`, `accentHex` instead of `category`, `description`, `delivery`, etc.).
- **`CartItem.swift`**: `{ id: UUID, product: Product, quantity: Int }` with convenience init.

---

## 9. WebRTC Voice Session Protocol

### Connection Sequence

```
Client                     Server                    OpenAI
  │                          │                          │
  │ getUserMedia(audio)     │                          │
  │ new RTCPeerConnection() │                          │
  │ addTrack(micAudio)      │                          │
  │ createDataChannel("oai-events")                    │
  │ createOffer()           │                          │
  │                          │                          │
  │── POST /session ────────►│                          │
  │   body: SDP offer text   │                          │
  │                          │── POST /v1/realtime/calls►│
  │                          │   FormData:              │
  │                          │     sdp=<offer>          │
  │                          │     session=<JSON config>│
  │                          │◄── SDP answer ───────────│
  │◄── SDP answer ──────────│                          │
  │                          │                          │
  │ setRemoteDescription()   │                          │
  │                          │                          │
  │◄══════════ Direct WebRTC connection ═══════════════►│
  │   Audio: bidirectional mic/speaker                  │
  │   Data Channel: tool calls + results                │
```

### Data Channel Event Types

**Inbound (OpenAI → Client):**
- `input_audio_buffer.speech_started` — user started speaking
- `response.created` — agent started processing
- `response.output_audio.delta` — streaming audio chunk
- `response.audio_transcript.delta` — streaming text transcript
- `response.done` — agent finished responding
- `conversation.item.created` / `response.output_item.done` — tool call events (when `item.type === "function_call"`)

**Outbound (Client → OpenAI):**
- `session.update` — update session instructions
- `conversation.item.create` with `type: "function_call_output"` — tool execution result
- `response.create` — prompt the agent to generate the next response

---

## 10. Native ↔ Web Camera Bridge

This bridge allows the OpenAI Realtime API (running in the web view's WebRTC session) to capture a frame from the native ARKit camera.

### Flow

```
OpenAI Realtime API
  │  function_call: analyze_surroundings
  ▼
Web JS (ui.js) runRealtimeTool()
  │  calls window.captureNativeCameraView({ question })
  ▼
Injected JS Bridge (in WKWebView)
  │  Creates a Promise with requestId
  │  Posts message to native: webkit.messageHandlers.captureSurroundings
  ▼
Native Swift (AgentWebViewStore.handleCaptureRequest)
  │  Calls cameraSnapshotProvider() → ARCameraSnapshotStore.captureSnapshotPayload()
  │  arView.snapshot() → UIImage → JPEG 0.7 → base64
  ▼
Native Swift resolves via evaluateJavaScript()
  │  window.__resolveNativeCameraCapture(requestId, { mimeType, imageBase64 })
  ▼
Web JS Promise resolves
  │  POST /api/tools/analyze-surroundings { question, imageBase64, mimeType }
  ▼
Server (server.mjs)
  │  POST to OpenAI Vision API (gpt-4.1-mini)
  │  Returns { summary, visualClues[], suggestedSearchTerms[], confidence }
  ▼
Web JS sends function_call_output back to OpenAI Realtime via data channel
  ▼
OpenAI speaks the analysis result to the user
```

### Bridge JavaScript (injected at WKWebView load)

Key globals created:
- `window.captureNativeCameraView({ question })` → `Promise<{ imageBase64, mimeType }>`
- `window.__pendingNativeCameraCaptures` → `Map<requestId, { resolve, reject, timeoutId }>`
- `window.__resolveNativeCameraCapture(requestId, payload)` — called from native
- `window.__rejectNativeCameraCapture(requestId, message)` — called from native
- Timeout: 15 seconds per capture request.

---

## 11. Setup & Running Instructions

### Prerequisites

- **Node.js** 18+ (for ESM support and top-level await)
- **Xcode** 15+ with iOS 17 SDK (for the iOS app)
- **XcodeGen** (for generating the Xcode project from `project.yml`)
- An **OpenAI API key** with Realtime API access enabled
- An **iPhone** with ARKit support (for iOS AR features)

### Web-Only Setup (quickest path)

```bash
# 1. Clone the repo
git clone <repo-url> && cd Codex_Proto

# 2. Create .env
cat > .env << 'EOF'
OPENAI_API_KEY=sk-your-key-here
OPENAI_REALTIME_MODEL=gpt-realtime-2
OPENAI_REALTIME_VOICE=marin
OPENAI_VISION_MODEL=gpt-4.1-mini
PORT=3000
EOF

# 3. Start the server (no npm install needed — zero dependencies)
node server.mjs

# 4. Open http://localhost:3000 in a browser
```

> [!IMPORTANT]
> Voice features require HTTPS in most browsers (for `getUserMedia`). For local development over HTTP, use Chrome with `chrome://flags/#unsafely-treat-insecure-origin-as-secure` or set up TLS (see below).

### HTTPS Setup (required for iOS)

```bash
# 1. Generate a self-signed certificate for your LAN IP
mkdir -p certs
openssl req -x509 -newkey rsa:2048 -keyout certs/dev-key.pem \
  -out certs/dev-cert.pem -days 365 -nodes \
  -subj "/CN=192.168.1.73"

# 2. Add to .env
echo "SSL_KEY_FILE=certs/dev-key.pem" >> .env
echo "SSL_CERT_FILE=certs/dev-cert.pem" >> .env

# 3. Start the server — it will now listen on HTTPS
node server.mjs
# Output: Shopee agent server listening on https://0.0.0.0:3000
```

### iOS App Setup

```bash
# 1. Install XcodeGen
brew install xcodegen

# 2. Generate the Xcode project
cd ios
xcodegen generate

# 3. Open in Xcode
open ShopeeARDemo.xcodeproj

# 4. Update AgentBaseURL in Info.plist
#    Set to your machine's LAN IP, e.g.: https://192.168.1.73:3000

# 5. Select your iPhone as the run target
# 6. Build and run (Cmd+R)
```

> [!NOTE]
> The iOS app automatically accepts the self-signed TLS certificate in `WKWebView` for local development. This is handled in `AgentWebViewStore.webView(_:didReceive:completionHandler:)`.

### Verifying the Full Flow

1. **Text mode**: Type "My sink is leaking" in the web UI → should see 3 product cards appear in the recommendations drawer.
2. **Voice mode**: Click the mic button → grant microphone permission → speak a query → products should appear and the agent should speak a response.
3. **iOS Camera mode**: In the iOS app, tap the camera button → point at a surface → wait for plane detection → products appear in AR → expand the agent panel to interact with the voice agent → say "What am I looking at?" to trigger the vision pipeline.
