defmodule Demos.AccessLogs do
  @moduledoc "Custom access-log formatting written to proxy stdout."

  alias Arion.ControlPlane.Helpers.{
    AccessLog,
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
      {:setup, "Demos.AccessLogs.setup()", "Enable stdout access logging with default demo-access format"},
      {:set_format, "Demos.AccessLogs.set_format()", "Switch the access-log prefix live to my-access"}
    ]
  end

  def run do
    setup()
    Demo.get("/hello")
    set_format()
    Demo.get("/another-request")
  end

  def setup do
    Demo.reset()
    Demo.start_backend(18081, "backend-a")

    cluster = Cluster.static("backend", "127.0.0.1", [18081], connect_timeout: 1)

    Demo.apply!(
      cluster: cluster,
      listener: logged_listener("demo-access %REQ(:METHOD)% %REQ(:PATH)% %RESPONSE_CODE%\n")
    )

    Demo.hint([
      ~s|Demo.get("/hello") # check proxy stdout logs|,
      "Demos.AccessLogs.set_format()"
    ])
  end

  def set_format(format \\ "my-access %REQ(:METHOD)% %REQ(:PATH)% -> %RESPONSE_CODE%\n")
      when is_binary(format) do
    line = if String.ends_with?(format, "\n"), do: format, else: format <> "\n"
    Demo.apply!(listener: logged_listener(line))

    Demo.hint([
      ~s|Demo.get("/another-request") # check proxy stdout logs|
    ])
  end

  defp logged_listener(format) do
    routes =
      RouteConfig.new("demo-routes")
      |> RouteConfig.add_virtual_host(
        VirtualHost.new("all")
        |> VirtualHost.add_route(
          Route.new() |> Route.match_prefix("/") |> Route.to_cluster("backend")
        )
      )

    hcm =
      Hcm.new(codec_type: :HTTP1)
      |> Hcm.route_config(routes)
      |> Hcm.add_access_log(AccessLog.file("/dev/stdout", AccessLog.text_format(format)))

    Listener.new("http", Listener.local_address(18080))
    |> Listener.add_filter_chain(FilterChain.new("http") |> FilterChain.add_hcm(hcm))
  end
end
