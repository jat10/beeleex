# Payment methods — `PaymentMethodMain.vue`

Lists a company's payment methods and manages their lifecycle: add (Stripe
setup intent), retry, make default, and deactivate. Embedded inside
`CompanyDetails`.

> **Elixir-native port:** implemented as the embeddable LiveComponent
> `BeeleexWeb.PaymentMethodsLive.ListComponent` (rendered inside the company
> details page). Lifecycle actions call `Beeleex.Api.get_payment_methods/1`,
> `make_default_payment_method/2`, `deactivate_payment_method/1`,
> `reactivate_payment_method/1`. Adding a card uses
> `Beeleex.Api.request_setup_intent/1` plus the **`BeeleexStripeSetup`**
> JavaScript hook (`priv/static/beeleex/beeleex_hooks.js`). See the
> [Stripe wiring](#stripe-wiring-elixir-native) section below and
> [liveview-pages.md](liveview-pages.md).

### Props

| Prop | Type | Notes |
|------|------|-------|
| `graphqlUri` | String | GraphQL endpoint |
| `registeredToken` | String | `bu-authorization` header |
| `buId` | Number | Business Unit id |
| `companyId` | Number | Company whose methods are managed |
| `companyDetails` | Object | The parent company record |
| `isCreateCompany` | Boolean | Disable while creating a company |
| `isInvoicePaymentFailed` | Boolean | Set by parent when an invoice payment failed |
| `configurations` | Object | UI flags |
| `refreshInvoicesTimeout` | Number | Refresh interval |

### GraphQL

Smart query (`apollo: {}`):

| Key | Operation | Source |
|-----|-----------|--------|
| `getPaymentMethods` | `query getPaymentMethods($filter:[Filter], $size:Int, $skip:Int)` | `GET_PAYMENT_METHODS` |

Mutations (`this.$apollo.mutate`), all from `graphql/Payments.js`:

| Action | Operation | Imported as |
|--------|-----------|-------------|
| Start adding a card | `mutation requestSetupIntent($id:Int!)` | `REQUEST_SETUP_INTENT` |
| Deactivate a method | `mutation deactivatePaymentMethod($id:Int!)` | `DEACTIVATE_PAYMENT_METHOD` |
| Retry a method | `mutation retryPaymentMethod($id:Int!)` | `REACTIVATE_PAYMENT_METHOD` |
| Set default | `mutation changeDefaultPaymentMethod($companyId:Int!, $paymentId:Int!)` | `MAKE_DEFAULT_PAYMENT_METHOD` |

`requestSetupIntent` returns the Stripe client secret used to confirm a card
client-side. All requests carry `headers: { "bu-authorization": registeredToken }`.

### UI / Emits

- Uses `Alert`, `Table`, `Popup`, `RadioButtons`.
- Emits:
  - **`pmUpdated`** — payment methods changed; parent refetches the company
    (`$apollo.queries.getCompany.refetch()`).
  - **`refetchInvoices`** — ask the parent to refresh the invoices list (e.g.
    after fixing a failed payment).

---

## Stripe wiring (Elixir-native)

Adding a card is the one genuinely client-side flow, so the LiveView port ships
a JavaScript hook that host apps must register with their `LiveSocket`.

### Flow

```
"Add payment method" (click)
  -> component: Beeleex.Api.request_setup_intent(company_id)
       -> {client_secret, publishable_key}
  -> push_event "beeleex:init_stripe" {client_secret, publishable_key, target}
  -> BeeleexStripeSetup hook: load Stripe.js, mount card element
  -> "Save card" (click) -> stripe.confirmCardSetup(client_secret, {card})
       -> on success: pushEventTo(component, "payment_method_added")
  -> component: reload list + notify parent (counts refresh)
```

Beelee receives the new card via its own Stripe webhook; the component simply
re-queries `get_payment_methods/1` after a successful confirmation.

### Host setup

1. Make the hook available to your bundler. The file is shipped at
   `priv/static/beeleex/beeleex_hooks.js` inside the dependency:

   ```js
   // assets/js/app.js
   import { BeeleexHooks } from "../../deps/beeleex/priv/static/beeleex/beeleex_hooks.js"

   const liveSocket = new LiveSocket("/live", Socket, {
     params: { _csrf_token: csrfToken },
     hooks: { ...BeeleexHooks }   // merge with your own hooks
   })
   ```

   (The same file is also served by the bundled dev endpoint at
   `/beeleex/beeleex_hooks.js`.)

2. No Stripe keys are configured in your app — the publishable key comes from
   Beelee via `request_setup_intent/1`, and Stripe.js is loaded on demand from
   `https://js.stripe.com/v3`.

### DOM contract

The hook looks for these data attributes inside its root element (the component
renders them):

| Attribute | Purpose |
|-----------|---------|
| `data-beeleex-card-element` | container Stripe mounts the card element into |
| `data-beeleex-confirm-card` | the "Save card" button |
| `data-beeleex-card-errors` | element that receives card validation messages |
