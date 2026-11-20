defmodule Demos.Traffic do
  @moduledoc "Retries on 5xx responses and per-route request timeouts."

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
      {:setup, "Demos.Traffic.setup()", "Configure /flaky (5xx retries) and /slow (100ms timeout)"},
      {:set_slow_timeout, "Demos.Traffic.set_slow_timeout(2_000)", "Update the /slow timeout (in ms) live over RDS"}
    ]
  end

  def run do
    setup()
    Demo.get("/flaky?run=first")
    Demo.get("/slow")
    set_slow_timeout(2_000)
    Demo.get("/slow")
  end

  def setup do
    Demo.reset()
    Demo.start_backend(18081, "backend-a")

    cluster = Cluster.static("backend", "127.0.0.1", [18081], connect_timeout: 1)
    hcm = Hcm.new(codec_type: :HTTP1) |> Demo.rds("demo-routes")

    listener =
      Listener.new("http", Listener.local_address(18080))
      |> Listener.add_filter_chain(FilterChain.new("http") |> FilterChain.add_hcm(hcm))

    Demo.apply!(
      cluster: cluster,
      route: traffic_routes(duration_ms(100)),
      listener: listener
    )

    Demo.hint([
      ~s|Demo.get("/flaky?example=1") # 200 on attempt 2|,
      ~s|Demo.get("/slow") # 504 after 100ms|,
      "Demos.Traffic.set_slow_timeout(2_000)"
    ])
  end

  def set_slow_timeout(timeout_ms \\ 2_000) when is_integer(timeout_ms) and timeout_ms > 0 do
    Demo.apply!(route: traffic_routes(duration_ms(timeout_ms)))

    Demo.hint([
      ~s|Demo.get("/slow") # timeout now #{timeout_ms}ms|,
      "Demos.Traffic.set_slow_timeout(100)"
    ])
  end

  defp duration_ms(ms) do
    %Google.Protobuf.Duration{
      seconds: div(ms, 1_000),
      nanos: rem(ms, 1_000) * 1_000_000
    }
  end

  defp traffic_routes(slow_timeout) do
    flaky =
      Route.new("flaky")
      |> Route.match_prefix("/flaky")
      |> Route.to_cluster("backend")
      |> Route.timeout(3)
      |> Route.retry(Route.retry_policy("5xx", num_retries: 2, per_try_timeout: 1))

    slow =
      Route.new("slow")
      |> Route.match_prefix("/slow")
      |> Route.to_cluster("backend")
      |> Route.timeout(slow_timeout)

    default =
      Route.new("default")
      |> Route.match_prefix("/")
      |> Route.to_cluster("backend")

    vh =
      VirtualHost.new("all")
      |> VirtualHost.add_route(flaky)
      |> VirtualHost.add_route(slow)
      |> VirtualHost.add_route(default)

    RouteConfig.new("demo-routes") |> RouteConfig.add_virtual_host(vh)
  end
end
