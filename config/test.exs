import Config

# Don't touch the host's /sys at application start; tests use a temp tree.
config :ex_remoteproc, start: []
