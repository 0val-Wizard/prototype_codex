const cartPageCount = document.querySelector("#cart-page-count");
const cartPageNote = document.querySelector("#cart-page-note");
const cartPageStatus = document.querySelector("#cart-page-status");
const cartPageItems = document.querySelector("#cart-page-items");
const cartPageSummary = document.querySelector("#cart-page-summary");

const userId = new URLSearchParams(window.location.search).get("userId") || "u_001";

async function bootstrapCart() {
  const response = await fetch(`/api/cart?userId=${encodeURIComponent(userId)}`);
  const data = await response.json();
  renderCartPage(data);
}

function renderCartPage(data) {
  const cart = data.cart || [];
  const count = cart.reduce((total, item) => total + Number(item.quantity || 0), 0);
  cartPageCount.textContent = `${count} item${count === 1 ? "" : "s"}`;
  cartPageStatus.textContent = cart.length ? "Ready" : "Empty";
  cartPageNote.textContent = cart.length
    ? "These items were added from the assistant recommendations."
    : "Your cart is empty. Add items from the assistant to see them here.";

  if (!cart.length) {
    cartPageItems.innerHTML = '<div class="empty-state">No items in cart yet.</div>';
    cartPageSummary.innerHTML = "";
    return;
  }

  cartPageItems.innerHTML = cart
    .map(
      (item) => `
        <article class="cart-page-item">
          <div class="cart-page-item-head">
            <div>
              <h3>${escapeHtml(item.title || item.productId)}</h3>
              <p>${escapeHtml(item.description || "")}</p>
            </div>
            <strong>$${(Number(item.price || 0) * Number(item.quantity || 0)).toFixed(2)}</strong>
          </div>
          <div class="product-tags">
            <span class="product-tag">${item.quantity} × $${Number(item.price || 0).toFixed(2)}</span>
            <span class="product-tag">${item.rating}★ rating</span>
            <span class="product-tag">${escapeHtml(item.delivery || "standard")}</span>
          </div>
          <div class="product-footer">
            <strong>${escapeHtml(item.seller || "Unknown seller")}</strong>
            <span class="product-meta">${escapeHtml(item.reason || "")}</span>
          </div>
        </article>
      `
    )
    .join("");

  const summary = data.checkoutPreview;
  if (!summary) {
    cartPageSummary.innerHTML = "";
    return;
  }

  cartPageSummary.innerHTML = `
    <div class="summary-row"><span>Subtotal</span><strong>$${summary.subtotal.toFixed(2)}</strong></div>
    <div class="summary-row"><span>Discount${data.appliedVoucher ? ` (${escapeHtml(data.appliedVoucher.code)})` : ""}</span><strong>-$${summary.discount.toFixed(2)}</strong></div>
    <div class="summary-row"><span>Shipping</span><strong>$${summary.shipping.toFixed(2)}</strong></div>
    <div class="summary-row"><span>Total</span><strong>$${summary.total.toFixed(2)}</strong></div>
    <div class="summary-row"><span>Delivery</span><strong>${escapeHtml(summary.estimatedDelivery)}</strong></div>
  `;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

bootstrapCart().catch((error) => {
  console.error(error);
  cartPageStatus.textContent = "Error";
  cartPageItems.innerHTML = '<div class="empty-state">Failed to load your cart.</div>';
});
