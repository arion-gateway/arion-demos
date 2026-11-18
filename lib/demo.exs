Code.compiler_options(ignore_module_conflict: true)

for file <- ~w(state ui backend control http runner) do
  Code.compile_file(Path.join([__DIR__, "demo", "#{file}.exs"]))
end

defmodule Demo do
  @moduledoc """
  Interactive demo guide and testbed utilities for Arion.

  Start here:
    Demo.list()                   list available demos
    Demo.open(:mcp)               view guided steps & commands for a demo
    Demo.show(:mcp, :setup)       read a function's source before running it
    Demo.hint()                   re-show the current next-step nudge
    Demo.run(:mcp)                run a full demo unattended
  """

  # Discovery, source inspection & unattended runner
  defdelegate load_all(), to: Demo.Runner
  defdelegate list(), to: Demo.Runner
  defdelegate open(demo), to: Demo.Runner
  defdelegate show(target), to: Demo.Runner
  defdelegate show(demo, fn_name), to: Demo.Runner
  defdelegate reload(), to: Demo.Runner
  defdelegate reload(demo), to: Demo.Runner
  defdelegate run(demo), to: Demo.Runner
  defdelegate run_all(), to: Demo.Runner

  # Terminal helpers & nudges
  defdelegate banner(), to: Demo.UI
  defdelegate hint(), to: Demo.UI
  defdelegate hint(lines), to: Demo.UI

  # Control plane & testbed plumbing
  defdelegate reset(), to: Demo.Control
  defdelegate rds(hcm, route_config_name), to: Demo.Control
  defdelegate apply!(resources, opts \\ []), to: Demo.Control
  defdelegate wait_sync(fleet \\ "arion", timeout_ms \\ 30_000), to: Demo.Control
  defdelegate gen_tls_cert(), to: Demo.Control
  defdelegate tls_cert_path(), to: Demo.Control
  defdelegate export(path \\ nil), to: Demo.Control

  # Mock HTTP backends
  defdelegate start_backend(port, name), to: Demo.Backend, as: :start
  defdelegate stop_backend(port), to: Demo.Backend, as: :stop
  defdelegate stop_all_backends(), to: Demo.Backend, as: :stop_all
  defdelegate backends(), to: Demo.Backend, as: :list

  # In-shell HTTP/HTTPS client
  defdelegate get(path, opts \\ []), to: Demo.Http
  defdelegate post(path, body, opts \\ []), to: Demo.Http
  defdelegate request(method, path, body \\ nil, opts \\ []), to: Demo.Http
end
