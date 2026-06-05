# Shopee Voice Agent — SEA × OpenAI Hackathon

## One-Liner

> **A voice-first, camera-aware shopping agent that lets Shopee users go from "I have a problem" to "it's in my cart" — in a single conversation.**

---

## The Problem

Online shopping today is **search-box-first**. Users must already know *what* to buy before they can find it. But real purchase intent often starts with an *uncertain situation*:

- "My sink is leaking — what do I need to fix it?"
- "I'm running low on moisturizer before an interview tomorrow."
- "What pants match these boots and a black jacket?"

The user doesn't have a keyword. They have a *problem*. Today's e-commerce experience forces them to translate that problem into a search query, sift through hundreds of results, compare sellers, check compatibility, and find vouchers — all manually.

**This is the gap we close.**

---

## What We Built

**Shopee Voice Agent** is a multimodal shopping assistant powered by **OpenAI's Realtime API** and **Vision API**, deeply integrated into Shopee's commerce stack. It understands natural language *and* what the user is looking at through their phone camera.

The experience is simple:

1. **Talk** — Describe your situation in natural language. No keywords needed.
2. **Show** — Point your phone's camera at the problem (a leaking pipe, an outfit, a room). The agent sees what you see.
3. **Shop** — The agent classifies your need, searches the catalog, recommends products with reasoning, applies the best voucher, and adds everything to your cart.

All in a single, continuous voice conversation.

---

## How It Works

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            USER EXPERIENCE                              │
│                                                                          │
│   "My sink is leaking.           ┌─────────────────────────────────┐    │
│    What do I buy?"        ──────►│  🎙️  Voice Input (WebRTC)        │    │
│                                  └──────────┬──────────────────────┘    │
│   Points camera at pipe   ──────►  📷  AR Camera Snapshot (base64)      │
│                                             │                           │
└─────────────────────────────────────────────┼───────────────────────────┘
                                              │
                                              ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                     OPENAI REALTIME API  (gpt-realtime-2)                │
│                                                                          │
│   Listens to user speech in real time via WebRTC.                        │
│   Decides WHICH tools to call and in what order.                         │
│   Speaks the response back — streaming, low-latency, natural voice.     │
│                                                                          │
│   Registered Tools:                                                      │
│     ► classify_need          — What category does this belong to?        │
│     ► analyze_surroundings   — What is the camera looking at?           │
│     ► search_catalog         — Find relevant products                   │
│     ► add_to_cart            — Place items in the cart                   │
│                                                                          │
└──────────────────────────────────┬───────────────────────────────────────┘
                                   │  Tool calls are routed to our backend
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                     SHOPEE COMMERCE BACKEND  (Node.js)                   │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  INTENT CLASSIFICATION                                          │   │
│   │  Keyword-driven categorization into domain playbooks:           │   │
│   │  home_repair · beauty · fashion · electronics · grocery         │   │
│   │  Each playbook tailors search ranking and agent personality.    │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                   │                                     │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  CATALOG SEARCH & RANKING                                       │   │
│   │  Scores products on: keyword match, category fit, price,        │   │
│   │  seller rating, delivery speed, stock, user preferences.        │   │
│   │  Returns top 5 with human-readable reasoning per product.       │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                   │                                     │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  SMART CART & CHECKOUT                                          │   │
│   │  Session-based cart · automatic bundle suggestions              │   │
│   │  Best-voucher auto-application · checkout preview with totals   │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  VISION ANALYSIS  (via OpenAI gpt-4.1-mini)                     │   │
│   │  Receives camera snapshot → returns visual clues,               │   │
│   │  suggested search terms, and confidence score.                  │   │
│   │  Results are fed back into catalog search automatically.        │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        PRODUCT RECOMMENDATIONS                           │
│                                                                          │
│   Agent speaks:                                                          │
│   "This looks like a small sink repair job. Start with a 15mm PVC       │
│    Slip Coupling from FixPro at $4.20. I'd also pair it with sealant   │
│    tape. Should I add the bundle to cart?"                               │
│                                                                          │
│   UI shows:                                                              │
│   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                   │
│   │ PVC Coupling  │ │ Sealant Tape │ │ WP Sealant   │                   │
│   │ $4.20  4.8★   │ │ $3.50  4.7★  │ │ $6.90  4.6★  │                  │
│   │ ✓ Best match  │ │ ✓ Bundle     │ │ ✓ Same-day   │                   │
│   │ [Add to cart] │ │ [Add to cart] │ │ [Add to cart] │                  │
│   └──────────────┘ └──────────────┘ └──────────────┘                   │
│                                                                          │
│   Voucher auto-applied · checkout preview shows final total             │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Dual-Client Experience

We built **two frontends** that share the same backend, demonstrating platform versatility:

| | **Web Client** | **iOS AR App** |
|---|---|---|
| **Stack** | Vanilla HTML/JS | SwiftUI + RealityKit |
| **Voice** | WebRTC via browser | WebRTC via embedded WKWebView |
| **Camera** | N/A (text fallback) | Native ARKit camera with live 3D surface detection |
| **Visual Agent** | Animated CSS orb + waveform | SwiftUI `AgentOrb` with radial gradients and pulse animation |
| **Cart** | In-page panel + dedicated cart page | Native `CartSheet` overlay |
| **Key Feature** | Works on any device with a browser | "Point-and-shop" — ask "What am I looking at?" and the agent uses the live AR feed |

