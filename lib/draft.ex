defmodule Draft do
  @moduledoc """
  Facilitates command-line execution of arbitrary EEx templates and directories.
  """

  def execute(path) do
    root = Path.join([path, "template"])

    case File.ls(root) do
      {:error, :enoent} -> Mix.raise(~S(Missing template directory))
      _ -> process_path(root)
    end
  end

  def process_path(root, path \\ "", file \\ "") do
    templated_path = Path.join([path, file])
    rooted_path = Path.join([root, templated_path])

    case File.ls(rooted_path) do
      {:ok, paths} ->
        unless rooted_path == root do
          mkdir(rooted_path, templated_path, opts)
        end

        paths
        |> Task.async_stream(&process_path(root, templated_path, &1))
        |> Stream.run()

      {:error, :enotdir} ->
        rooted_path
        |> Path.extname()
        |> cp(rooted_path, templated_path, opts)
    end
  end

  defp mkdir(from, to, opts) do
    case Keyword.get(opts, :dry, false) do
      true -> IO.inspect({:mkdir, templated_path})
      false -> File.mkdir!(templated_path)
    end
  end

  defp cp(extname, from, to, opts)

  defp cp("eex", from, to, opts) do
    case Keyword.get(opts, :dry, false) do
      true ->
        IO.inspect({:cp_and_execute_template, {from, to}})

      false ->
        content = EEx.eval_file(from, app_name: Keyword.fetch!(opts, :app_name))
        File.write!(to, content)
    end
  end

  defp cp(_, from, to, opts) do
    case Keyword.get(opts, :dry, false) do
      true -> IO.inspect({:cp, {from, to}})
      false -> File.cp!(from, to)
    end
  end
end
