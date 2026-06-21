/**
 * Beeleex LiveView JavaScript hooks.
 *
 * Ship these hooks to your LiveSocket so the Beeleex billing pages can drive the
 * client-side Stripe flow used to add a payment method.
 *
 * Usage (in your app.js):
 *
 *   import { BeeleexHooks } from "../../deps/beeleex/priv/static/beeleex/beeleex_hooks.js"
 *
 *   const liveSocket = new LiveSocket("/live", Socket, {
 *     params: { _csrf_token: csrfToken },
 *     hooks: { ...BeeleexHooks }
 *   })
 *
 * The `BeeleexStripeSetup` hook listens for a "beeleex:init_stripe" event pushed
 * by the payment-methods component, loads Stripe.js on demand, mounts a card
 * element, and on confirmation calls stripe.confirmCardSetup(). On success it
 * pushes "payment_method_added" back to the component so the list refreshes.
 */

const STRIPE_JS_URL = "https://js.stripe.com/v3";

function loadStripeJs() {
  return new Promise((resolve, reject) => {
    if (window.Stripe) {
      resolve(window.Stripe);
      return;
    }

    const existing = document.querySelector(`script[src="${STRIPE_JS_URL}"]`);
    if (existing) {
      existing.addEventListener("load", () => resolve(window.Stripe));
      existing.addEventListener("error", reject);
      return;
    }

    const script = document.createElement("script");
    script.src = STRIPE_JS_URL;
    script.onload = () => resolve(window.Stripe);
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

const BeeleexStripeSetup = {
  mounted() {
    this.stripe = null;
    this.card = null;
    this.clientSecret = null;

    this.handleEvent("beeleex:init_stripe", (payload) => {
      // Only react to events targeted at this component instance.
      if (payload.target && payload.target !== `#${this.el.id}`) return;
      this.initStripe(payload);
    });
  },

  destroyed() {
    if (this.card) this.card.unmount();
  },

  async initStripe({ client_secret, publishable_key }) {
    this.clientSecret = client_secret;

    try {
      const Stripe = await loadStripeJs();
      this.stripe = Stripe(publishable_key);
    } catch (_error) {
      this.setError("Could not load Stripe.js");
      return;
    }

    // Wait a tick so the (now visible) modal container is in the DOM.
    requestAnimationFrame(() => this.mountCard());
  },

  mountCard() {
    const container = this.el.querySelector("[data-beeleex-card-element]");
    const confirmButton = this.el.querySelector("[data-beeleex-confirm-card]");
    if (!container || !confirmButton) return;

    const elements = this.stripe.elements();
    this.card = elements.create("card");
    this.card.mount(container);
    this.card.on("change", (event) => this.setError(event.error ? event.error.message : ""));

    this.confirmHandler = () => this.confirmCard(confirmButton);
    confirmButton.addEventListener("click", this.confirmHandler);
  },

  async confirmCard(confirmButton) {
    if (!this.stripe || !this.clientSecret) return;
    confirmButton.disabled = true;

    const result = await this.stripe.confirmCardSetup(this.clientSecret, {
      payment_method: { card: this.card }
    });

    confirmButton.disabled = false;

    if (result.error) {
      this.setError(result.error.message);
      return;
    }

    if (result.setupIntent && result.setupIntent.status === "succeeded") {
      this.setError("");
      // Notify the owning LiveComponent so it can refresh its list.
      this.pushEventTo(this.el, "payment_method_added", {
        payment_method: result.setupIntent.payment_method
      });
    }
  },

  setError(message) {
    const node = this.el.querySelector("[data-beeleex-card-errors]");
    if (node) node.textContent = message || "";
  }
};

export const BeeleexHooks = { BeeleexStripeSetup };
export default BeeleexHooks;
