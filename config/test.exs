import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :beeleex, BeeleexWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "jaWKVF4g81tycpRQ5m3zcu/cOHYPrsmAmYBG5tbropuQx6Wj5E2PeHmGw8jYJWLs",
  server: false

# The LiveView pages resolve their API module at compile time; point them at the
# Mox-backed mock during tests so no real Beelee calls are made.
config :beeleex, :api_module, Beeleex.ApiMock

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
