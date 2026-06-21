# Frontend Components

> **Two implementations.** The Vue documents below describe the **legacy SPA**
> components (the historical source of truth for behaviour and fields). The
> **Elixir-native port** ships these screens as server-rendered Phoenix
> LiveView pages inside `beeleex` — see
> **[liveview-pages.md](liveview-pages.md)** (and **[theming.md](theming.md)**
> for restyling). New host apps should mount the LiveView pages; the Vue docs
> remain the reference for screen behaviour.

This section documents the Vue (Vue 2 + `vue-apollo`) frontend components that
render the **Beelee** billing UI inside a host "Business Unit" application. They
are the visual counterpart to the `Beeleex` Elixir client documented in the
[parent docs](../overview.md): the components talk to the Beelee **GraphQL**
server, while the Elixir library handles outbound API, webhooks, and token
verification.

> Source: `geeks-apps-bo/components/beelee/*.vue`. The GraphQL operations they
> reference live in `geeks-apps-bo/graphql/{Company,Invoices,Payments}.js`.

## Component map

| Component | Role | Doc |
|-----------|------|-----|
| `Beelee.vue` | Root orchestrator — picks which screen to render (`<component :is>`) and fans props down | [beelee-root.md](beelee-root.md) |
| `ListCompanies.vue` | Paginated, filterable table of companies | [companies.md](companies.md) |
| `CompanyDetails.vue` | Single company: view/create/edit/delete + project linking; hosts invoices & payment methods | [companies.md](companies.md) |
| `InvoicesMain.vue` | Paginated invoices table for a company | [invoices.md](invoices.md) |
| `InvoiceDetails.vue` | Single invoice view | [invoices.md](invoices.md) |
| `PaymentMethodMain.vue` | Payment methods table + setup/retry/default/deactivate | [payment-methods.md](payment-methods.md) |

## Composition

`Beelee.vue` is the only component a host app mounts directly. It dynamically
renders one child via `<component :is="componentsPrefix + componentName">` and
swaps `componentName` based on route/props:

```
Beelee.vue
 ├─ BeeleeListCompanies      (default)
 ├─ BeeleeCompanyDetails ──┬─ BeeleeInvoicesMain ── BeeleeInvoiceDetails
 │                         └─ BeeleePaymentMethodMain
 └─ BeeleeInvoiceDetails     (solo / deep-link)
```

`componentsPrefix` (prop) is prepended to each child name so the host registers
them globally as e.g. `BeeleeListCompanies`.

## Shared conventions

All data-fetching children follow the same pattern:

- **GraphQL client** — `vue-apollo` smart queries under `apollo: { ... }`, plus
  `this.$apollo.mutate(...)` for writes. Each call passes a per-request
  `uri` (`graphqlUri` prop, or `getEnvironmentUrl(environment)` in "solo" mode).
- **Auth** — every request sends the header `"bu-authorization": registeredToken`.
  The `registeredToken` prop is threaded down from the root.
- **Errors** — `graphQlError` / `handleErrorMessage` from `graphql/helpers`.
- **Shared UI** — `Alert`, `Table`, `Pagination`, `Popup`, `Inputs`,
  `RadioButtons`, `Loading`, `gAnimatedLoading` from the host component library.
- **i18n** — `this.$t` (vue-i18n); routing via `localePath`.

## Common props

These props recur across most components (types from the `props` blocks):

| Prop | Type | Meaning |
|------|------|---------|
| `graphqlUri` | String | Beelee GraphQL endpoint |
| `environment` | String | Resolves the GraphQL URI in solo mode via `getEnvironmentUrl` |
| `registeredToken` | String | Sent as `bu-authorization` header |
| `buId` / `businessUnitId` | Number | Business Unit identifier |
| `companyId` | Number | Selected company |
| `invoiceId` | Number | Selected invoice |
| `configurations` | Object | Host-supplied UI/config flags |
| `availableProjects` | Array | Projects available to link to a company |
| `*Path` | String | Route paths used for navigation between screens |
| `refreshInvoicesTimeout` | Number | Polling/refresh interval for invoices |

See each component doc for its full prop list and emitted events.
