# Gap Analysis: Original Plan vs. Current Build

## What's Built vs. What Was Planned

### Registered Realtime API Tools (what the voice agent can actually call)

| Tool | In Original Plan | Built in `commerce.mjs` | Registered as Realtime Tool | Notes |
|---|---|---|---|---|
| `classify_need` | ✅ | ✅ | ✅ | Working |
| `search_catalog` | ✅ | ✅ | ✅ | Working |
| `add_to_cart` | ✅ | ✅ | ✅ | Working |
| `analyze_surroundings` | ✅ (was `extract_visual_clues` / `analyze_image`) | ✅ | ✅ | Working — uses Vision API |
| `rank_products` | ✅ | ✅ (function exists) | ❌ Not a tool | Called internally by `runAgent()`, but the voice agent can't invoke it independently |
| `recommend_bundle` | ✅ | ✅ (function exists) | ❌ Not a tool | Same — internal only |
| `apply_best_voucher` | ✅ | ✅ (function exists) | ❌ Not a tool | Auto-applied inside `add_to_cart` endpoint, not a separate agent action |
| `checkout_preview` | ✅ | ✅ (function exists) | ❌ Not a tool | Auto-returned with cart, not independently callable |
| **`compare_products`** | ✅ | ❌ Not built | ❌ | **Missing entirely** |
| **`check_user_history`** | ✅ | ❌ Not built | ❌ | **Missing entirely** — user data exists but no tool uses it |
| **`ask_clarifying_question`** | ✅ | ❌ Not built | ❌ | Agent does this conversationally but not as a structured tool |

### Key Insight

**The voice agent currently has only 4 tools.** It can classify, search, add to cart, and look at the camera. That's it. It can't compare products, check purchase history, or proactively apply vouchers as distinct actions. Many functions exist in `commerce.mjs` but are wired as internal pipeline steps, not as tools the LLM can choose to call.

---

## Recommendations: What to Add to Win

### Priority 1: `check_user_history` (HIGH IMPACT, LOW EFFORT)

**Why judges will love this**: This is the "personalization" moment. The agent doesn't just search — it *knows you*. This is the difference between a search engine and an actual shopping assistant.

**Demo moment**: User says "I need to restock on skincare stuff." Agent calls `check_user_history`, sees they bought `SK001` (moisturizer) on April 20, and says: *"You bought Hydrating Barrier Repair Moisturizer about 6 weeks ago. Want me to reorder it? I can also check if there's a new voucher."*

**Implementation**:
- New function in `commerce.mjs`: `checkUserHistory({ userId }) → { pastPurchases[], reorderSuggestions[], daysSinceLastOrder }`
- Look up user from `users.json`, hydrate `order_history` with product details
- Calculate days since last purchase, flag items likely needing replenishment
- Register as Realtime tool so the agent can call it autonomously
- New endpoint: `POST /api/tools/check-user-history`

**Effort**: ~30 minutes

---

### Priority 2: `compare_products` (HIGH IMPACT, MEDIUM EFFORT)

**Why judges will love this**: This shows the agent doing *reasoning*, not just retrieval. Side-by-side comparison is something real shoppers need and current e-commerce doesn't do well with voice.

**Demo moment**: After search results come back, user says "Compare the first two options." Agent calls `compare_products` and says: *"The PVC coupling is cheaper at $4.20 but next-day delivery. The waterproof sealant is $6.90 but arrives same-day. Both are highly rated. I'd go with the coupling plus sealant tape as a bundle for $7.70 total."*

**Implementation**:
- New function: `compareProducts({ productIds }) → { comparison: { dimensions: [...], winner, reasoning } }`
- Compare on: price, rating, delivery speed, seller rating, stock availability
- Return structured comparison with a recommended winner and reasoning
- Register as Realtime tool
- New endpoint: `POST /api/tools/compare-products`
- **Bonus**: render a comparison card in the web UI when this tool is called

**Effort**: ~45 minutes

---

### Priority 3: Proactive Bundle + Voucher as Separate Agent Actions (MEDIUM IMPACT, LOW EFFORT)

**Why it matters**: Right now `recommend_bundle` and `apply_best_voucher` happen silently inside the add-to-cart flow. The agent never *talks about* them as decisions. If these are separate tools, the agent can say things like: *"I'd also pair this with sealant tape — want me to add the bundle?"* and *"I found a REPAIR10 voucher that saves you 10%. Applying it now."*

