defmodule Demo.State do
  @moduledoc false

  @initial %{
    current: nil,
    last_hint: nil,
    running?: false,
    backends: %{},
    tls_cert_path: nil,
    flaky: %{}
  }

  def ensure do
    case Agent.start(fn -> @initial end, name: __MODULE__) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  def get(key) do
    ensure()
    Agent.get(__MODULE__, &Map.fetch!(&1, key))
  end

  def put(key, value) do
    ensure()
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  def update(key, fun) do
    ensure()
    Agent.update(__MODULE__, &Map.update!(&1, key, fun))
  end

  def next_attempt(path) do
    ensure()

    Agent.get_and_update(__MODULE__, fn state ->
      attempt = Map.get(state.flaky, path, 0) + 1
      {attempt, put_in(state.flaky[path], attempt)}
    end)
  end
end
