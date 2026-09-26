defmodule ExRemoteproc.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      case Application.get_env(:ex_remoteproc, :start, [:adsp]) do
        [] -> []
        names -> [{ExRemoteproc.Starter, names}]
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: ExRemoteproc.Supervisor)
  end
end
