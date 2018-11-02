defmodule Draft do
  @moduledoc """
  Facilitates command-line execution of arbitrary EEx templates and directories.
  """

  @spec execute(Path.t()) :: :ok
  def execute(path, opts \\ []) do
    root = Path.join([path, "template"])

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

  defp cp("eex", source, dest, opts) do
    case Keyword.get(opts, :dry, false) do
      true ->
        IO.inspect({:cp_and_execute_template, {source, dest}})

      false ->
        content = EEx.eval_file(source, app_name: Keyword.fetch!(opts, :app_name))
        File.write!(dest, content)
    end
  end

  defp cp(_, source, dest, opts) do
    case Keyword.get(opts, :dry, false) do
      true -> IO.inspect({:cp, {source, dest}})
      false -> File.cp!(source, dest)
    end
  end
end
