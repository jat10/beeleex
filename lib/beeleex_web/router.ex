defmodule Beeleex.Routes do
  @moduledoc """
  `Beeleex.Routes` mounts the routes Beeleex needs into your Phoenix router.

  ## Token verification API (always mounted)

  ```elixir
  use Beeleex.Routes, scope: "/", pipe_through: [:browser, :authenticate]
  ```

  `:scope` defaults to `"/beeleex"`.

  `:pipe_through` defaults to beeleex's `[:beeleex_api]`; the pipes you pass are
  appended, so you can customize the pipeline as you want.

  This always mounts:

  ```elixir
  post("/verify_token", BeeleexController, :verify_token, as: :beeleex)
  ```

  ## Billing LiveView pages (opt-in)

  Pass `live: true` to additionally mount the server-rendered billing pages:

  ```elixir
  use Beeleex.Routes, live: true, scope: "/billing"
  ```

  This mounts (under `:scope`):

  ```elixir
  live "/companies",          CompaniesLive.Index, :index
  live "/companies/new",      CompaniesLive.Show,  :new
  live "/companies/:id",      CompaniesLive.Show,  :show
  live "/companies/:id/edit", CompaniesLive.Show,  :edit

  live "/companies/:id/invoices/:invoice_id", InvoicesLive.Show, :show
  ```

  The pages render through the `:beeleex_browser` pipeline (plus any
  `:pipe_through` pipes you append). They fetch data server-side via
  `Beeleex.Api`, so configure `:business_unit_secure_key`, `:business_unit_id`
  and (optionally) `:beelee_endpoint` for your app.

  ### Requirements for the host app

  * Your endpoint must serve the LiveView socket:
    `socket "/live", Phoenix.LiveView.Socket, ...`.
  * Pass `root_layout:` if you want the pages wrapped in your own root layout;
    it defaults to `{BeeleexWeb.Layouts, :root}`.
  """

  defmacro __using__(options \\ []) do
    scoped = Keyword.get(options, :scope, "/beeleex")
    custom_pipes = Keyword.get(options, :pipe_through, [])
    api_pipes = [:beeleex_api] ++ custom_pipes
    browser_pipes = [:beeleex_browser] ++ custom_pipes
    live? = Keyword.get(options, :live, false)
    root_layout = Keyword.get(options, :root_layout, {BeeleexWeb.Layouts, :root})

    quote do
      import Phoenix.LiveView.Router

      pipeline :beeleex_browser do
        plug(:accepts, ["html", "json"])
        plug(:fetch_session)
        plug(:fetch_live_flash)
        plug(:protect_from_forgery)
        plug(:put_secure_browser_headers)
      end

      pipeline :beeleex_api do
        plug(:accepts, ["json"])
      end

      scope unquote(scoped), BeeleexWeb do
        pipe_through(unquote(api_pipes))

        post("/verify_token", BeeleexController, :verify_token, as: :beeleex)
      end

      if unquote(live?) do
        scope unquote(scoped), BeeleexWeb do
          pipe_through(unquote(browser_pipes))

          live_session :beeleex, root_layout: unquote(Macro.escape(root_layout)) do
            live("/companies", CompaniesLive.Index, :index)
            live("/companies/new", CompaniesLive.Show, :new)
            live("/companies/:id", CompaniesLive.Show, :show)
            live("/companies/:id/edit", CompaniesLive.Show, :edit)
            live("/companies/:id/invoices/:invoice_id", InvoicesLive.Show, :show)
          end
        end
      end
    end
  end
end
