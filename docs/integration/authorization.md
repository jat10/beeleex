# Authorizing the billing components

The Beeleex LiveView pages (companies, invoices, payment methods) talk to the
Beelee GraphQL API on the server. There are **two** auth modes — pick the right
one and the "Unauthorized request." errors go away.

## Two auth modes

| Mode | Headers | Used by | Acts as |
|------|---------|---------|---------|
| **Server-to-server** | `secure-key` + `bu-id` | `update_invoices`, `generate_credit_note`, webhooks, cron-style calls | the Business Unit itself |
| **User-facing UI** | `bu-authorization` + `bu-id` | the billing LiveViews (`get_companies`, `get_invoices`, `get_payment_methods`, …) | the signed-in end user |

The billing pages use the **user-facing** mode: every call carries the signed-in
user's token as `bu-authorization`, so Beelee authorizes the action as that user.
The token never reaches the browser — it is read server-side from the LiveView
session.

```
bu-authorization: <user token>
bu-id: <business unit id>
```

## What the host app must do

### 1. Configure the BU id (and server-to-server key, if you use those calls)

```elixir
# config/<env>.exs
config :beeleex,
  business_unit_id: 8,                               # integer or string, both fine
  business_unit_secure_key: System.get_env("BEELEE_BU_SECURE_KEY")  # server-to-server only
```

> `bu-id` is always coerced to a string before it is sent — HTTPoison/hackney
> would otherwise send an integer as a raw byte, which Beelee rejects.

### 2. Put the user's token in the session

The user-facing calls need a per-user token in the **Plug session**. Store it at
login under whatever key your app already uses for auth:

```elixir
conn |> put_session("portal_user_token", token)   # e.g. in your login controller
```

### 3. Point Beeleex at that session key

```elixir
# config/config.exs
config :beeleex, :bu_token_session_key, "portal_user_token"   # default: "bu_token"
```

Beeleex reads the **name** from this config and the **value** from the LiveView
session passed to `mount/3`:

```elixir
# lib/beeleex_web/live_session.ex
key   = Application.get_env(:beeleex, :bu_token_session_key, "bu_token")
token = session[key]            # -> sent as bu-authorization
```

### 4. Verify the token (callback)

Beelee relays the token back to your app to verify it. Implement the callback and
wire it up:

```elixir
config :beeleex,
  verify_token_action: %{module: MyApp.TokenVerifier, function: :verify_token}
```

```elixir
def verify_token(%{"token" => token, "fields" => fields}) do
  case lookup_user_by_token(token) do
    nil  -> {:error, :invalid_token}
    user -> {:ok, %{user_id: user.id, fields: resolve(fields, user), metadata: %{}}}
  end
end
```

See [token-verification.md](../token-verification.md) for the full contract.

## End-to-end flow

```
login → put_session("portal_user_token", token)
  → /billing/companies   (live_session, your auth pipeline + on_mount)
    → LiveView mount(_p, session, socket)
      → LiveSession.bu_token(session)              # reads the configured key
        → Beeleex.Api.get_companies(token, ...)
             bu-authorization: <token>
             bu-id: <business_unit_id>
          → Beelee verifies via POST /verify_token  → 200 + data
```

## Troubleshooting "Unauthorized request."

Run with `Logger` at `:debug`; `ui_headers/1` logs the outgoing headers
(token masked). Check, in order:

1. **`bu-id` empty or wrong** → set `config :beeleex, :business_unit_id`.
2. **token empty (`<empty>` / `len=0`)** → the session key is wrong or the user
   has no token. Confirm `:bu_token_session_key` matches the key your login flow
   writes, and that the page runs behind your auth pipeline.
3. **`bu-id` and token both present but still rejected** → Beelee is rejecting
   the token value itself. Confirm the BU accepts your app's user token for
   `bu-authorization`, and that your `verify_token` callback is reachable and
   returns `{:ok, ...}` for that token.
