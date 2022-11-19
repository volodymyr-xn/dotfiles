#!/usr/bin/env bash

# The qemu package (quick emulator) is an application that allows you to perform hardware virtualization.
# The qemu-kvm package is the main KVM package.
# The libvritd-daemon is the virtualization daemon.
# The bridge-utils package helps you create a bridge connection to allow other users to access a virtual machine other than the host system.
# The virt-manager is an application for managing virtual machines through a graphical user interface.

sudo apt install -y \
  qemu \
  qemu-kvm \
  libvirt-daemon \
  libvirt-clients \
  bridge-utils \
  virt-manager

current_user=`id -un`

sudo adduser "$current_user" libvirt
sudo adduser "$current_user" kvm
