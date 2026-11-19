defmodule Demos.Tls do
  @moduledoc "HTTPS termination using a certificate delivered through an xDS Secret."

  alias Arion.ControlPlane.Helpers.{
    Cluster,
    FilterChain,
    Hcm,
    Listener,
    Route,
    RouteConfig,
    Secret,
    Tls,
    VirtualHost
  }

  def steps do
    [
      {:publish_secret, "Demos.Tls.publish_secret()", "Generate a self-signed cert and publish xDS Secret \"demo-cert\""},
      {:publish_listener, "Demos.Tls.publish_listener()", "Publish HTTPS Listener on :18443 referencing demo-cert via SDS"},
      {:rotate_secret, "Demos.Tls.rotate_secret()", "Rotate the TLS certificate live over SDS without touching the Listener"}
    ]
  end

  def run do
    publish_secret()
    publish_listener()
    Demo.get("/hello", tls: true)
    rotate_secret()
    Demo.get("/hello", tls: true)
  end

  def publish_secret do
    Demo.reset()
    Demo.start_backend(18081, "backend-a")

    secret = build_secret()
    cluster = Cluster.static("backend", "127.0.0.1", [18081], connect_timeout: 1)

    Demo.apply!(secret: secret, cluster: cluster)

    Demo.hint([
      "Demo.show(:tls, :publish_listener)",
      "Demos.Tls.publish_listener()"
    ])
  end

  def publish_listener do
    routes =
      RouteConfig.new("demo-routes")
      |> RouteConfig.add_virtual_host(
        VirtualHost.new("all")
        |> VirtualHost.add_route(
          Route.new() |> Route.match_prefix("/") |> Route.to_cluster("backend")
        )
      )

    hcm = Hcm.new(codec_type: :HTTP1) |> Hcm.route_config(routes)

    chain =
      FilterChain.new("https")
      |> FilterChain.add_hcm(hcm)
      |> FilterChain.put_transport_socket(Tls.downstream_sds_certificate("demo-cert"))

    listener =
      Listener.new("https", Listener.local_address(18443))
      |> Listener.add_filter_chain(chain)

    Demo.apply!(listener: listener)

    cert_path = Demo.tls_cert_path()

    Demo.hint([
      ~s|Demo.get("/hello", tls: true)|,
      "curl --cacert #{cert_path} https://localhost:18443/hello",
      "Demos.Tls.rotate_secret()   # rotate the certificate live over SDS"
    ])
  end

  def rotate_secret do
    Demo.apply!(secret: build_secret())

    Demo.hint([
      ~s|Demo.get("/hello", tls: true)   # verified against the newly rotated cert|
    ])
  end

  defp build_secret do
    %{cert: cert, key: key} = Demo.gen_tls_cert()

    tls_cert =
      Tls.certificate(
        Secret.data_source(:inline_string, cert),
        Secret.data_source(:inline_string, key)
      )

    Secret.tls_certificate("demo-cert", tls_cert)
  end
end
