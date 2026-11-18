defmodule Demo.Http do
  @moduledoc false

  alias Demo.{Control, UI}

  @shown_headers ["location", "x-demo-proxy", "mcp-session-id"]

  def get(path, opts \\ []), do: request("GET", path, nil, opts)
  def post(path, body, opts \\ []), do: request("POST", path, body, opts)

  def request(method, path, body \\ nil, opts \\ []) do
    tls? = Keyword.get(opts, :tls, false)
    host = Keyword.get(opts, :host, "localhost") |> String.to_charlist()
    port = Keyword.get(opts, :port, if(tls?, do: 18443, else: 18080))
    quiet? = Keyword.get(opts, :quiet, false)
    timeout = Keyword.get(opts, :timeout, 15_000)

    {encoded_body, headers} = encode_body(body, Keyword.get(opts, :headers, []))

    case :gun.open(host, port, gun_opts(tls?, opts)) do
      {:ok, pid} ->
        try do
          send_request(pid, method, path, headers, encoded_body, timeout, quiet?)
        after
          :gun.close(pid)
        end

      {:error, reason} ->
        fail(reason, quiet?)
    end
  end

  defp send_request(pid, method, path, headers, body, timeout, quiet?) do
    with {:ok, _proto} <- :gun.await_up(pid, 5_000),
         ref = :gun.request(pid, method, path, headers, body),
         {:response, fin, status, resp_headers} <- :gun.await(pid, ref, timeout),
         {:ok, resp_body} <- read_body(pid, ref, fin, timeout) do
      resp = %{status: status, headers: resp_headers, body: resp_body}
      unless quiet?, do: print_response(resp)
      resp
    else
      {:error, reason} -> fail(reason, quiet?)
      other -> fail(other, quiet?)
    end
  end

  defp read_body(_pid, _ref, :fin, _timeout), do: {:ok, ""}
  defp read_body(pid, ref, :nofin, timeout), do: :gun.await_body(pid, ref, timeout)

  defp encode_body(nil, headers), do: {"", headers}
  defp encode_body(bin, headers) when is_binary(bin), do: {bin, headers}

  defp encode_body(map, headers) when is_map(map) do
    has_ct? = Enum.any?(headers, fn {k, _} -> String.downcase(k) == "content-type" end)
    headers = if has_ct?, do: headers, else: [{"content-type", "application/json"} | headers]
    {Jason.encode!(map), headers}
  end

  defp gun_opts(false, _opts), do: %{protocols: [:http], transport: :tcp, retry: 0}

  defp gun_opts(true, opts) do
    tls_opts =
      case Keyword.get(opts, :cacert, Control.tls_cert_path()) do
        nil -> [verify: :verify_peer]
        cert_file -> pinned_tls_opts(cert_file)
      end

    %{protocols: [:http], transport: :tls, tls_opts: tls_opts, retry: 0}
  end

  defp pinned_tls_opts(cert_file) do
    ders =
      cert_file
      |> File.read!()
      |> :public_key.pem_decode()
      |> Enum.map(fn {:Certificate, der, :not_encrypted} -> der end)

    verify_fun =
      {fn
         cert, {:bad_cert, :selfsigned_peer}, trusted ->
           if :public_key.pkix_encode(:OTPCertificate, cert, :otp) in trusted,
             do: {:valid, trusted},
             else: {:fail, {:bad_cert, :selfsigned_peer}}

         _, {:extension, _}, state ->
           {:unknown, state}

         _, event, state when event in [:valid, :valid_peer] ->
           {:valid, state}

         _, reason, _ ->
           {:fail, reason}
       end, ders}

    [verify: :verify_peer, cacerts: ders, verify_fun: verify_fun]
  end

  defp print_response(%{status: status, headers: headers, body: body}) do
    UI.puts([if(status in 200..299, do: :green, else: :yellow), "HTTP #{status}"])

    for {k, v} <- headers, String.downcase(k) in @shown_headers do
      UI.puts([:faint, "  #{k}: #{v}"])
    end

    if (text = String.trim(body)) != "", do: IO.puts(text)
  end

  defp fail(reason, quiet?) do
    unless quiet?, do: UI.puts([:red, "Request error: #{inspect(reason)}"])
    {:error, reason}
  end
end
