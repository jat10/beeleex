defmodule BeeleexWeb.InvoicesLive.ListComponent do
  @moduledoc """
  Embeddable, paginated list of a company's invoices (the LiveView port of the
  embedded `InvoicesMain.vue` screen). Rendered inside the company details page.

  Pagination is event-driven (within the component) rather than URL-driven, so
  it can be dropped into any parent LiveView.

  ## Required assigns

    * `:id` - the component id
    * `:company_id` - the company whose invoices to list
    * `:companies_path` - base path used to build invoice detail links
  """
  use BeeleexWeb, :live_component

  @api Application.compile_env(:beeleex, :api_module, Beeleex.Api)
  @page_size 10

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns[:loaded] do
        socket
      else
        load(socket, 1)
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    {:noreply, load(socket, String.to_integer(page))}
  end

  defp load(socket, page) do
    skip = (page - 1) * @page_size
    filter = [%{key: "company_id", value: to_string(socket.assigns.company_id)}]

    case @api.get_invoices(filter: filter, size: @page_size, skip: skip) do
      {:ok, %{invoices: invoices, total: total}} ->
        socket
        |> assign(invoices: invoices, total: total, page: page, size: @page_size, loaded: true)
        |> assign(error: nil)

      {:error, message} ->
        assign(socket,
          invoices: [],
          total: 0,
          page: page,
          size: @page_size,
          loaded: true,
          error: message
        )
    end
  end

  defp invoice_tone("paid"), do: :success
  defp invoice_tone("pending"), do: :warning
  defp invoice_tone(status) when status in ["failed", "unpaid"], do: :danger
  defp invoice_tone(_), do: :neutral

  @impl true
  def render(assigns) do
    page_count = max(1, ceil(assigns.total / assigns.size))
    assigns = assign(assigns, :page_count, page_count)

    ~H"""
    <div class="beeleex-invoices">
      <.flash_alert :if={@error} kind={:error}><%= @error %></.flash_alert>

      <.table id={"#{@id}-table"} rows={@invoices} empty_message={gettext("No invoices yet")}>
        <:col :let={invoice} label={gettext("Type")}><%= invoice.type %></:col>
        <:col :let={invoice} label={gettext("Status")}>
          <.badge tone={invoice_tone(invoice.status)}><%= invoice.status %></.badge>
        </:col>
        <:col :let={invoice} label={gettext("Cycle")}><%= invoice.cycle %></:col>
        <:col :let={invoice} label={gettext("Amount")}>
          <%= format_amount(invoice.amount_with_tax, invoice.decimal_places) %>
        </:col>
        <:action :let={invoice}>
          <.link
            navigate={@companies_path <> "/#{@company_id}/invoices/#{invoice.id}"}
            class="bx-action"
          >
            <%= gettext("View") %>
          </.link>
        </:action>
      </.table>

      <nav :if={@page_count > 1} class="bx-pagination">
        <button
          :if={@page > 1}
          type="button"
          phx-click="page"
          phx-value-page={@page - 1}
          phx-target={@myself}
          class="bx-btn bx-btn--ghost"
        >
          <%= gettext("Previous") %>
        </button>
        <span class="bx-pagination__info">
          <%= gettext("Page %{page} of %{count}", page: @page, count: @page_count) %>
        </span>
        <button
          :if={@page < @page_count}
          type="button"
          phx-click="page"
          phx-value-page={@page + 1}
          phx-target={@myself}
          class="bx-btn bx-btn--ghost"
        >
          <%= gettext("Next") %>
        </button>
      </nav>
    </div>
    """
  end
end
