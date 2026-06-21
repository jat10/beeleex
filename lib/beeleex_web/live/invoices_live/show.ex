defmodule BeeleexWeb.InvoicesLive.Show do
  @moduledoc """
  Read-only view of a single invoice (the LiveView port of `InvoiceDetails.vue`).
  """
  use BeeleexWeb, :live_view

  @api Application.compile_env(:beeleex, :api_module, Beeleex.Api)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, company_path: "/companies", invoice: nil)}
  end

  @impl true
  def handle_params(%{"id" => company_id, "invoice_id" => invoice_id}, uri, socket) do
    company_path = companies_base(uri) <> "/#{company_id}"

    case @api.get_invoice(invoice_id) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> assign(:page_title, gettext("Invoice #%{id}", id: invoice.id))
         |> assign(:company_path, company_path)
         |> assign(:invoice, invoice)}

      {:error, message} ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> push_navigate(to: company_path)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bx-page">
      <.link navigate={@company_path} class="bx-back"><%= gettext("← Back to company") %></.link>

      <h1 class="bx-title">
        <%= gettext("Invoice #%{id}", id: @invoice.id) %>
      </h1>

      <section class="bx-card">
        <dl class="bx-dl">
          <dt><%= gettext("Type") %></dt>
          <dd><%= @invoice.type %></dd>
          <dt><%= gettext("Status") %></dt>
          <dd><%= @invoice.status %></dd>
          <dt><%= gettext("Cycle") %></dt>
          <dd><%= @invoice.cycle %></dd>
          <dt><%= gettext("Period") %></dt>
          <dd><%= @invoice.beginning %> → <%= @invoice.end %></dd>
          <dt><%= gettext("Amount before tax") %></dt>
          <dd><%= format_amount(@invoice.amount_before_tax, @invoice.decimal_places) %></dd>
          <dt><%= gettext("Tax") %></dt>
          <dd><%= format_amount(@invoice.tax_amount, @invoice.decimal_places) %></dd>
          <dt><%= gettext("Amount with tax") %></dt>
          <dd><%= format_amount(@invoice.amount_with_tax, @invoice.decimal_places) %></dd>
        </dl>
      </section>

      <section :if={@invoice.breakdown not in [nil, []]} class="bx-section">
        <h2 class="bx-subtitle"><%= gettext("Breakdown") %></h2>
        <.table id="invoice-breakdown" rows={@invoice.breakdown || []}>
          <:col :let={line} label={gettext("Project")}><%= line[:project_name] %></:col>
          <:col :let={line} label={gettext("Package")}><%= line[:package_name] %></:col>
          <:col :let={line} label={gettext("Price before tax")}>
            <%= format_amount(line[:package_price_before_tax], @invoice.decimal_places) %>
          </:col>
        </.table>
      </section>
    </div>
    """
  end

  defp companies_base(uri) do
    %URI{path: path} = URI.parse(uri)
    [head | _] = String.split(path, "/companies")
    head <> "/companies"
  end
end
