# LiveView billing pages (Elixir-native)

These are the **Phoenix LiveView** port of the legacy Vue back-office screens.
A host application that depends on `beeleex` can mount ready-made, server-
rendered billing pages with a one-line router macro — no SPA, no GraphQL client,
and no Beelee tokens in the browser.

> **Status:** ships the **Companies** screens (list + details, including
> create/edit/delete and customer-project linking), the **Invoices** screens
> (per-company list + invoice detail), and **Payment methods** (per-company
> list with make-default / deactivate / retry, plus add-card via a Stripe
> JavaScript hook). All three are embedded in the company details page.

## How it works

```
Host LiveView (server)
  -> Beeleex.Api.get_companies/get_company/create_company/...
       ExGeeks.Helpers.endpoint_post_callback(url, %{query, variables}, headers)
       headers = secure-key + bu-id          # server-to-server, never in browser
  -> Beelee GraphQL
```

The LiveViews resolve their API module via
`Application.compile_env(:beeleex, :api_module, Beeleex.Api)`, so production uses
`Beeleex.Api` and tests inject a mock.

## Mounting the pages

In your application's router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Beeleex.Routes, live: true, scope: "/billing", pipe_through: [:require_admin]
end
```

This mounts, under `:scope` (default `/beeleex`):

| Path | LiveView | Action |
|------|----------|--------|
| `GET /companies` | `BeeleexWeb.CompaniesLive.Index` | `:index` |
| `GET /companies/new` | `BeeleexWeb.CompaniesLive.Show` | `:new` |
| `GET /companies/:id` | `BeeleexWeb.CompaniesLive.Show` | `:show` |
| `GET /companies/:id/edit` | `BeeleexWeb.CompaniesLive.Show` | `:edit` |
| `GET /companies/:id/invoices/:invoice_id` | `BeeleexWeb.InvoicesLive.Show` | `:show` |

`POST /verify_token` is always mounted as well (see
[token-verification.md](../token-verification.md)).

### Macro options

| Option | Default | Meaning |
|--------|---------|---------|
| `:live` | `false` | Set `true` to mount the billing LiveView pages |
| `:scope` | `"/beeleex"` | URL scope for all mounted routes |
| `:pipe_through` | `[]` | Extra pipelines appended after `:beeleex_browser` (pages) and `:beeleex_api` (verify_token) — use this to require authentication/authorization |
| `:root_layout` | `{BeeleexWeb.Layouts, :root}` | Root layout for the `live_session`; pass your own to embed the pages in your app's chrome |

The pages run through the macro-provided `:beeleex_browser` pipeline
(`fetch_session`, `fetch_live_flash`, `protect_from_forgery`,
`put_secure_browser_headers`). Append your own auth pipeline via `:pipe_through`.

## Host requirements

1. **LiveView socket** — your endpoint must serve it (standard for any LiveView
   app):

   ```elixir
   socket "/live", Phoenix.LiveView.Socket,
     websocket: [connect_info: [session: @session_options]]
   ```

2. **Configuration** — the same server-to-server credentials used by the rest of
   `Beeleex.Api`:

   ```elixir
   config :beeleex,
     beelee_endpoint: "https://beelee.geeks.solutions/v0-1/api",
     business_unit_id: System.get_env("BEELEE_BU_ID"),
     business_unit_secure_key: System.get_env("BEELEE_BU_SECURE_KEY")
   ```

3. **Styling** — include the shipped stylesheet and (optionally) theme it by
   overriding CSS variables. No Tailwind or build step required:

   ```html
   <link rel="stylesheet" href="/beeleex/beeleex.css" />
   ```

   ```css
   .beeleex { --bx-primary: #ff6a00; --bx-radius: 4px; }
   ```

   See [theming.md](theming.md) for the full variable list and how the
   `.beeleex`-scoped semantic classes work.

## API surface used

All added to `Beeleex.Api` (see [api-reference.md](../api-reference.md)) and
declared in the `Beeleex.ApiBehaviour`:

`get_companies/1`, `get_company/1`, `create_company/1`, `update_company/2`,
`delete_company/1`, `get_unlinked_projects/1`, `link_projects/2`,
`unlink_project/2`, `get_invoices/1`, `get_invoice/1`, `get_payment_methods/1`,
`request_setup_intent/1`, `deactivate_payment_method/1`,
`reactivate_payment_method/1`, `make_default_payment_method/2`.

These request only non-sensitive fields (they deliberately omit secrets such as
`stripeSecretKey` / `secureKey` present in the Beelee schema).

## JavaScript hook (payment methods only)

Adding a card requires the `BeeleexStripeSetup` hook to be registered with your
`LiveSocket`. See [payment-methods.md](payment-methods.md#stripe-wiring-elixir-native)
for the one-time `app.js` setup. The rest of the pages need no JavaScript beyond
the standard LiveView client.

## Testing in your app

The pages are covered by `test/beeleex_web/live/companies_live_test.exs` using
`Phoenix.LiveViewTest` against a Mox mock of `Beeleex.ApiBehaviour`. To test your
own integration, set `config :beeleex, :api_module, MyApp.BeeleexApiMock` in
`config/test.exs` and define a mock with
`Mox.defmock(MyApp.BeeleexApiMock, for: Beeleex.ApiBehaviour)`.

## Local development (see the pages)

`beeleex` ships a self-contained dev harness: a minimal endpoint
(`BeeleexWeb.Endpoint`) + router (`BeeleexWeb.Router`, mounting the macro at
`/`), a JS bundle (esbuild), and a sample-data API so the pages render without a
real Beelee BU.

```bash
mix deps.get
mix esbuild.install        # one-time: downloads the esbuild binary (for the JS bundle)
mix phx.server             # http://localhost:4000 (set PORT=4010 if 4000 is taken)
```

Then open:

* `http://localhost:4000/companies` — list
* `http://localhost:4000/companies/1` — details (with invoices + payment methods)
* `http://localhost:4000/companies/1/invoices/1001` — invoice detail

By default dev uses `BeeleexWeb.Dev.SampleApi` (canned data), wired in
`config/dev.exs`. To develop against a **real Beelee BU**, remove the
`config :beeleex, :api_module, BeeleexWeb.Dev.SampleApi` line and set
`:business_unit_secure_key`, `:business_unit_id` and `:beelee_endpoint`.

The pages are styled out of the box via the shipped `/beeleex/beeleex.css`
(see [theming.md](theming.md)); only the JavaScript bundle is built (esbuild).
