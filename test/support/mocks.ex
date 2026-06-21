# Defines the Mox mock at compile time (test/support is on the test elixirc
# path) so the LiveViews — which resolve `Beeleex.ApiMock` via compile_env — see
# a real module with the behaviour's callbacks. Defining it here instead of in
# test_helper.exs (runtime) avoids "module is not available" compile/Dialyzer
# warnings.
Mox.defmock(Beeleex.ApiMock, for: Beeleex.ApiBehaviour)
