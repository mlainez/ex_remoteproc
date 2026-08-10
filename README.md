# ex_remoteproc

> ### ⚠️ Very early work — built for a workshop, not for production
>
> Written for the **Goatmire Elixir workshop** on running Nerves on
> Fairphone 3 hardware. It exists for tinkering and teaching.
>
> **Not an actively maintained project** (yet) — no stability
> guarantees, no test coverage, APIs will change without notice.

Starts Qualcomm remote processors from userspace once
[`ex_rmtfs`](https://github.com/mlainez/ex_rmtfs) is serving their
firmware.

## Install

```elixir
defp deps do
  [{:ex_remoteproc, github: "mlainez/ex_remoteproc"}]
end
```

## Configure

Name the remoteprocs to bring up at boot, using their kernel names from
`/sys/class/remoteproc/*/name`:

```elixir
config :ex_remoteproc, start: [:adsp]
```

`[:adsp]` is the default, and usually all you need. On the FP3+ the
other two — `4080000.remoteproc` (modem MSS) and `a204000.remoteproc`
(WCNSS) — boot at kernel probe time without help.

## Usage

```elixir
ExRemoteproc.list()      # what the kernel exposes
ExRemoteproc.kick(:adsp) # start one by hand
```

## Who needs this

The ADSP has to be running before several other things work:

- [`ex_audio`](https://github.com/mlainez/ex_audio) — the sound card
  doesn't appear until the DSP is up
- [`ex_qcom_smgr`](https://github.com/mlainez/ex_qcom_smgr) — IIO
  sensors are ADSP-bridged

Both depend on this package for that reason. Ordering matters: `rmtfs`
must be serving before a remoteproc is kicked, or firmware loading fails
and the DSP stays down.

## License

Apache-2.0