The iOS app uses a **native ↔ web bridge** pattern: the voice agent UI runs in a shared `WKWebView`, but camera snapshots are captured natively via `ARView.snapshot()` and injected into the web context through a JavaScript bridge (`captureNativeCameraView`). This means the Realtime API's `analyze_surroundings` tool can pull a live camera frame even though the voice session lives in WebRTC.

---

## Key Technical Innovations

### 1. Voice-Native Tool Orchestration
The OpenAI Realtime API doesn't just chat — it **autonomously decides which tools to call and in what sequence**. A single utterance like "My sink is leaking" triggers a multi-step pipeline: `classify_need` → `search_catalog` → the agent formulates a recommendation and speaks it back. No prompt chaining, no manual orchestration — the model drives the flow.

### 2. Camera-to-Cart Pipeline
When the user says "What am I looking at?", the system:
1. Captures an AR camera snapshot (native iOS → base64 JPEG)
2. Sends it to `gpt-4.1-mini` for structured scene analysis
3. Extracts `visualClues` and `suggestedSearchTerms`
4. Feeds those directly into catalog search
5. The voice agent speaks the results

**The user never types a single character.** They speak and point — the system handles the rest.

### 3. Domain Playbooks
Intent classification doesn't just route to a category — it activates a **domain-specific playbook** that shapes how the agent reasons and communicates:
- **Home repair**: Prioritize compatibility, size, safety. Add cautions about measurement.
- **Beauty**: Prioritize skin type, routine fit, delivery speed. Avoid medical language.
- **Fashion**: Prioritize color matching, style coherence, outfit compatibility.
- **Electronics**: Prioritize device compatibility, ports, seller reliability.

This makes the agent feel like a knowledgeable specialist, not a generic chatbot.

### 4. WebRTC SDP Relay Architecture
The backend acts as a **thin relay**: it receives the client's SDP offer, attaches session configuration and tool definitions, and forwards it to OpenAI. After that, the WebRTC connection is **direct between the client and OpenAI** — the server never touches the audio stream. This gives us sub-second voice latency while keeping tool execution on our own infrastructure.

---

## Demo Scenarios

These three scenarios showcase the breadth of the system:

| Scenario | What the user says | What happens |
|---|---|---|
| **🔧 Home Repair** | "My sink is leaking. What do I buy?" | Agent classifies → home_repair, searches for PVC couplings + sealant, recommends a bundle, auto-applies a voucher, offers to add to cart. |
| **💄 Beauty** | "I'm running low on moisturizer before an interview." | Agent classifies → beauty, finds same-day delivery barrier moisturizer + facial mist bundle, prioritizes interview urgency in spoken response. |
| **👖 Fashion** | "What pants match these boots and a black jacket?" | Agent classifies → fashion, recommends dark denim + black belt, explains style coherence in the spoken reply. |
| **📷 Camera (iOS)** | *Points camera at a leaking pipe* "What do I need to fix this?" | Agent triggers `analyze_surroundings`, Vision API identifies pipe/leak/PVC, those clues feed into catalog search, agent speaks results. |

---

## Why This Matters for Shopee

### For Users
- **Zero-friction discovery**: No keyword translation required. Speak your problem, get a solution.
- **Context-aware shopping**: The agent uses visual context (camera), domain expertise (playbooks), and personal preferences (delivery priority, budget sensitivity) to curate results — not just keyword matching.
- **Hands-free checkout**: Especially powerful for home repair (hands are dirty), cooking (hands are busy), or accessibility scenarios.

### For the Platform
- **Higher conversion**: Users who describe intent in natural language have higher purchase intent than browsers.
- **Larger basket size**: Bundle recommendations and auto-voucher application increase AOV.
- **New interaction paradigm**: Voice + camera opens Shopee to use cases that search boxes can't serve — especially in SEA markets where mobile-first, voice-comfortable users are the majority.

---

## Tech Stack Summary

| Layer | Technology |
|---|---|
| Voice AI | OpenAI Realtime API (`gpt-realtime-2`) via WebRTC |
| Vision AI | OpenAI Vision API (`gpt-4.1-mini`) |
| Backend | Node.js (raw HTTP/HTTPS, no framework) |
| Web Frontend | Vanilla HTML/CSS/JS |
| iOS App | SwiftUI + RealityKit + ARKit + WKWebView bridge |
| Data | Mock JSON catalog (products, sellers, vouchers, users) |
| Protocol | WebRTC (voice + data channel), REST (tool execution) |

---

## What We'd Build Next (Production Roadmap)

1. **Live Shopee API integration** — Replace mock JSON with real catalog, cart, and voucher APIs.
2. **Multi-turn memory** — Persist conversation context across sessions ("Last time you fixed the kitchen sink, you also bought sealant tape").
3. **AR product preview** — Place 3D product models in the user's space before buying (RealityKit foundation is already in place).
4. **Multi-language voice** — Critical for SEA: Bahasa, Thai, Vietnamese, Tagalog voice support via Realtime API language options.
5. **Seller-side agent tools** — Let the agent negotiate, check live stock, or request seller discounts in real time.
