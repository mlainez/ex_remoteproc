defmodule ExRemoteproc do
  @moduledoc """
  Inspects and starts Qualcomm remote processors through the kernel's
  remoteproc sysfs interface (`/sys/class/remoteproc/remoteprocN/{name,state}`).

  The `:ex_remoteproc` application also starts `ExRemoteproc.Starter`,
  which kicks the remoteprocs listed in the application environment once at
  boot:

      config :ex_remoteproc, start: [:adsp]

  `[:adsp]` is the default; use `start: []` to kick nothing. Names are the
  kernel names from `/sys/class/remoteproc/*/name`. On the Fairphone 3 the
  others are `4080000.remoteproc` (modem MSS) and `a204000.remoteproc`
  (WCNSS); those do not need a kick.

  The sysfs root can be changed (mainly for tests):

      config :ex_remoteproc, sysfs_root: "/sys/class/remoteproc"

  None of these functions raise; unreadable entries are skipped or reported
  as `{:error, reason}`.

  ## Manual control

      ExRemoteproc.list()
      #=> %{"adsp" => "running", "4080000.remoteproc" => "running"}

      ExRemoteproc.state(:adsp)
      #=> {:ok, "offline"}

      ExRemoteproc.kick(:adsp)
      #=> :ok
  """

  @default_sysfs_root "/sys/class/remoteproc"

  @doc """
  Returns the configured sysfs root (`config :ex_remoteproc, :sysfs_root`,
  default `"/sys/class/remoteproc"`).
  """
  @spec sysfs_root() :: Path.t()
  def sysfs_root, do: Application.get_env(:ex_remoteproc, :sysfs_root, @default_sysfs_root)

  @doc """
  Returns a map of remoteproc name => current state for everything the
  kernel exposes. Entries whose `name` or `state` can't be read are skipped;
  a missing sysfs directory gives `%{}`.
  """
  @spec list() :: %{String.t() => String.t()}
  def list do
    for path <- entries(),
        {:ok, name} <- [read_trimmed(Path.join(path, "name"))],
        {:ok, state} <- [read_trimmed(Path.join(path, "state"))],
        into: %{},
        do: {name, state}
  end

  @doc """
  Returns the current state (`"offline"`, `"running"`, `"crashed"`, ...) of
  the named remoteproc, or `{:error, :not_found}`.
  """
  @spec state(atom() | String.t()) :: {:ok, String.t()} | {:error, term()}
  def state(name) do
    with {:ok, path} <- find(name) do
      read_trimmed(Path.join(path, "state"))
    end
  end

  @doc """
  Writes `start` to the named remoteproc's `state` file.

  Returns `:ok` on success, `{:error, :not_found}` if no remoteproc has that
  name, or `{:error, posix}` if the kernel rejects the write (writing
  `start` to a remoteproc that is already running fails with `:ebusy`).
  """
  @spec kick(atom() | String.t()) :: :ok | {:error, term()}
  def kick(name) do
    with {:ok, path} <- find(name) do
      File.write(Path.join(path, "state"), "start")
    end
  end

  @doc """
  Returns `{:ok, sysfs_dir}` for the remoteproc called `name`, or
  `{:error, :not_found}`.
  """
  @spec find(atom() | String.t()) :: {:ok, Path.t()} | {:error, :not_found}
  def find(name) do
    target = to_string(name)

    case Enum.find(entries(), &(read_trimmed(Path.join(&1, "name")) == {:ok, target})) do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end

  defp entries do
    root = sysfs_root()

    case File.ls(root) do
      {:ok, names} -> names |> Enum.sort() |> Enum.map(&Path.join(root, &1))
      {:error, _} -> []
    end
  end

  defp read_trimmed(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, String.trim(content)}
      error -> error
    end
  end
end
