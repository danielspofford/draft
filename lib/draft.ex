defmodule Draft do
  @moduledoc """
  Facilitates command-line execution of arbitrary EEx templates and directories.
  """

  @doc """
  Recursively explore a path copying and templating its contents to the current working directory.

  When encountering a
  - Directory - Create that directory
  - File - Copy that file
  - EEx template - Copy and execute that template

  ## Options

  `:dry` - Print out what this run would have done, instead of actually doing it.

  All other options provided will be passed along as bindings while templating EEX files.
  """
  @spec execute(Path.t()) :: :ok
  def execute(path, raw_opts \\ []) do
    root = Path.join([path, "template"])
    bindings = Keyword.drop(raw_opts, [:dry])
    opts = [dry: Keyword.get(raw_opts, :dry, false), bindings: bindings]

    case File.ls(root) do
      {:error, :enoent} ->
        Mix.raise("Missing template directory")

      _ ->
        case process_path(root, "", "", opts) do
          :ok -> Mix.shell().info("done: success")
          :error -> Mix.shell().error("done: failure")
        end
    end
  end

  @spec process_path(Path.t(), Path.t(), Path.t(), [{:dry, boolean()}]) :: :ok
  def process_path(root, path, file, opts) do
    templated_path = Path.join([path, file])
    rooted_path = Path.join([root, templated_path])

    case File.ls(rooted_path) do
      {:ok, paths} ->
        dir? =
          case rooted_path == root do
            true -> true
            false -> mkdir(templated_path, opts) == :ok
          end

        if dir? do
          paths
          |> Task.async_stream(&process_path(root, templated_path, &1, opts))
          |> Enum.reduce(:ok, fn
            {:ok, :ok}, :ok -> :ok
            _, _ -> :error
          end)
        else
          :error
        end

      {:error, :enotdir} ->
        rooted_path
        |> Path.extname()
        |> cp(rooted_path, templated_path, opts)
    end
  end

  defp mkdir(dir, opts) do
    with false <- Keyword.get(opts, :dry, false),
         :ok <- File.mkdir(dir) do
      :ok
    else
      true ->
        Mix.shell().info("Create directory: #{dir}")
        :ok

      {:error, :eexist} ->
        Mix.shell().error("Skipping directory (and contents) because it already exists: #{dir}")
        :error
    end
  end

  defp cp(extname, source, dest, opts)

  defp cp(".eex", source, dest, opts) do
    trimmed_dest = String.trim_trailing(dest, ".eex")

    case Keyword.get(opts, :dry, false) do
      true ->
        Mix.shell().info("""
        Copy and execute
          source: #{source}
          dest: #{trimmed_dest}\
        """)

        :ok

      false ->
        content = EEx.eval_file(source, Keyword.get(opts, :bindings, []))
        File.write!(trimmed_dest, content)
        :ok
    end
  end

  defp cp(_, source, dest, opts) do
    case Keyword.get(opts, :dry, false) do
      true ->
        Mix.shell().info("""
        Copy
          source: #{source}
          dest: #{dest}\
        """)

        :ok

      false ->
        File.cp!(source, dest)
        :ok
    end
  end
end
