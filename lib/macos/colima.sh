#!/usr/bin/env bash

# Shared Colima state checks. Sourced, never executed.

# Colima is considered up when its docker socket exists and the lima host
# agent holding it is alive. Both are bash builtins, so the check costs
# ~0.4ms and is cheap enough for a per-command hot path. It deliberately
# stops short of proving the daemon answers: that needs a socket connect
# (~35ms, more than a whole `docker ps`), and `colima status` shells into
# the VM over SSH and can take minutes.
is_colima_running() {
  local socket_path="$HOME/.colima/default/docker.sock"
  local host_agent_pid_file="$HOME/.colima/_lima/colima/ha.pid"
  local host_agent_pid

  [[ -S "$socket_path" ]] || return 1
  read -r host_agent_pid < "$host_agent_pid_file" 2>/dev/null || return 1

  kill -0 "$host_agent_pid" 2>/dev/null
}

# A Colima VM only exists once it has been provisioned. Starting one that
# was never created gives it the stock 2 CPU / 2 GB, too small for the
# amd64 QEMU builds Kamal needs, so callers check this before starting.
colima_vm_exists() {
  [[ -f "$HOME/.colima/_lima/colima/lima.yaml" ]]
}

# Resident size, in MiB, of the Virtualization.framework process that holds
# the Colima VM's RAM -- what Activity Monitor labels "Virtual Machine
# Service for limactl". It is an XPC service reparented to launchd, so there
# is no process-tree link back to limactl and the executable path is the only
# handle available. Refusing to answer when the match is not unique keeps a
# second VZ guest (Docker Desktop, UTM, another lima instance) from being
# reported as Colima's.
colima_vm_host_rss_mb() {
  local vm_pids

  vm_pids="$(pgrep -f com.apple.Virtualization.VirtualMachine)" || return 1
  [[ "$(wc -l <<< "$vm_pids")" -eq 1 ]] || return 1

  ps -o rss= -p "$vm_pids" | awk '{ printf "%d\n", $1 / 1024 }'
}
