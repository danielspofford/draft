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
      {:error, :enoent} -> Mix.raise(~S(Missing template directory))
      _ -> process_path(root, "", "", opts)
    end

    :ok
  end

  @spec process_path(Path.t(), Path.t(), Path.t(), [{:dry, boolean()}]) :: :ok
  def process_path(root, path, file, opts) do
    templated_path = Path.join([path, file])
    rooted_path = Path.join([root, templated_path])

    case File.ls(rooted_path) do
      {:ok, paths} ->
        unless rooted_path == root do
          mkdir(templated_path, opts)
        end

        paths
        |> Task.async_stream(&process_path(root, templated_path, &1, opts))
        |> Stream.run()

      {:error, :enotdir} ->
        rooted_path
        |> Path.extname()
        |> cp(rooted_path, templated_path, opts)
    end
  end

  defp mkdir(dir, opts) do
    case Keyword.get(opts, :dry, false) do
      true -> IO.inspect({:mkdir, dir})
      false -> File.mkdir!(dir)
    end
  end

  defp cp(extname, source, dest, opts)

  defp cp(".eex", source, dest, opts) do
    case Keyword.get(opts, :dry, false) do
      true ->
        IO.inspect({:cp_and_execute_template, {source, dest}})

      false ->
        content = EEx.eval_file(source, Keyword.get(opts, :bindings, []))

        dest
        |> String.trim_trailing(".eex")
        |> File.write!(content)
    end
  end

  defp cp(_, source, dest, opts) do
    case Keyword.get(opts, :dry, false) do
      true -> IO.inspect({:cp, {source, dest}})
      false -> File.cp!(source, dest)
    end
  end
end
