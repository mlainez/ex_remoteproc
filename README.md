# ex_remoteproc

> ### ⚠️ Very early work — built for a workshop, not for production
>
> Written for the **Goatmire Elixir workshop** on running Nerves on Fairphone 3 hardware. There are no stability guarantees and APIs will change without notice.

Starts Qualcomm remote processors from userspace through the kernel's
remoteproc sysfs interface (`/sys/class/remoteproc/*/{name,state}`).

## Why

On the Fairphone 3 (MSM8953/SDM632) the ADSP driver is built into the
kernel and probes a couple of seconds into boot, before the root filesystem
is mounted. Its firmware request against `/lib/firmware` fails, and the
ADSP stays `offline`. Once userspace is up the firmware is available, and
writing `start` to the remoteproc's `state` file boots it. That is all this
library does.

It does not need `rmtfs` (which serves the modem's EFS partitions, not
remoteproc firmware), so it has no dependency on `ex_rmtfs`.

## Install

```elixir
defp deps do
  [{:ex_remoteproc, github: "mlainez/ex_remoteproc"}]
end
```

Requires a kernel with `CONFIG_REMOTEPROC` and the Qualcomm remoteproc
drivers, and the remoteproc firmware in `/lib/firmware` (both provided by
`nerves_system_fp3`). No userspace binaries are needed.

## Configure

The application starts automatically and kicks the listed remoteprocs once
at boot, using their kernel names from `/sys/class/remoteproc/*/name`:

```elixir
config :ex_remoteproc,
  start: [:adsp],                        # default; [] kicks nothing
  sysfs_root: "/sys/class/remoteproc"    # default
```

On the Fairphone 3 the other remoteprocs, `4080000.remoteproc` (modem MSS)
and `a204000.remoteproc` (WCNSS), don't need a kick.

A remoteproc that is already `running` is left alone. One that isn't found
yet, or whose kick fails, is retried after 1, 2, 4 and 8 seconds and then
given up on with a warning. Nothing crashes.

## Usage

```elixir
ExRemoteproc.list()        # %{"adsp" => "offline", ...}
ExRemoteproc.state(:adsp)  # {:ok, "offline"} | {:error, :not_found}
ExRemoteproc.kick(:adsp)   # :ok | {:error, :not_found | posix}
```

None of these raise. `kick/1` on a remoteproc that is already running
returns the kernel's error (`{:error, :ebusy}`).

## Who needs this

The ADSP has to be running before:

- [`ex_audio`](https://github.com/mlainez/ex_audio): the sound card
  doesn't appear until the DSP is up
- [`ex_qcom_smgr`](https://github.com/mlainez/ex_qcom_smgr): the IIO
  sensors are bridged through the ADSP

Both list `ex_remoteproc` as a dependency so OTP starts it first.

## Status

Tested on the host against a fake sysfs tree. Behaviour on the Fairphone 3
has not been re-verified since the retry logic and the removal of the
`ex_rmtfs` dependency and the 500 ms startup delay.

## Toolchain

Built and tested with Erlang/OTP 29.1.1 and Elixir 1.20.4, matching the official Nerves systems (see `.tool-versions`).

## License

Apache-2.0
