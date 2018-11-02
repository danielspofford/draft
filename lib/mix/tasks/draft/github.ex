defmodule Mix.Tasks.Draft.Github do
  use Mix.Task
  alias Draft.Github
  alias Git.Repository

  @moduledoc """
  Executes a template identified by `user/repo`.

  ## Switches

  `--dry` - Print out what this run would have done, instead of actually doing it.

  All other switches provided will be passed along as bindings while templating EEx files.
  """

  @shortdoc "Executes a template from a Github repo."

  @preferred_cli_env :dev

  def run(argv) do
    with {:ok, {user_repo, opts}} <- parse_argv(argv),
         {:ok, {user, repo}} <- parse_user_repo(user_repo),
         {:ok, path} <- make_dir(user, repo),
         :ok <- clone(user, repo, path, is_empty?(path)) do
      Draft.execute(path, opts)
    else
      {:error, :user_repo} ->
        Mix.raise(~S(Expected user/repo to be given, please use "mix draft.github user/repo"))

      {:error, {:path, path}} ->
        Mix.raise("Failed while creating tmp dir to clone into: #{path}")

      {:error, {:clone, err, args, code}} ->
        Mix.raise("""
        Failed while cloning:
          err: #{err}
          args: #{args}
          code: #{code}\
        """)
    end
  end

  defp parse_argv(argv) do
    case OptionParser.parse(argv, switches: [dry: :boolean], allow_nonexistent_atoms: true) do
      {opts, [user_repo], []} -> {:ok, {user_repo, opts}}
      _ -> {:error, :user_repo}
    end
  end

  defp parse_user_repo(user_repo) do
    case String.split(user_repo, "/") do
      [user, repo] -> {:ok, {user, repo}}
      _ -> {:error, :user_repo}
    end
  end

  defp is_empty?(path) do
    file_count =
      path
      |> File.ls!()
      |> length()

    file_count == 0
  end

  defp clone(user, repo, path, is_empty?)

  defp clone(_, _, path, false) do
    Mix.shell().info("Using cached repo at: #{path}")
    :ok
  end

  defp clone(user, repo, path, true) do
    url = repo_url(user, repo)
    args = ["clone", url, path]
    opts = [stderr_to_stdout: true]

    case System.cmd("git", args, opts) do
      {output, 0} -> :ok
      {err, code} -> {:error, {:clone, err, args, code}}
    end
  end

  defp make_dir(user, repo) do
    path = Path.join([System.tmp_dir!(), "#{user}_#{repo}"])

    case File.mkdir(path) do
      :ok -> {:ok, path}
      {:error, :eexist} -> {:ok, path}
      _ -> {:error, {:path, path}}
    end
  end

  defp repo_url(user, repo), do: "https://github.com/#{user}/#{repo}"
end
