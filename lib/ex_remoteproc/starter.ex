defmodule ExRemoteproc.Starter do
  @moduledoc """
  Kicks the configured remoteprocs into `running` once at boot.

  Why this is needed on the Fairphone 3 (MSM8953/SDM632): the ADSP driver
  (`qcom_q6v5_pas`, built into the kernel) probes a couple of seconds into
  boot and asks the kernel firmware loader for its firmware under
  `/lib/firmware`. At that point the root filesystem
  isn't mounted yet, the request fails with `-ENOENT` and the remoteproc
  stays `offline`. Once userspace is running `/lib/firmware` is available,
  and writing `start` to its `state` file boots it.

  This does not depend on `rmtfs`: rmtfs serves the modem's EFS partitions,
  not remoteproc firmware, and the ADSP is loaded directly by the kernel.

  For each configured name the Starter reads the state via
  `ExRemoteproc.state/1`; if it is not `running` it calls
  `ExRemoteproc.kick/1`. A remoteproc that doesn't exist yet (its driver
  may still be probing) or whose kick fails is retried a few times, after
  1, 2, 4 and 8 seconds, then given up on with a warning. Nothing here ever
  crashes.
  """
  use GenServer
  require Logger

  @retry_delays [1_000, 2_000, 4_000, 8_000]

  @doc false
  def start_link(names) do
    GenServer.start_link(__MODULE__, names, name: __MODULE__)
  end

  @impl true
  def init(names) do
    {:ok, %{}, {:continue, {:kick, Enum.map(names, &to_string/1), @retry_delays}}}
  end

  @impl true
  def handle_continue({:kick, names, delays}, state) do
    {:noreply, kick_all(names, delays, state)}
  end

  @impl true
  def handle_info({:kick, names, delays}, state) do
    {:noreply, kick_all(names, delays, state)}
  end

  defp kick_all(names, delays, state) do
    failed = Enum.reject(names, &ensure_running/1)

    case {failed, delays} do
      {[], _} ->
        :ok

      {_, [delay | rest]} ->
        Process.send_after(self(), {:kick, failed, rest}, delay)

      {_, []} ->
        Logger.warning("ex_remoteproc: giving up on #{inspect(failed)}")
    end

    state
  end

  # Returns true when the remoteproc is running (or was just started).
  defp ensure_running(name) do
    case ExRemoteproc.state(name) do
      {:ok, "running"} ->
        Logger.info("ex_remoteproc: #{name} already running")
        true

      {:ok, current} ->
        case ExRemoteproc.kick(name) do
          :ok ->
            Logger.info("ex_remoteproc: kicked #{name} (was #{current})")
            true

          {:error, reason} ->
            Logger.warning("ex_remoteproc: kick #{name} failed: #{inspect(reason)}")
            false
        end

      {:error, reason} ->
        Logger.warning("ex_remoteproc: #{name}: #{inspect(reason)}")
        false
    end
  end
end
