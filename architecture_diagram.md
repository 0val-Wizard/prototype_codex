# Shopee Voice Agent — System Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND CLIENTS                                   │
│                                                                                 │
│   ┌───────────────────────────────┐     ┌───────────────────────────────────┐   │
│   │      Web Client               │     │      iOS AR App                   │   │
│   │  ┌─────────────────────────┐  │     │  ┌─────────────────────────────┐  │   │
│   │  │ index.html              │  │     │  │ ARShoppingApp.swift         │  │   │
│   │  │ ui.js (WebRTC + DOM)    │  │     │  │ ContentView.swift           │  │   │
│   │  │ styles.css              │  │     │  │ AgentOrb.swift (voice UI)   │  │   │
│   │  │ cart.html / cart.js     │  │     │  │ CartSheet.swift             │  │   │
│   │  └─────────────────────────┘  │     │  │ AgentViewModel (networking) │  │   │
│   └──────────────┬────────────────┘     │  │ CartService (state)         │  │   │
│                  │                      │  └─────────────────────────────┘  │   │
│                  │                      └──────────────┬────────────────────┘   │
│                  │                                     │                        │
└──────────────────┼─────────────────────────────────────┼────────────────────────┘
                   │                                     │
        ┌──────────┴──────────┐               ┌──────────┴──────────┐
        │  HTTP REST calls    │               │  HTTP REST calls    │
        │  POST /session      │               │  POST /session      │
        │  POST /api/agent    │               │  POST /api/agent    │
        │  POST /api/tools/*  │               │  POST /api/tools/*  │
        │  GET  /api/cart     │               │  GET  /api/cart     │
        │  GET  /api/bootstrap│               │  GET  /api/bootstrap│
        └──────────┬──────────┘               └──────────┬──────────┘
                   │                                     │
                   ▼                                     ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         NODE.JS BACKEND SERVER                                  │
│                            (server.mjs)                                         │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         HTTP/HTTPS Request Router                       │   │
│   │                                                                         │   │
│   │   POST /session ──────────────────► SDP relay to OpenAI Realtime API    │   │
│   │   GET  /api/bootstrap ────────────► getBootstrap()                      │   │
│   │   GET  /api/cart ─────────────────► getCartSnapshot()                   │   │
│   │   POST /api/agent ────────────────► runAgent()                          │   │
│   │   POST /api/tools/classify-need ──► classifyNeed()                      │   │
│   │   POST /api/tools/search-catalog ─► searchCatalog()                     │   │
│   │   POST /api/tools/add-to-cart ────► addToCart() + applyBestVoucher()    │   │
│   │   POST /api/tools/apply-voucher ──► applyBestVoucher()                  │   │
│   │   POST /api/tools/checkout-preview► checkoutPreview()                   │   │
│   │   POST /api/tools/analyze-surroundings ► analyzeSurroundings()          │   │
│   │   GET  /* ────────────────────────► Static file server                  │   │
│   │                                                                         │   │
│   └───────────────────────────────┬─────────────────────────────────────────┘   │
│                                   │                                             │
│                                   ▼                                             │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                    COMMERCE LOGIC ENGINE                                │   │
│   │                       (commerce.mjs)                                    │   │
│   │                                                                         │   │
│   │   ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐   │   │
│   │   │  classifyNeed()  │  │ searchCatalog()   │  │ recommendBundle()  │   │   │
│   │   │  Keyword-based   │  │ Score + rank      │  │ Find companion     │   │   │
│   │   │  intent routing  │  │ products by       │  │ products from      │   │   │
│   │   │  into categories │  │ relevance, price, │  │ bundleItems list   │   │   │
│   │   │                  │  │ rating, delivery  │  │                    │   │   │
│   │   └──────────────────┘  └──────────────────┘  └────────────────────┘   │   │
│   │                                                                         │   │
│   │   ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐   │   │
│   │   │  addToCart()      │  │ applyBestVoucher()│  │ checkoutPreview()  │   │   │
│   │   │  Session-based   │  │ Find highest-     │  │ Calculate totals,  │   │   │
│   │   │  cart management │  │ value eligible    │  │ shipping, and      │   │   │
│   │   │  per userId      │  │ voucher           │  │ estimated delivery │   │   │
│   │   └──────────────────┘  └──────────────────┘  └────────────────────┘   │   │
│   │                                                                         │   │
│   │   ┌──────────────────┐  ┌──────────────────┐                           │   │
│   │   │  runAgent()      │  │ rankProducts()    │  Category Playbooks:     │   │
│   │   │  Full pipeline:  │  │ Re-rank by user   │  • home_repair           │   │
│   │   │  classify → clue │  │ preferences       │  • beauty                │   │
│   │   │  → search → rank │  │ (delivery, budget)│  • fashion               │   │
│   │   │  → bundle → reply│  │                   │  • electronics           │   │
│   │   └──────────────────┘  └──────────────────┘  • grocery / home_decor   │   │
│   │                                                                         │   │
│   └───────────────────────────────┬─────────────────────────────────────────┘   │
│                                   │                                             │
│                                   ▼                                             │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                        LOCAL MOCK DATA (JSON)                           │   │
│   │                                                                         │   │
│   │    data/products.json    Product catalog with prices, ratings,          │   │
│   │                          delivery options, keywords, bundleItems        │   │
│   │    data/sellers.json     Seller names and ratings                       │   │
│   │    data/vouchers.json    Discount/voucher rules (%, fixed, shipping)    │   │
│   │    data/users.json       User profiles and preferences                  │   │
│   │                                                                         │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────┬───────────────────────────────┬───────────────────────┘
                          │                               │
              ┌───────────┴───────────┐       ┌───────────┴───────────┐
              │  SDP Offer + Session  │       │  Vision API Request   │
              │  Config + Tool Defs   │       │  (base64 image +      │
              │                       │       │   question prompt)     │
              └───────────┬───────────┘       └───────────┬───────────┘
                          │                               │
                          ▼                               ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          EXTERNAL APIs (OpenAI)                                 │
│                                                                                 │
│   ┌───────────────────────────────────┐  ┌──────────────────────────────────┐   │
│   │   OpenAI Realtime API             │  │   OpenAI Vision API              │   │
│   │   Model: gpt-realtime-2           │  │   Model: gpt-4.1-mini           │   │
│   │                                   │  │                                  │   │
│   │   • Receives SDP offer from       │  │   • Receives base64 camera      │   │
│   │     server, returns SDP answer    │  │     snapshot from server         │   │
│   │   • Establishes WebRTC peer       │  │   • Returns structured JSON:     │   │
│   │     connection DIRECTLY to client │  │     - summary                    │   │
│   │   • Streams audio both ways       │  │     - visualClues[]             │   │
│   │   • Sends tool call events over   │  │     - suggestedSearchTerms[]    │   │
│   │     the WebRTC data channel       │  │     - confidence score          │   │
│   │   • Registered tools:             │  │                                  │   │
│   │     - classify_need               │  │   Used when the user asks about  │   │
│   │     - search_catalog              │  │   what they're currently seeing   │   │
│   │     - add_to_cart                 │  │   through the camera.            │   │
│   │     - analyze_surroundings        │  │                                  │   │
│   └───────────────────────────────────┘  └──────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## WebRTC Voice Session — Connection Flow

```
  Client (Web/iOS)              Server (server.mjs)           OpenAI Realtime API
        │                              │                              │
        │  1. getUserMedia(audio)      │                              │
        │  2. createOffer()            │                              │
        │                              │                              │
        │──── POST /session (SDP) ────►│                              │
        │                              │── POST /v1/realtime/calls ──►│
        │                              │   (SDP + session config      │
        │                              │    + tool definitions)       │
        │                              │                              │
        │                              │◄──── SDP Answer ─────────────│
        │◄──── SDP Answer ────────────│                              │
        │                              │                              │
        │◄═══════════ WebRTC Peer Connection (DIRECT) ══════════════►│
        │         Audio stream (mic → agent → speakers)               │
        │         Data channel (tool calls + results)                 │
        │                              │                              │
```

## Tool Execution — Runtime Flow

```
  Client (Web/iOS)              Server (server.mjs)           OpenAI Realtime API
        │                              │                              │
        │  User speaks: "My sink       │                              │
        │  is leaking"                 │                              │
        │──── audio over WebRTC ──────────────────────────────────────►
        │                              │                              │
        │                              │    LLM decides to call tool  │
        │◄──── function_call: classify_need ──────────────────────────│
        │      {message: "sink leak"}  │                              │
        │                              │                              │
        │── POST /api/tools/classify-need ─►│                         │
        │   {message: "sink leak"}     │                              │
        │                              │  classifyNeed() →            │
        │                              │  {category: "home_repair",   │
        │◄──── {category, confidence} ─│   confidence: 0.75}          │
        │                              │                              │
        │──── function_call_output ───────────────────────────────────►
        │     + response.create        │                              │
        │                              │                              │
        │                              │    LLM calls search_catalog  │
        │◄──── function_call: search_catalog ─────────────────────────│
        │                              │                              │
        │── POST /api/tools/search-catalog ─►│                        │
        │                              │  searchCatalog() →           │
        │                              │  scores & ranks products     │
        │◄──── {products[]} ───────────│                              │
        │                              │                              │
        │  UI updates: show product    │                              │
        │  recommendation cards        │                              │
        │                              │                              │
        │──── function_call_output ───────────────────────────────────►
        │                              │                              │
        │◄════ Agent speaks: "I found a PVC coupling..." ═════════════│
        │      (audio streamed via WebRTC)                            │
        │                              │                              │
```

## Camera / Vision — AR Flow

```
  iOS App                    Server (server.mjs)         OpenAI Vision API
    │                              │                          │
    │  User says: "What am I       │                          │
    │  looking at?"                │                          │
    │                              │                          │
    │  Realtime API triggers       │                          │
    │  analyze_surroundings        │                          │
    │                              │                          │
    │  captureNativeCameraView()   │                          │
    │  → snapshot as base64        │                          │
    │                              │                          │
    │── POST /api/tools/           │                          │
    │   analyze-surroundings       │                          │
    │   {question, imageBase64}  ──►                          │
    │                              │── POST /v1/responses ───►│
    │                              │   (gpt-4.1-mini)         │
    │                              │   system: "Analyze       │
    │                              │    scene for shopping"   │
    │                              │   image + question       │
    │                              │                          │
    │                              │◄── {summary,             │
    │                              │     visualClues[],       │
    │◄──── analysis result ────────│     suggestedSearchTerms}│
    │                              │                          │
    │  Result fed back to          │                          │
    │  Realtime API → agent        │                          │
    │  speaks about what it sees   │                          │
    │                              │                          │
```

## File Map

```
Codex_Proto/
├── .env                          # API keys & config (OPENAI_API_KEY, model, voice, TLS)
├── server.mjs                    # HTTP server, SDP relay, tool endpoints, vision proxy
├── commerce.mjs                  # All shopping logic: classify, search, cart, voucher, bundle
├── index.html                    # Web UI: orb, composer, product drawer, cart panel
├── ui.js                         # Web client: WebRTC setup, tool execution, DOM rendering
├── styles.css                    # Design system and responsive layout
├── cart.html / cart.js           # Dedicated cart page
├── data/
│   ├── products.json             # Product catalog (id, title, price, rating, keywords, delivery)
│   ├── sellers.json              # Seller profiles (id, name, rating)
│   ├── vouchers.json             # Voucher rules (percent, fixed, free_shipping, minSpend)
│   └── users.json                # User profiles (preferences: delivery, budget)
└── ios/
    └── ShopeeARDemo/
        ├── ARShoppingApp.swift           # App entry point, injects CartService & AgentViewModel
        ├── ContentView.swift             # Root navigation view
        └── Features/
            ├── Recommendations/
            │   └── AgentOrb.swift         # Animated voice indicator orb (SwiftUI)
            └── Cart/
                └── CartSheet.swift        # Cart overlay sheet
```
