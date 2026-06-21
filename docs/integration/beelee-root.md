# `Beelee.vue` — root orchestrator

The single entry point a host app mounts. It renders **no business UI itself**;
instead it dynamically swaps between the screens and forwards props/events.

```vue
<component
  :is="componentsPrefix + componentName"
  :registered-token="registeredToken"
  :bu-id="businessUnitId"
  :graphql-uri="graphqlUri"
  ...
  @updateComponent="onComponentUpdate"
  @openSoloInvoice="(d) => $emit('openSoloInvoice', d)"
  @backEvent="(d) => $emit('backEvent', d)" />
```

## Props

| Prop | Type | Notes |
|------|------|-------|
| `environment` | String | Resolves `graphqlUri` via `getEnvironmentUrl(environment)` |
| `devGraphqlUri` | String | Override URI used in dev |
| `componentsPrefix` | String | Prepended to child component names (e.g. `Beelee`) |
| `companyComponent` | String | Watched; forces `componentName` to a specific screen |
| `registeredToken` | String | `bu-authorization` header, forwarded to all children |
| `currentComponent` | Object | Drives initial `componentName`/`isCreate` |
| `businessUnitId` | Number | Forwarded as `buId` |
| `availableProjects` | Array | Forwarded to company screens |
| `configurations` | Object | Forwarded everywhere |
| `invoicesSeparateComponent` | Boolean | Render invoice screens standalone |
| `invoiceSolo` / `backEventSolo` | Boolean | Deep-link / "solo" invoice mode |
| `invoiceIdProp` | Number | Deep-linked invoice id |
| `companyDetailsSolo` | Boolean | Deep-link / "solo" company mode |
| `companyIdProp` | Number | Deep-linked company id |
| `createCompanyPath`, `companyDetailsPath`, `companiesPath`, `invoiceDetailsPath` | String | Route paths for navigation |
| `hasCompanyUrl`, `hasNoCompanyUrl` | String | Conditional routing URLs |
| `refreshInvoicesTimeout` | Number | Forwarded to invoice/payment screens |

## Local state

| Data | Default | Meaning |
|------|---------|---------|
| `componentName` | `'BeeleeListCompanies'` | Currently rendered child |
| `isCreate` | `false` | Whether `CompanyDetails` is in create mode |
| `graphqlUri` | `""` | Resolved from `environment` / `devGraphqlUri` |

## Routing logic

On mount and via watchers, `componentName` is chosen from the route/props:

- invoice path → `BeeleeInvoiceDetails`
- company path → `BeeleeCompanyDetails`
- create-company path → `BeeleeCompanyDetails` with `isCreate = true`
- otherwise → falls back to `currentComponent.name` or `BeeleeListCompanies`

`graphqlUri` is computed as `getEnvironmentUrl(environment)`, or `devGraphqlUri`
in development.

## Emits

| Event | Payload | When |
|-------|---------|------|
| `componentUpdated` | component | A child requested a screen change (`onComponentUpdate`) |
| `openSoloInvoice` | invoice data | Re-emitted from a child to open an invoice standalone |
| `backEvent` | data | Re-emitted "back" navigation from a child |

## Host usage sketch

```vue
<Beelee
  components-prefix="Beelee"
  :business-unit-id="buId"
  :registered-token="token"
  environment="production"
  :available-projects="projects"
  :configurations="config"
  companies-path="/billing/companies"
  company-details-path="/billing/company"
  create-company-path="/billing/company/new"
  invoice-details-path="/billing/invoice"
  @openSoloInvoice="..." />
```

The host must globally register the child components under the chosen prefix
(`BeeleeListCompanies`, `BeeleeCompanyDetails`, `BeeleeInvoicesMain`,
`BeeleeInvoiceDetails`, `BeeleePaymentMethodMain`).