**Implementation**:
- Register `recommend_bundle` and `apply_best_voucher` in `getToolDefinitions()`
- Add them to `runTool()` dispatcher
- Add endpoints: `POST /api/tools/recommend-bundle`, `POST /api/tools/apply-voucher` (the apply-voucher endpoint already exists but isn't registered as a Realtime tool)

**Effort**: ~15 minutes

---

### Priority 4: Richer UI Feedback for Tool Calls (MEDIUM IMPACT, MEDIUM EFFORT)

**Why it matters**: Right now when the agent calls tools, the web UI only reacts to `search_catalog` (shows products) and `add_to_cart` (updates cart). Other tool calls are invisible. Showing real-time tool activity makes the demo feel *alive* and *agentic*.

**Suggestions**:
- Show a "thinking trail" in the assistant panel: "Classifying your need… → Home repair detected → Searching catalog… → Found 3 products → Checking for bundles… → Applying voucher REPAIR10"
- Flash the relevant UI section when a tool fires (e.g., pulse the cart badge when voucher is applied)
- Show a comparison card when `compare_products` is called

**Effort**: ~1 hour

---

### Priority 5: `checkout_preview` as an Agent-Callable Tool (LOW EFFORT, NICE-TO-HAVE)

Register `checkout_preview` as a Realtime tool so the agent can say "Here's your checkout summary" and the UI can render the totals panel. Currently it's auto-calculated but the agent never explicitly triggers it.

**Effort**: ~10 minutes

---

## What NOT to Add (diminishing returns for hackathon)

| Feature | Why Skip |
|---|---|
| `ask_clarifying_question` as a registered tool | The LLM already asks clarifying questions naturally in conversation. Making it a formal tool adds complexity without visible benefit. |
| Multi-agent orchestration | Overkill for a hackathon. Single agent with many tools is more impressive and reliable. |
| Real payment / checkout completion | Explicitly out of scope. The preview is the right stopping point. |
| More product categories / data | 9 products across 6 categories is plenty for a demo. Adding more data doesn't improve the pitch. |
| Complex cart management (remove, update qty) | Nice but low demo value — the happy path is add → checkout. |

---

## Suggested Implementation Order

If you have **2 hours**:

1. ✅ `check_user_history` tool + endpoint + registration (30 min)
2. ✅ Register `recommend_bundle` and `apply_best_voucher` as Realtime tools (15 min)
3. ✅ Register `checkout_preview` as Realtime tool (10 min)
4. ✅ `compare_products` tool + endpoint + registration (45 min)
5. ✅ UI thinking trail for tool calls (20 min)

This takes you from **4 tools → 8 tools**, and critically, gives the agent the ability to:
- Remember who the user is and what they've bought before
- Compare options intelligently
- Proactively suggest bundles as a separate conversational step
- Explicitly apply vouchers and explain the savings
- Show a checkout summary on demand

---

## Updated Tool Registration After Changes

```js
// getToolDefinitions() in commerce.mjs — proposed additions
{
  type: "function",
  name: "check_user_history",
  description: "Look up the user's past purchases and preferences to personalize recommendations or suggest reorders.",
  parameters: {
    type: "object",
    properties: {
      userId: { type: "string" }
    },
    required: ["userId"]
  }
},
{
  type: "function",
  name: "compare_products",
  description: "Compare two or more products side by side on price, rating, delivery speed, and seller quality.",
  parameters: {
    type: "object",
    properties: {
      productIds: { type: "array", items: { type: "string" } }
    },
    required: ["productIds"]
  }
},
{
  type: "function",
  name: "recommend_bundle",
  description: "Find complementary products that pair well with a primary product.",
  parameters: {
    type: "object",
    properties: {
      primaryProductId: { type: "string" }
    },
    required: ["primaryProductId"]
  }
},
{
  type: "function",
  name: "apply_best_voucher",
  description: "Find and apply the best available voucher for the current cart.",
  parameters: {
    type: "object",
    properties: {
      category: { type: "string" }
    }
  }
},
{
  type: "function",
  name: "checkout_preview",
  description: "Calculate and show the checkout summary with subtotal, discount, shipping, and total.",
  parameters: {
    type: "object",
    properties: {}
  }
}
```

---

## Updated Demo Script with New Capabilities

### Enhanced Repair Scenario

```
User:  "I need to fix something in my kitchen"

Agent: [calls check_user_history]
       "I can see you're based in Singapore. You haven't bought any
        repair items before. What's the issue?"

User:  "The pipe under my sink is leaking"

Agent: [calls classify_need → home_repair]
       [calls search_catalog]
       "I found 3 products for a pipe leak repair. The top match is
        a 15mm PVC Slip Coupling at $4.20."

       [calls recommend_bundle]
       "I'd also pair it with waterproof sealant tape for $3.50.
        Together that's $7.70 for a complete fix. Want me to compare
        the options first or add the bundle?"

User:  "Compare them"

Agent: [calls compare_products]
       "The coupling is the core fix at $4.20, rated 4.8 stars,
        next-day delivery. The sealant tape is $3.50, rated 4.7,
        also next-day. The waterproof sealant is $6.90 but arrives
        same-day. All three together give you a complete repair kit
        for $14.60. Want me to add all three?"

User:  "Yes, add them all"

Agent: [calls add_to_cart]
       [calls apply_best_voucher]
       "Done! I applied the REPAIR10 voucher — that's 10% off,
        saving you $1.46."

       [calls checkout_preview]
       "Your total is $16.13 including $2.99 shipping. Everything
        arrives by tomorrow. Ready to checkout?"
```

**This demo shows 7 distinct tool calls in a single conversation — that's the "agentic" story judges want to see.**
