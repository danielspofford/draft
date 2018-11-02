defmodule Mix.Tasks.Draft.Github do
  use Mix.Task
  alias Draft.Github
  alias Git.Repository

  @moduledoc """
  Executes a template identified by `user/repo`.
  """

  @shortdoc "Executes a template from a Github repo."

  @preferred_cli_env :dev

  def run([user_repo | args]) do
    with {:ok, {user, repo}} <- parse_user_repo(user_repo),
         {:ok, path} <- make_dir(user, repo) do
      user
      |> clone(repo, path, is_empty?(path))
      |> Draft.execute()
    else
      {:error, :user_repo} ->
        user_repo_error()

      {:error, {:path, path}} ->
        Mix.raise(~s(Failed while creating tmp dir to clone into: #{path}))
    end
  end

  def run(_), do: user_repo_error()

  def parse_user_repo(user_repo) do
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

  defp clone(user, repo, path, false), do: path

  defp clone(user, repo, path, true) do
    url = repo_url(user, repo)
    {:ok, %Repository{path: path}} = Git.clone([url, path])
    path
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

  defp user_repo_error do
    Mix.raise(~S(Expected user/repo to be given, please use "mix draft.github user/repo"))
  end
end
