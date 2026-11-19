defmodule Demos.LoadBalancing do
  @moduledoc "Multiple endpoints, balancing policies, and weighted cluster traffic splits."

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
      {:round_robin, "Demos.LoadBalancing.round_robin()", "Configure one Cluster across backend-a and backend-b (ROUND_ROBIN)"},
      {:sample, "Demos.LoadBalancing.sample(6)", "Send N requests and inspect the per-backend distribution"},
      {:least_request, "Demos.LoadBalancing.least_request()", "Switch the Cluster policy live to LEAST_REQUEST"},
      {:weighted, "Demos.LoadBalancing.weighted(90, 10)", "Split traffic by weight across separate backend-a and backend-b clusters"}
    ]
  end

  def run do
    round_robin()
    sample(6)
    least_request()
    sample(4)
    weighted(90, 10)
    sample(20)
  end

  def round_robin do
    Demo.reset()
    Demo.start_backend(18081, "backend-a")
    Demo.start_backend(18082, "backend-b")

    cluster = Cluster.static("backend", "127.0.0.1", [18081, 18082], connect_timeout: 1)

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
      "Demos.LoadBalancing.sample(6)",
      "Demo.show(:load_balancing, :least_request)",
      "Demos.LoadBalancing.least_request()"
    ])
  end

  def sample(count \\ 10) when is_integer(count) and count > 0 do
    counts =
      1..count
      |> Enum.map(fn _ ->
        %{status: 200, body: body} = Demo.get("/", quiet: true)
        Jason.decode!(body)["backend"]
      end)
      |> Enum.frequencies()

    summary = counts |> Enum.sort() |> Enum.map_join(", ", fn {b, n} -> "#{b}: #{n}" end)
    IO.puts("  Distribution (#{count} requests) → #{summary}")
    counts
  end

  def least_request do
    cluster =
      Cluster.static("backend", "127.0.0.1", [18081, 18082], connect_timeout: 1)
      |> Cluster.lb(:least_request)

    Demo.apply!(cluster: cluster)

    Demo.hint([
      "Demos.LoadBalancing.sample(6)",
      "Demo.show(:load_balancing, :weighted)",
      "Demos.LoadBalancing.weighted(90, 10)"
    ])
  end

  def weighted(weight_a \\ 90, weight_b \\ 10) do
    cluster_a = Cluster.static("backend-a", "127.0.0.1", [18081], connect_timeout: 1)
    cluster_b = Cluster.static("backend-b", "127.0.0.1", [18082], connect_timeout: 1)

    routes =
      RouteConfig.new("demo-routes")
      |> RouteConfig.add_virtual_host(
        VirtualHost.new("all")
        |> VirtualHost.add_route(
          Route.new()
          |> Route.match_prefix("/")
          |> Route.to_weighted_clusters([{"backend-a", weight_a}, {"backend-b", weight_b}])
        )
      )

    hcm = Hcm.new(codec_type: :HTTP1) |> Hcm.route_config(routes)

    listener =
      Listener.new("http", Listener.local_address(18080))
      |> Listener.add_filter_chain(FilterChain.new("http") |> FilterChain.add_hcm(hcm))

    Demo.apply!(cluster: cluster_a, cluster: cluster_b, listener: listener)

    Demo.hint([
      "Demos.LoadBalancing.sample(20)",
      "Demos.LoadBalancing.weighted(50, 50)   # try an even split"
    ])
  end
end
