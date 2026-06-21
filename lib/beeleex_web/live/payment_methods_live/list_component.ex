defmodule BeeleexWeb.PaymentMethodsLive.ListComponent do
  @moduledoc """
  Embeddable list of a company's payment methods (the LiveView port of
  `PaymentMethodMain.vue`). Supports making a method the default, deactivating
  and retrying a method, and adding a new card via a Stripe SetupIntent.

  ## Adding a card (Stripe)

  Adding a card is the one genuinely client-side flow. When the user clicks
  "Add payment method" the server calls `Beeleex.Api.request_setup_intent/1` and
  pushes a `"beeleex:init_stripe"` event carrying the `client_secret` and
  `publishable_key`. The JavaScript hook `BeeleexStripeSetup`
  (`priv/static/beeleex/beeleex_hooks.js`) loads Stripe.js, mounts a card
  element, and on confirmation calls `stripe.confirmCardSetup/2`. On success it
  pushes `"payment_method_added"` back to this component, which refreshes the
  list. See `docs/integration/payment-methods.md` for host wiring.

  ## Required assigns

    * `:id` - the component id (also used as the Stripe hook root id)
    * `:company_id` - the company whose payment methods to manage
  """
  use BeeleexWeb, :live_component

  @api Application.compile_env(:beeleex, :api_module, Beeleex.Api)

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      socket
      |> assign_new(:adding, fn -> false end)
      |> assign_new(:error, fn -> nil end)

    socket = if socket.assigns[:loaded], do: socket, else: load(socket)

    {:ok, socket}
  end

  defp load(socket) do
    filter = [%{key: "company_id", value: to_string(socket.assigns.company_id)}]

    case @api.get_payment_methods(filter: filter, size: 50) do
      {:ok, %{payment_methods: methods}} ->
        assign(socket, payment_methods: methods, loaded: true, error: nil)

      {:error, message} ->
        assign(socket, payment_methods: [], loaded: true, error: message)
    end
  end

  @impl true
  def handle_event("add_payment_method", _params, socket) do
    case @api.request_setup_intent(socket.assigns.company_id) do
      {:ok, %{client_secret: secret, publishable_key: key}} ->
        {:noreply,
         socket
         |> assign(adding: true, error: nil)
         |> push_event("beeleex:init_stripe", %{
           client_secret: secret,
           publishable_key: key,
           target: "##{socket.assigns.id}"
         })}

      {:error, message} ->
        {:noreply, assign(socket, :error, message)}
    end
  end

  def handle_event("cancel_add", _params, socket) do
    {:noreply, assign(socket, :adding, false)}
  end

  def handle_event("payment_method_added", _params, socket) do
    send(self(), {:payment_methods_updated, socket.assigns.company_id})
    {:noreply, socket |> assign(:adding, false) |> load()}
  end

  def handle_event("make_default", %{"id" => id}, socket) do
    run(socket, fn -> @api.make_default_payment_method(socket.assigns.company_id, id) end)
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    run(socket, fn -> @api.deactivate_payment_method(id) end)
  end

  def handle_event("reactivate", %{"id" => id}, socket) do
    run(socket, fn -> @api.reactivate_payment_method(id) end)
  end

  defp run(socket, fun) do
    case fun.() do
      {:ok, _} ->
        send(self(), {:payment_methods_updated, socket.assigns.company_id})
        {:noreply, load(socket)}

      {:error, message} ->
        {:noreply, assign(socket, :error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} phx-hook="BeeleexStripeSetup" class="beeleex-payment-methods">
      <.flash_alert :if={@error} kind={:error}><%= @error %></.flash_alert>

      <.table id={"#{@id}-table"} rows={@payment_methods} empty_message={gettext("No payment methods yet")}>
        <:col :let={pm} label={gettext("Card")}>
          <%= card_brand(pm) %> •••• <%= card_last4(pm) %>
        </:col>
        <:col :let={pm} label={gettext("Expires")}><%= card_expiry(pm) %></:col>
        <:col :let={pm} label={gettext("Status")}>
          <.badge tone={pm_tone(pm[:status])}><%= pm[:status] %></.badge>
        </:col>
        <:col :let={pm} label={gettext("Default")}>
          <.badge :if={pm[:default_payment_method]} tone={:success}><%= gettext("Default") %></.badge>
        </:col>
        <:action :let={pm}>
          <button
            :if={!pm[:default_payment_method]}
            type="button"
            phx-click="make_default"
            phx-value-id={pm[:id]}
            phx-target={@myself}
            class="bx-action"
          >
            <%= gettext("Make default") %>
          </button>
        </:action>
        <:action :let={pm}>
          <button
            :if={pm[:status] != "deactivated"}
            type="button"
            phx-click="deactivate"
            phx-value-id={pm[:id]}
            phx-target={@myself}
            data-confirm={gettext("Deactivate this payment method?")}
            class="bx-action bx-action--danger"
          >
            <%= gettext("Deactivate") %>
          </button>
          <button
            :if={pm[:status] == "deactivated"}
            type="button"
            phx-click="reactivate"
            phx-value-id={pm[:id]}
            phx-target={@myself}
            class="bx-action"
          >
            <%= gettext("Retry") %>
          </button>
        </:action>
      </.table>

      <button
        type="button"
        phx-click="add_payment_method"
        phx-target={@myself}
        class="bx-btn bx-btn--primary"
        style="margin-top: 0.85rem;"
      >
        <%= gettext("Add payment method") %>
      </button>

      <div :if={@adding} class="bx-modal">
        <div class="bx-modal__overlay" aria-hidden="true" phx-click="cancel_add" phx-target={@myself}></div>
        <div class="bx-modal__content" role="dialog" aria-modal="true">
          <h3 class="bx-subtitle"><%= gettext("Add a card") %></h3>
          <%!-- Stripe.js mounts its card element into this container --%>
          <div id={"#{@id}-card-element"} data-beeleex-card-element class="bx-card-element"></div>
          <p id={"#{@id}-card-errors"} data-beeleex-card-errors role="alert" class="bx-error"></p>
          <div class="bx-modal__actions">
            <.button variant="ghost" phx-click="cancel_add" phx-target={@myself}>
              <%= gettext("Cancel") %>
            </.button>
            <button type="button" id={"#{@id}-confirm-card"} data-beeleex-confirm-card class="bx-btn bx-btn--primary">
              <%= gettext("Save card") %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- card display helpers -------------------------------------------------

  defp pm_tone("active"), do: :success
  defp pm_tone("deactivated"), do: :danger
  defp pm_tone(_), do: :neutral

  defp card(pm), do: pm[:stripe_card] || %{}
  defp card_brand(pm), do: card(pm)[:brand] || pm[:type] || "card"
  defp card_last4(pm), do: card(pm)[:last4] || "????"

  defp card_expiry(pm) do
    c = card(pm)

    case {c[:exp_month], c[:exp_year]} do
      {nil, _} -> "—"
      {month, year} -> "#{month}/#{year}"
    end
  end
end
