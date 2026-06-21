# Companies — `ListCompanies.vue` & `CompanyDetails.vue`

> **Elixir-native port:** these two screens are implemented as the LiveView
> pages `BeeleexWeb.CompaniesLive.Index` and `BeeleexWeb.CompaniesLive.Show`.
> See [liveview-pages.md](liveview-pages.md) for how to mount them. The GraphQL
> operations below are wrapped by `Beeleex.Api` functions (`get_companies/1`,
> `get_company/1`, `create_company/1`, `update_company/2`, `delete_company/1`,
> `get_unlinked_projects/1`, `link_projects/2`, `unlink_project/2`).

## `ListCompanies.vue`

Paginated, filterable table of companies for a Business Unit. Clicking a row
navigates to `CompanyDetails`.

### Props

| Prop | Type | Notes |
|------|------|-------|
| `graphqlUri` | String | GraphQL endpoint |
| `registeredToken` | String | `bu-authorization` header |
| `buId` | Number | Business Unit id |
| `availableProjects` | Array | Passed through |
| `configurations` | Object | UI flags |
| `companyDetailsPath`, `createCompanyPath`, `companiesPath` | String | Navigation targets |
| `hasCompanyUrl`, `hasNoCompanyUrl` | String | Conditional routing |

### GraphQL

- Smart query **`getCompanies`** → `GET_COMPANIES` (`graphql/Company.js`):
  ```graphql
  query getCompanies($filter:[Filter], $size:Int, $skip:Int) {
    getCompanies(filter:$filter, size:$size, skip:$skip) {
      companies { ...company }
      total
      count
    }
  }
  ```
  Pagination via `$size`/`$skip`; filtering via the `$filter` array, persisted in
  the route query string (`filters`).

### UI / Emits

- Uses `Alert`, `Table`, `Pagination`.
- Emits **`updateComponent`** to ask the root to switch screens.

---

## `CompanyDetails.vue`

The richest component: views a single company and supports **create / edit /
delete**, **project linking/unlinking**, and embeds the invoices and payment-
method screens for that company.

### Props

| Prop | Type | Notes |
|------|------|-------|
| `environment` | String | Resolves URI in solo mode |
| `graphqlUri` | String | GraphQL endpoint |
| `registeredToken` | String | `bu-authorization` header |
| `buId` | Number | Business Unit id |
| `companyId` | Number | Company being viewed |
| `isCreateCompany` | Boolean | Create vs. view/edit mode |
| `companyDetailsSolo` | Boolean | Standalone/deep-link mode (uses `getEnvironmentUrl(environment)` for the URI) |
| `availableProjects` | Array | Projects selectable for linking |
| `configurations` | Object | UI flags |
| `createCompanyPath`, `companiesPath`, `invoiceDetailsPath` | String | Navigation |
| `refreshInvoicesTimeout` | Number | Forwarded to `InvoicesMain` / `PaymentMethodMain` |

### GraphQL

Smart queries (`apollo: {}`):

| Key | Operation | Source |
|-----|-----------|--------|
| `getCompany` | `query getCompany($id:Int!)` | `GET_COMPANY` |
| `getUnlinkedProjects` | `query getUnlinkedProjects($projectIds:[CustomerProject])` | `UNLINKED_PROJECTS` |

Mutations (`this.$apollo.mutate`):

| Action | Operation | Source |
|--------|-----------|--------|
| Create | `mutation createCompany($company:CompanyInput!)` | `CREATE_COMPANY` |
| Edit | `mutation editCompany($company:CompanyInput!, $id:Int!)` | `EDIT_COMPANY` |
| Delete | `mutation deleteCompany($id:Int!)` | `DELETE_COMPANY` |
| Link projects | `mutation linkCustomerProject($id:Int!, $projectIds:[CustomerProject])` | `LINK_PROJECTS_TO_COMPANY` |
| Unlink project | `mutation unlinkCustomerProject($id:Int!, $projectId:CustomerProject)` | `UNLINK_PROJECT_FROM_COMPANY` |

Each call sets `uri` (solo → `getEnvironmentUrl(environment)`, else `graphqlUri`)
and `headers: { "bu-authorization": registeredToken }`. After mutations it
refetches `getCompany` / `getUnlinkedProjects`, then routes back to
`companiesPath` with `?refresh=true`.

### Embedded children

```vue
<InvoicesMain :company-id="companyId" :graphql-uri="..." :bu-id="buId"
  :registered-token="registeredToken" :is-create-company="isCreateCompany"
  @openSoloInvoice="(d) => $emit('openSoloInvoice', { invoiceId: d })"
  @invoiceFailed="isInvoicePaymentFailed = true" />

<PaymentMethodMain :company-id="companyId" :graphql-uri="..." :bu-id="buId"
  :registered-token="registeredToken" :company-details="company"
  :is-invoice-payment-failed="isInvoicePaymentFailed"
  @pmUpdated="$apollo.queries.getCompany.refetch()" />
```

### UI / Emits

- Uses `Inputs`, `Alert`, `Popup`, plus embedded `InvoicesMain` &
  `PaymentMethodMain`. Country list via `i18n-iso-countries`.
- Emits **`openSoloInvoice`** and **`updateComponent`**.
