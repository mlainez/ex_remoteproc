defmodule ExRemoteproc.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    names = Application.get_env(:ex_remoteproc, :start, [:adsp])

    children = [
      {ExRemoteproc.Starter, names}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: ExRemoteproc.Supervisor
    )
  end
end
