defmodule ExRemoteproc.Starter do
  @moduledoc """
  Kicks the configured Qualcomm remoteprocs into `running` after rmtfs is up.

  On MSM8953/SDM632 the ADSP firmware loads at probe time (kernel ~t+2.5 s),
  before the squashfs rootfs is mounted, so its `qcom/.../adsp.mbn` lookup
  fails with -2 and the remoteproc stays `offline`. Once userspace is up,
  rmtfs needs to be serving on QRTR *before* we re-trigger ADSP boot so the
  ADSP firmware can find its shared storage.

  ex_remoteproc depends on `:ex_rmtfs` in mix.exs, so OTP guarantees
  ex_rmtfs is started first. This Starter then writes `start` to
  `/sys/class/remoteproc/<n>/state` for each name in the config.
  """
  use GenServer
  require Logger

  @sysfs "/sys/class/remoteproc"

  def start_link(names) do
    GenServer.start_link(__MODULE__, names, name: __MODULE__)
  end

  @impl true
  def init(names) do
    {:ok, %{names: names}, {:continue, :kick_all}}
  end

  @impl true
  def handle_continue(:kick_all, %{names: names} = state) do
    # Give ex_rmtfs a moment to bind its QRTR socket before the ADSP
    # firmware starts hitting it for storage requests.
    Process.sleep(500)
    Enum.each(names, &kick/1)
    {:noreply, state}
  end

  defp kick(name) do
    target = to_string(name)

    case find(target) do
      nil ->
        Logger.warning("ex_remoteproc: no remoteproc named #{inspect(target)}")

      path ->
        do_kick(target, path)
    end
  end

  defp do_kick(name, path) do
    state_path = Path.join(path, "state")

    case File.read(state_path) do
      {:ok, content} ->
        case String.trim(content) do
          "running" ->
            Logger.info("ex_remoteproc: #{name} already running")

          current ->
            case File.write(state_path, "start") do
              :ok ->
                Logger.info("ex_remoteproc: kicked #{name} (was #{current})")

              {:error, reason} ->
                Logger.warning("ex_remoteproc: kick #{name} failed: #{inspect(reason)}")
            end
        end

      {:error, reason} ->
        Logger.warning("ex_remoteproc: cannot read #{state_path}: #{inspect(reason)}")
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
