defmodule Beeleex.ApiBehaviour do
  @moduledoc """
  Behaviour for the subset of `Beeleex.Api` used by the LiveView pages.

  The LiveViews resolve their API module via
  `Application.compile_env(:beeleex, :api_module, Beeleex.Api)`, which lets tests
  inject a mock implementing this behaviour (see `Beeleex.ApiMock` in the test
  suite).
  """

  alias Beeleex.Company
  alias Beeleex.Invoice

  @callback get_companies(keyword) ::
              {:ok, %{companies: list(Company.t()), total: integer, count: integer}}
              | {:error, String.t()}
  @callback get_company(integer | String.t()) :: {:ok, Company.t()} | {:error, String.t()}
  @callback create_company(map) :: {:ok, Company.t()} | {:error, String.t()}
  @callback update_company(integer | String.t(), map) :: {:ok, Company.t()} | {:error, String.t()}
  @callback delete_company(integer | String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback get_unlinked_projects(list(String.t())) ::
              {:ok, list(String.t())} | {:error, String.t()}
  @callback link_projects(integer | String.t(), list) :: {:ok, Company.t()} | {:error, String.t()}
  @callback unlink_project(integer | String.t(), any) ::
              {:ok, Company.t()} | {:error, String.t()}

  @callback get_invoices(keyword) ::
              {:ok, %{invoices: list(Invoice.t()), total: integer, count: integer}}
              | {:error, String.t()}
  @callback get_invoice(integer | String.t()) :: {:ok, Invoice.t()} | {:error, String.t()}

  @callback get_payment_methods(keyword) ::
              {:ok, %{payment_methods: list(map), total: integer, count: integer}}
              | {:error, String.t()}
  @callback request_setup_intent(integer | String.t()) ::
              {:ok, %{client_secret: String.t(), publishable_key: String.t(), verified: boolean}}
              | {:error, String.t()}
  @callback deactivate_payment_method(integer | String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
  @callback reactivate_payment_method(integer | String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
  @callback make_default_payment_method(integer | String.t(), integer | String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
end
