defmodule BeeleexWeb.CompaniesLive.Show do
  @moduledoc """
  Shows a single company and supports create / edit / delete plus customer
  project linking/unlinking (the LiveView port of the Vue `CompanyDetails.vue`
  screen). Invoices and payment methods are rendered as placeholders here and
  will be filled in by later phases.
  """
  use BeeleexWeb, :live_view

  alias BeeleexWeb.CompaniesLive.FormComponent

  @api Application.compile_env(:beeleex, :api_module, Beeleex.Api)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, companies_path: "/companies", company: nil, unlinked_projects: [])}
  end

  @impl true
  def handle_params(params, uri, socket) do
    socket = assign(socket, :companies_path, companies_base(uri))
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New company"))
    |> assign(:company, %Beeleex.Company{})
  end

  defp apply_action(socket, action, %{"id" => id}) when action in [:show, :edit] do
    case @api.get_company(id) do
      {:ok, company} ->
        socket
        |> assign(:page_title, company.name || gettext("Company"))
        |> assign(:company, company)

      {:error, message} ->
        socket
        |> put_flash(:error, message)
        |> push_navigate(to: socket.assigns.companies_path)
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case @api.delete_company(socket.assigns.company.id) do
      {:ok, _message} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Company deleted"))
         |> push_navigate(to: socket.assigns.companies_path)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("unlink_project", %{"project" => project_id}, socket) do
    case @api.unlink_project(socket.assigns.company.id, project_id) do
      {:ok, company} ->
        {:noreply,
         socket
         |> assign(:company, company)
         |> put_flash(:info, gettext("Project unlinked"))}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("link_project", %{"project" => project_id}, socket) do
    case @api.link_projects(socket.assigns.company.id, [project_id]) do
      {:ok, company} ->
        {:noreply,
         socket
         |> assign(:company, company)
         |> put_flash(:info, gettext("Project linked"))}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_info({:saved, company}, socket) do
    {:noreply, push_navigate(socket, to: socket.assigns.companies_path <> "/#{company.id}")}
  end

  # Payment methods changed: refresh the company so the counts stay in sync.
  def handle_info({:payment_methods_updated, _company_id}, socket) do
    case @api.get_company(socket.assigns.company.id) do
      {:ok, company} -> {:noreply, assign(socket, :company, company)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def render(%{live_action: action} = assigns) when action in [:new, :edit] do
    ~H"""
    <div class="bx-page">
      <.link navigate={@companies_path} class="bx-back"><%= gettext("← Back") %></.link>
      <h1 class="bx-title">
        <%= if @live_action == :new, do: gettext("New company"), else: gettext("Edit company") %>
      </h1>
      <div class="bx-card">
        <.live_component
          module={FormComponent}
          id={@company.id || :new}
          action={@live_action}
          company={@company}
          return_to={@companies_path}
        />
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="bx-page">
      <.link navigate={@companies_path} class="bx-back"><%= gettext("← Back to companies") %></.link>

      <div class="bx-header">
        <h1 class="bx-title"><%= @company.name %></h1>
        <div class="bx-toolbar">
          <.link navigate={@companies_path <> "/#{@company.id}/edit"} class="bx-btn bx-btn--ghost">
            <%= gettext("Edit") %>
          </.link>
          <.button variant="danger" phx-click={show_modal("delete-modal")}>
            <%= gettext("Delete") %>
          </.button>
        </div>
      </div>

      <section class="bx-card">
        <dl class="bx-dl">
          <dt><%= gettext("Email") %></dt>
          <dd><%= @company.email %></dd>
          <dt><%= gettext("Phone") %></dt>
          <dd><%= @company.phone_number %></dd>
          <dt><%= gettext("VAT number") %></dt>
          <dd><%= @company.vat_number %></dd>
          <dt><%= gettext("Registration number") %></dt>
          <dd><%= @company.registration_number %></dd>
          <dt><%= gettext("Solvency") %></dt>
          <dd><%= @company.solvency_status %></dd>
        </dl>
      </section>

      <section class="bx-section">
        <h2 class="bx-subtitle"><%= gettext("Linked projects") %></h2>
        <ul class="bx-list">
          <li :for={project <- @company.customer_projects || []} class="bx-list__item">
            <span><%= project %></span>
            <button
              type="button"
              phx-click="unlink_project"
              phx-value-project={project}
              data-confirm={gettext("Unlink this project?")}
              class="bx-action bx-action--danger"
            >
              <%= gettext("Unlink") %>
            </button>
          </li>
          <li :if={(@company.customer_projects || []) == []} class="bx-muted">
            <%= gettext("No projects linked") %>
          </li>
        </ul>
      </section>

      <section class="bx-section">
        <h2 class="bx-subtitle"><%= gettext("Invoices") %></h2>
        <.live_component
          module={BeeleexWeb.InvoicesLive.ListComponent}
          id={"company-#{@company.id}-invoices"}
          company_id={@company.id}
          companies_path={@companies_path}
        />
      </section>

      <section class="bx-section">
        <h2 class="bx-subtitle"><%= gettext("Payment methods") %></h2>
        <.live_component
          module={BeeleexWeb.PaymentMethodsLive.ListComponent}
          id={"company-#{@company.id}-payment-methods"}
          company_id={@company.id}
        />
      </section>

      <.modal id="delete-modal">
        <h3 class="bx-subtitle"><%= gettext("Delete company") %></h3>
        <p><%= gettext("This action cannot be undone. Continue?") %></p>
        <div class="bx-modal__actions">
          <.button variant="ghost" phx-click={hide_modal("delete-modal")}>
            <%= gettext("Cancel") %>
          </.button>
          <.button variant="danger" phx-click="delete">
            <%= gettext("Delete") %>
          </.button>
        </div>
      </.modal>
    </div>
    """
  end

  defp companies_base(uri) do
    %URI{path: path} = URI.parse(uri)
    [head | _] = String.split(path, "/companies")
    head <> "/companies"
  end
end
