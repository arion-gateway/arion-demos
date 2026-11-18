defmodule Demo.UI do
  @moduledoc false

  alias Demo.State

  def puts(iodata), do: iodata |> IO.ANSI.format() |> IO.puts()
  def col(color, text, width), do: [color, String.pad_trailing(to_string(text), width), :reset]

  def banner do
    puts([
      "\n",
      :bright,
      "Arion Interactive Demos\n",
      :reset,
      "  ",
      col(:cyan, "Demo.list()", 26),
      "list available demos\n",
      "  ",
      col(:cyan, "Demo.open(:mcp)", 26),
      "open guided steps for a demo\n",
      "  ",
      col(:cyan, "Demo.show(:mcp, :setup)", 26),
      "read a step's source code\n",
      "  ",
      col(:cyan, "Demo.hint()", 26),
      "re-show the next-step nudge\n",
      "  ",
      col(:cyan, "Demo.run(:mcp)", 26),
      "run a full demo unattended"
    ])
  end

  def hint do
    case State.get(:last_hint) do
      nil ->
        puts([
          "No active hint yet. Try ",
          :cyan,
          "Demo.list()",
          :reset,
          " or ",
          :cyan,
          "Demo.open(:http)",
          :reset,
          "."
        ])

      lines ->
        print_hint(lines)
    end
  end

  def hint(line) when is_binary(line), do: hint([line])

  def hint(lines) when is_list(lines) do
    State.put(:last_hint, lines)
    unless State.get(:running?), do: print_hint(lines)
    :ok
  end

  def summary(path) do
    with {:ok, content} <- File.read(path),
         [_, doc] <- Regex.run(~r/@moduledoc\s+"([^"]+)"/, content) do
      doc
    else
      _ -> ""
    end
  end

  def show_file(path) do
    puts(["\n", :faint, "Source (#{path}):"])
    path |> File.read!() |> String.split("\n") |> print_lines(1)
  end

  def show_function(path, fn_name) do
    lines = path |> File.read!() |> String.split("\n")

    case def_range(lines, Atom.to_string(fn_name)) do
      {first, last} ->
        puts(["\n", :faint, "Source (#{path}:#{first}-#{last}):"])
        lines |> Enum.slice((first - 1)..(last - 1)) |> print_lines(first)

      nil ->
        puts([:faint, "(source for #{fn_name} not found in #{path})"])
    end
  end

  defp print_hint(lines) do
    puts(["\n", :bright, "Next →"])

    Enum.each(lines, fn line ->
      case String.split(line, " # ", parts: 2) do
        [cmd, note] -> puts(["  ", :cyan, String.trim_trailing(cmd), :reset, :faint, "  # ", note])
        [cmd] -> puts(["  ", :cyan, cmd])
      end
    end)

    IO.puts("")
  end

  defp print_lines(lines, start_line) do
    lines
    |> Enum.with_index(start_line)
    |> Enum.each(fn {line, n} ->
      puts(["  ", :faint, String.pad_leading(Integer.to_string(n), 3), " │", :reset, " ", line])
    end)
  end

  defp def_range(lines, name) do
    pattern = ~r/^(\s*)def\s+#{Regex.escape(name)}(?:\s|\(|$)/

    with start_idx when is_integer(start_idx) <- Enum.find_index(lines, &Regex.match?(pattern, &1)) do
      line = Enum.at(lines, start_idx)
      [_, indent] = Regex.run(pattern, line)

      if String.contains?(line, ", do:") do
        {start_idx + 1, start_idx + 1}
      else
        find_end(lines, start_idx, ~r/^#{indent}end\s*$/)
      end
    end
  end

  defp find_end(lines, start_idx, end_pattern) do
    lines
    |> Enum.with_index()
    |> Enum.drop(start_idx + 1)
    |> Enum.find_value(fn {line, idx} ->
      if Regex.match?(end_pattern, line), do: {start_idx + 1, idx + 1}
    end)
  end
end
