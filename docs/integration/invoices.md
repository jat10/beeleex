# Invoices — `InvoicesMain.vue` & `InvoiceDetails.vue`

> **Elixir-native port:** the invoices list is the embeddable LiveComponent
> `BeeleexWeb.InvoicesLive.ListComponent` (rendered inside the company details
> page), and the detail screen is the LiveView `BeeleexWeb.InvoicesLive.Show`
> (route `/companies/:id/invoices/:invoice_id`). Data comes from
> `Beeleex.Api.get_invoices/1` and `Beeleex.Api.get_invoice/1`. To scope
> invoices to a company, `get_invoices/1` is passed
> `filter: [%{key: "company_id", value: to_string(company_id)}]`. See
> [liveview-pages.md](liveview-pages.md).

## `InvoicesMain.vue`

Paginated invoices table for a company. Used both embedded inside
`CompanyDetails` and standalone (`invoicesSeparateComponent` / `invoicesSolo`).

### Props

| Prop | Type | Notes |
|------|------|-------|
| `graphqlUri` | String | GraphQL endpoint |
| `registeredToken` | String | `bu-authorization` header |
| `buId` | Number | Business Unit id |
| `companyId` | Number | Company whose invoices are listed |
| `isCreateCompany` | Boolean | Hide/disable while creating a company |
| `invoicesSeparateComponent` | Boolean | Standalone render |
| `invoicesSolo` | Boolean | Deep-link / solo mode |
| `availableProjects` | Array | Passed through |
| `configurations` | Object | UI flags |
| `invoiceDetailsPath` | String | Navigation target for a row |

### GraphQL

| Key | Operation | Source |
|-----|-----------|--------|
| `getCompanies` | inline `gql` `query getCompanies($filter:[Filter], $size:Int, $skip:Int)` | inline in component |
| `getInvoices` | `query getInvoices($filter:[Filter], $size:Int, $skip:Int)` | `GET_INVOICES` (`graphql/Invoices.js`) |

```graphql
query getInvoices($filter:[Filter], $size:Int, $skip:Int) {
  getInvoices(filter:$filter, size:$size, skip:$skip) {
    total
    count
    invoices { ...invoice }
  }
}
```

Pagination via `$size`/`$skip`; the component also reacts to
`refreshInvoicesTimeout` for periodic refresh.

### UI / Emits

- Uses `Alert`, `Table`, `Pagination`, `Loading`.
- Emits:
  - **`openSoloInvoice`** — open a specific invoice standalone.
  - **`invoiceFailed`** — a payment for an invoice failed (parent sets
    `isInvoicePaymentFailed`).
  - **`updateComponent`** — request a screen change.

---

## `InvoiceDetails.vue`

Read-only view of a single invoice.

### Props

| Prop | Type | Notes |
|------|------|-------|
| `environment` | String | Resolves URI in solo mode |
| `graphqlUri` | String | GraphQL endpoint |
| `registeredToken` | String | `bu-authorization` header |
| `buId` | Number | Business Unit id |
| `companyId` | Number | Owning company |
| `invoiceId` | Number | Invoice to display |
| `configurations` | Object | UI flags |
| `invoicesSeparateComponent` | Boolean | Standalone render |
| `invoiceSolo` | Boolean | Deep-link / solo mode |
| `backEventSolo` | Boolean | Controls "back" behaviour in solo mode |

### GraphQL

| Key | Operation | Source |
|-----|-----------|--------|
| `getInvoice` | `query getInvoice($id:Int!)` | `GET_INVOICE` (`graphql/Invoices.js`) |

### UI / Emits

- Uses `TextParagraph`, `Table`.
- Emits **`backEvent`** (navigate back) and **`updateComponent`**.
