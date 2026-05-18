defmodule ExRemoteproc do
  @moduledoc """
  Starts Qualcomm remoteprocs from userspace once `:ex_rmtfs` is serving.

  Configure which remoteprocs to bring up at boot (by their kernel name
  from `/sys/class/remoteproc/*/name`):

      config :ex_remoteproc, start: [:adsp]

  Default is `[:adsp]`. Other names that exist on the FP3+ are
  `4080000.remoteproc` (modem MSS) and `a204000.remoteproc` (WCNSS) —
  both boot at kernel probe time without help.

  ## Manual control

      iex> ExRemoteproc.kick(:adsp)
  """

  @sysfs "/sys/class/remoteproc"

  @doc """
  Returns a map of remoteproc name => current state for everything the
  kernel exposes.
  """
  @spec list() :: %{String.t() => String.t()}
  def list do
    case File.ls(@sysfs) do
      {:ok, entries} ->
        Map.new(entries, fn entry ->
          path = Path.join(@sysfs, entry)
          name = path |> Path.join("name") |> File.read!() |> String.trim()
          state = path |> Path.join("state") |> File.read!() |> String.trim()
          {name, state}
        end)

      _ ->
        %{}
    end
  end

  @doc """
  Writes `start` to the named remoteproc's `state` file.

  Returns `:ok` on success, `{:error, reason}` if the name isn't found or
  the kernel rejects the write.
  """
  @spec kick(atom() | String.t()) :: :ok | {:error, term()}
  def kick(name) do
    target = to_string(name)

    case find(target) do
      nil -> {:error, :not_found}
      path -> File.write(Path.join(path, "state"), "start")
    end
  end

  defp find(target) do
    case File.ls(@sysfs) do
      {:ok, entries} ->
        Enum.find_value(entries, fn entry ->
          path = Path.join(@sysfs, entry)

          case File.read(Path.join(path, "name")) do
            {:ok, content} ->
              if String.trim(content) == target, do: path

            _ ->
              nil
          end
        end)

      _ ->
        nil
    end
  end
end
