defmodule Demo.Runner do
  @moduledoc false

  alias Demo.{State, UI}

  @demos [
    {:http, "demos/http/demo.exs", Demos.Http},
    {:routing, "demos/routing/demo.exs", Demos.Routing},
    {:tls, "demos/tls/demo.exs", Demos.Tls},
    {:load_balancing, "demos/load-balancing/demo.exs", Demos.LoadBalancing},
    {:rbac, "demos/rbac/demo.exs", Demos.Rbac},
    {:mcp, "demos/mcp/demo.exs", Demos.Mcp},
    {:traffic, "demos/traffic/demo.exs", Demos.Traffic},
    {:access_logs, "demos/access-logs/demo.exs", Demos.AccessLogs}
  ]

  def load_all do
    State.ensure()
    Code.compiler_options(ignore_module_conflict: true)
    for {_id, path, _mod} <- @demos, File.exists?(path), do: Code.compile_file(path)
    :ok
  end

  def list do
    UI.puts(["\n", :bright, "Available demos:\n"])

    for {id, path, _mod} <- @demos do
      UI.puts(["  ", UI.col(:cyan, ":#{id}", 16), " ", UI.summary(path)])
    end

    UI.puts([
      "\nOpen a guide with ",
      :cyan,
      "Demo.open(:mcp)",
      :reset,
      " or run unattended with ",
      :cyan,
      "Demo.run(:mcp)",
      :reset,
      ".\n"
    ])
  end

  def open(demo_id) do
    {id, path, mod, steps} = load_demo!(demo_id)
    State.put(:current, id)

    UI.puts([
      "\n",
      :bright,
      ":#{id}",
      :reset,
      :faint,
      " · #{inspect(mod)}\n",
      :reset,
      UI.summary(path),
      "\n"
    ])

    steps
    |> Enum.with_index(1)
    |> Enum.each(fn {{_fn_name, call, desc}, idx} ->
      UI.puts(["  ", :yellow, "#{idx}. ", :reset, desc])
      UI.puts(["     ", :cyan, call, "\n"])
    end)

    [{first_fn, first_call, _} | _] = steps
    show_cmd = "Demo.show(:#{id}, :#{first_fn})"
    w = max(String.length(show_cmd), 20) + 3

    UI.puts([
      :faint,
      "Helpers:\n",
      :reset,
      "  ",
      UI.col(:cyan, show_cmd, w),
      :faint,
      "read a step's source\n",
      :reset,
      "  ",
      UI.col(:cyan, "Demo.hint()", w),
      :faint,
      "re-show the current nudge\n",
      :reset,
      "  ",
      UI.col(:cyan, "Demo.run(:#{id})", w),
      :faint,
      "run all steps unattended"
    ])

    UI.hint([
      "#{show_cmd} # optional: inspect source",
      first_call
    ])
  end

  def show(target) when is_atom(target) do
    case find_demo(target) do
      {_id, path, _mod} -> UI.show_file(path)
      nil -> show(current_demo_id!(:show, target), target)
    end
  end

  def show(demo_id, fn_name) when is_atom(fn_name) do
    {_id, path, _mod} = resolve_demo!(demo_id)
    UI.show_function(path, fn_name)
  end

  def reload do
    case State.get(:current) do
      nil -> load_all()
      id -> reload(id)
    end
  end

  def reload(demo_id) do
    {id, path, _mod} = resolve_demo!(demo_id)
    Code.compiler_options(ignore_module_conflict: true)
    Code.compile_file(path)
    UI.puts([:green, "✓ Reloaded #{path} (:#{id})"])
  end

  def run(demo_id) do
    {id, _path, mod, _steps} = load_demo!(demo_id)
    State.put(:current, id)
    State.put(:running?, true)

    UI.puts(["\n", :bright, "Running :#{id} (#{inspect(mod)}.run/0)"])

    try do
      mod.run()
      UI.puts(["\n", :green, "✓ Completed :#{id}."])
      if State.get(:last_hint), do: UI.hint()
      :ok
    after
      State.put(:running?, false)
    end
  end

  def run_all, do: Enum.each(@demos, fn {id, _path, _mod} -> run(id) end)

  defp load_demo!(demo_id) do
    {id, path, mod} = resolve_demo!(demo_id)
    unless Code.ensure_loaded?(mod), do: Code.compile_file(path)
    {id, path, mod, mod.steps()}
  end

  defp find_demo(id),
    do: Enum.find(@demos, fn {demo_id, _, mod} -> demo_id == id or mod == id end)

  defp resolve_demo!(id) when is_atom(id) do
    find_demo(id) ||
      raise(ArgumentError, "Unknown demo #{inspect(id)}. Run Demo.list() to see available demos.")
  end

  defp current_demo_id!(action, target) do
    case State.get(:current) do
      nil ->
        raise ArgumentError,
              "No demo open. Pass Demo.#{action}(:demo_name, :#{target}) or call Demo.open/1 first."

      id ->
        id
    end
  end
end
