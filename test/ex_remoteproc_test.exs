defmodule ExRemoteprocTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    root = Path.join(dir, "remoteproc")
    File.mkdir_p!(root)
    Application.put_env(:ex_remoteproc, :sysfs_root, root)
    on_exit(fn -> Application.delete_env(:ex_remoteproc, :sysfs_root) end)
    %{root: root}
  end

  defp add_rproc(root, entry, name, state) do
    dir = Path.join(root, entry)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "name"), name <> "\n")
    if state, do: File.write!(Path.join(dir, "state"), state <> "\n")
    dir
  end

  defp read_state(dir), do: File.read!(Path.join(dir, "state"))

  test "list/0 returns name => state and skips unreadable entries", %{root: root} do
    add_rproc(root, "remoteproc0", "adsp", "offline")
    add_rproc(root, "remoteproc1", "4080000.remoteproc", "running")
    add_rproc(root, "remoteproc2", "broken", nil)

    assert ExRemoteproc.list() == %{"adsp" => "offline", "4080000.remoteproc" => "running"}
  end

  test "list/0 returns an empty map when sysfs root is missing", %{root: root} do
    File.rm_rf!(root)
    assert ExRemoteproc.list() == %{}
  end

  test "state/1, find/1 and kick/1", %{root: root} do
    dir = add_rproc(root, "remoteproc0", "adsp", "offline")

    assert {:ok, ^dir} = ExRemoteproc.find(:adsp)
    assert {:ok, "offline"} = ExRemoteproc.state("adsp")
    assert :ok = ExRemoteproc.kick(:adsp)
    assert read_state(dir) == "start"

    assert {:error, :not_found} = ExRemoteproc.find(:nope)
    assert {:error, :not_found} = ExRemoteproc.state(:nope)
    assert {:error, :not_found} = ExRemoteproc.kick(:nope)
  end

  describe "Starter" do
    test "kicks offline remoteprocs and leaves running ones alone", %{root: root} do
      adsp = add_rproc(root, "remoteproc0", "adsp", "offline")
      mss = add_rproc(root, "remoteproc1", "mss", "running")

      start_supervised!({ExRemoteproc.Starter, [:adsp, "mss"]})
      :sys.get_state(ExRemoteproc.Starter)

      assert read_state(adsp) == "start"
      assert read_state(mss) == "running\n"
    end

    test "retries a remoteproc that appears later", %{root: root} do
      pid = start_supervised!({ExRemoteproc.Starter, [:adsp]})
      :sys.get_state(pid)

      adsp = add_rproc(root, "remoteproc0", "adsp", "offline")
      Process.sleep(1_300)

      assert read_state(adsp) == "start"
      assert Process.alive?(pid)
    end
  end
end
