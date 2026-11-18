defmodule Demo.Control do
  @moduledoc false

  alias Arion.ControlPlane.Pb.Data.{AggregatedConfigSource, ConfigSource}
  alias Arion.ControlPlane.Pb.Filter.{HttpConnectionManager, Rds}
  alias Arion.ControlPlane.{ResourceCache, Service}
  alias Demo.{Backend, State, UI}

  def reset do
    Backend.stop_all()
    State.put(:flaky, %{})

    case Arion.Ctl.get("arion") do
      [] ->
        :ok

      docs ->
        {:ok, _} = Arion.Ctl.delete_documents(docs)
        wait_sync()
    end

    UI.puts([:faint, "  → reset fleet \"arion\" and stopped demo backends"])
  end

  def rds(%HttpConnectionManager{} = hcm, route_config_name) do
    ads = %ConfigSource{config_source_specifier: {:ads, %AggregatedConfigSource{}}}

    %{
      hcm
      | route_specifier: {:rds, %Rds{route_config_name: route_config_name, config_source: ads}}
    }
  end

  def apply!(resources, opts \\ []) when is_list(resources) do
    fleet = Keyword.get(opts, :fleet, "arion")
    {:ok, %{resources: count}} = Arion.Ctl.apply_resources(resources, fleet: fleet)
    wait_sync(fleet)

    UI.puts([
      :green,
      "  ✓ applied (#{count} total resources in fleet \"#{fleet}\", ACKed by proxy)"
    ])
  end

  def wait_sync(fleet \\ "arion", timeout_ms \\ 30_000) do
    await_sync(fleet, System.monotonic_time(:millisecond) + timeout_ms)
  end

  def gen_tls_cert do
    openssl = System.find_executable("openssl") || raise "openssl executable not found"
    dir = if File.mkdir_p(".demo/tls") == :ok, do: ".demo/tls", else: "/tmp/arion-demo-tls"
    File.mkdir_p!(dir)

    key_path = Path.join(dir, "key.pem")
    cert_path = Path.join(dir, "cert.pem")

    args =
      ~w(req -x509 -newkey rsa:2048 -nodes -days 2 -subj /CN=localhost -addext subjectAltName=DNS:localhost,IP:127.0.0.1) ++
        ["-keyout", key_path, "-out", cert_path]

    case System.cmd(openssl, args, stderr_to_stdout: true) do
      {_out, 0} -> :ok
      {out, _} -> raise "openssl failed: #{out}"
    end

    File.chmod!(key_path, 0o600)
    File.chmod!(cert_path, 0o600)
    State.put(:tls_cert_path, cert_path)
    UI.puts([:faint, "  → generated self-signed TLS cert at #{cert_path}"])

    %{
      cert: File.read!(cert_path),
      key: File.read!(key_path),
      cert_path: cert_path,
      key_path: key_path
    }
  end

  def tls_cert_path, do: State.get(:tls_cert_path)

  def export(nil), do: Arion.Ctl.get("arion") |> Jason.encode!(pretty: true) |> IO.puts()

  def export(path) when is_binary(path) do
    docs = Arion.Ctl.get("arion")
    File.write!(path, Jason.encode!(docs, pretty: true) <> "\n")
    UI.puts([:green, "  ✓ exported #{length(docs)} resources to #{path}"])
  end

  defp await_sync(fleet, deadline) do
    case sync_status(fleet) do
      :ready ->
        :ok

      {:nack, message} ->
        raise "Proxy rejected configuration: #{message}"

      :pending ->
        if System.monotonic_time(:millisecond) >= deadline do
          raise "Timed out waiting for proxy to ACK fleet #{inspect(fleet)}. Is Arion running?"
        end

        Process.sleep(100)
        await_sync(fleet, deadline)
    end
  end

  defp sync_status(fleet) do
    expected = expected_versions(fleet)
    clients = Service.acks(fleet) |> Map.values()

    case nack_errors(clients, expected) do
      [_ | _] = errors -> {:nack, Enum.join(errors, "; ")}
      [] -> if(acked?(clients, expected), do: :ready, else: :pending)
    end
  end

  defp expected_versions(fleet) do
    Map.new(Service.resources(fleet), fn {kind, resources} ->
      {kind,
       Map.new(resources, fn {name, res} ->
         {name, {:ack, ResourceCache.entry(kind, res).wire.version}}
       end)}
    end)
  end

  defp nack_errors(clients, expected) do
    for state <- clients,
        {kind, resources} <- expected,
        {name, {:nack, version, error}} <- Map.get(state, kind, %{}),
        resources[name] == {:ack, version},
        do: "#{kind}/#{name}: #{error}"
  end

  defp acked?([], _expected), do: false

  defp acked?(clients, expected) do
    Enum.all?(clients, fn state ->
      Map.get(state, :pending, %{}) == %{} and
        Enum.all?(expected, fn {kind, versions} -> Map.get(state, kind, %{}) == versions end)
    end)
  end
end
