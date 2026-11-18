defmodule Demo.Backend do
  @moduledoc false
  @behaviour :cowboy_handler

  alias Demo.{State, UI}

  def start(port, name) when is_integer(port) and is_binary(name) do
    ref = listener_ref(port)
    :cowboy.stop_listener(ref)

    dispatch = :cowboy_router.compile([{:_, [{:_, __MODULE__, %{name: name}}]}])

    {:ok, _} =
      :cowboy.start_clear(ref, [ip: {127, 0, 0, 1}, port: port], %{env: %{dispatch: dispatch}})

    State.update(:backends, &Map.put(&1, port, name))
    UI.puts([:faint, "  → started #{name} on 127.0.0.1:#{port}"])
  end

  def stop(port) when is_integer(port) do
    :cowboy.stop_listener(listener_ref(port))
    name = State.get(:backends) |> Map.get(port, "backend")
    State.update(:backends, &Map.delete(&1, port))
    UI.puts([:faint, "  → stopped #{name} on 127.0.0.1:#{port}"])
  end

  def stop_all do
    for {port, _name} <- State.get(:backends), do: :cowboy.stop_listener(listener_ref(port))
    State.put(:backends, %{})
  end

  def list, do: State.get(:backends) |> Enum.sort()

  @impl :cowboy_handler
  def init(req, %{name: name} = state) do
    path = :cowboy_req.path(req)
    qs = :cowboy_req.qs(req)
    full_path = if qs == "", do: path, else: "#{path}?#{qs}"

    {status, extra} = route(path, qs, full_path)

    base = %{
      backend: name,
      method: :cowboy_req.method(req),
      path: path,
      headers: :cowboy_req.headers(req)
    }

    base = if qs == "", do: base, else: Map.put(base, :query, URI.decode_query(qs))

    body =
      base
      |> Map.merge(extra)
      |> Jason.encode!(pretty: true)
      |> Kernel.<>("\n")

    {:ok, :cowboy_req.reply(status, %{"content-type" => "application/json"}, body, req), state}
  end

  defp route("/slow", _qs, _full) do
    Process.sleep(1_000)
    {200, %{}}
  end

  defp route("/greet", qs, _full) do
    who = URI.decode_query(qs)["name"] || "world"
    {200, %{message: "Hello, #{who}!"}}
  end

  defp route("/flaky", _qs, full) do
    attempt = State.next_attempt(full)
    {if(rem(attempt, 2) == 1, do: 503, else: 200), %{attempt: attempt}}
  end

  defp route(_path, _qs, _full), do: {200, %{}}

  defp listener_ref(port), do: :"arion_demo_backend_#{port}"
end
