defmodule Demos.Http do
  @moduledoc "Basic HTTP listener forwarding requests to a backend cluster."

  alias Arion.ControlPlane.Helpers.{
    Cluster,
    FilterChain,
    Hcm,
    Listener,
    Route,
    RouteConfig,
    VirtualHost
  }

  def steps do
    [
      {:setup, "Demos.Http.setup()", "Start backend-a (:18081) and publish Cluster + HTTP Listener (:18080)"},
      {:switch_backend, ~s|Demos.Http.switch_backend(18082, "backend-b")|, "Start a new backend and repoint the Cluster live over xDS"}
    ]
  end

  def run do
    setup()
    Demo.get("/hello")
    switch_backend(18082, "backend-b")
    Demo.get("/hello")
  end

  def setup do
    Demo.reset()
    Demo.start_backend(18081, "backend-a")

    cluster = Cluster.static("backend", "127.0.0.1", [18081], connect_timeout: 1)

    routes =
      RouteConfig.new("demo-routes")
      |> RouteConfig.add_virtual_host(
        VirtualHost.new("all")
        |> VirtualHost.add_route(
          Route.new() |> Route.match_prefix("/") |> Route.to_cluster("backend")
        )
      )

    hcm = Hcm.new(codec_type: :HTTP1) |> Hcm.route_config(routes)

    listener =
      Listener.new("http", Listener.local_address(18080))
      |> Listener.add_filter_chain(FilterChain.new("http") |> FilterChain.add_hcm(hcm))

    Demo.apply!(cluster: cluster, listener: listener)

    Demo.hint([
      ~s|Demo.get("/hello") # or: curl http://localhost:18080/hello|,
      "Demo.show(:http, :switch_backend)",
      ~s|Demos.Http.switch_backend(18082, "backend-b")|
    ])
  end

  def switch_backend(port \\ 18082, name \\ "backend-b") do
    Demo.start_backend(port, name)

    # Replacing only the Cluster keeps the Listener running with zero downtime.
    cluster = Cluster.static("backend", "127.0.0.1", [port], connect_timeout: 1)
    Demo.apply!(cluster: cluster)

    Demo.hint([
      ~s|Demo.get("/hello") # now answered by #{name}|,
      ~s|Demos.Http.switch_backend(18083, "backend-c")|,
      "Demo.open(:routing)"
    ])
  end
end
