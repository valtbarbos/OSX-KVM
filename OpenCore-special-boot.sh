#!/usr/bin/env bash

# Special thanks to:
# https://github.com/Leoyzen/KVM-Opencore
# https://github.com/thenickdude/KVM-Opencore/
# https://github.com/qemu/qemu/blob/master/docs/usb2.txt

# qemu-img create -f qcow2 mac_hdd_ng.img 128G
# echo 1 > /sys/module/kvm/parameters/ignore_msrs (this is required)

# NOTE: Tweak the "MY_OPTIONS" line in case you are having booting problems!
MY_OPTIONS="+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check"

# Set your CPU topology
CPU_SOCKETS="1"
CPU_CORES="4"
CPU_THREADS="2"
TOTAL_CPUS=$(($CPU_CORES * $CPU_THREADS))

# NOT available with QEMU only
# Set CPU pinning for vCPUs (0-7)
# CPU_AFFINITY="0,10,1,11,2,12,3,13"

# The taskset command is used to set the CPU affinity for the QEMU process itself
# This example pins the emulator threads to CPUs 4-9 and 14-19
EMULATOR_CPUSET="4-9,14-19"

# Define the CPUs reserved for the host when VM is running
HOST_CPUS="4-9,14-19"
# Define the full range of CPUs for when the VM is not running
ALL_CPUS="0-19"

# This script works for Big Sur, Catalina, Mojave, and High Sierra.
ALLOCATED_RAM="65536" # MiB
REPO_PATH="."
OVMF_DIR="."

start_vm() {
    # Set CPU governor to performance
    cpupower frequency-set -g performance

    # Restrict the host to specific CPUs when the VM starts
    systemctl set-property --runtime -- system.slice AllowedCPUs=$HOST_CPUS
    systemctl set-property --runtime -- user.slice AllowedCPUs=$HOST_CPUS
    systemctl set-property --runtime -- init.scope AllowedCPUs=$HOST_CPUS

    # Start the VM with CPU pinning and options
    taskset -c $EMULATOR_CPUSET qemu-system-x86_64 "${args[@]}"
}

stop_vm() {
    # Set CPU governor to powersave (or ondemand/powersave based on your preference)
    cpupower frequency-set -g powersave

    # Release all CPUs back to the host when the VM stops
    systemctl set-property --runtime -- system.slice AllowedCPUs=$ALL_CPUS
    systemctl set-property --runtime -- user.slice AllowedCPUs=$ALL_CPUS
    systemctl set-property --runtime -- init.scope AllowedCPUs=$ALL_CPUS
}

args=(
    -enable-kvm -m "$ALLOCATED_RAM" -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
    -machine q35
    -usb -device usb-kbd -device usb-tablet
    -smp cores=$CPU_CORES,threads=$CPU_THREADS,sockets=$CPU_SOCKETS
    -device usb-ehci,id=ehci
    # -device usb-kbd,bus=ehci.0
    # -device usb-mouse,bus=ehci.0er 2 USD USB Sound Card
    -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
    -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/$OVMF_DIR/OVMF_CODE.fd"
    -drive if=pflash,format=raw,file="$REPO_PATH/$OVMF_DIR/OVMF_VARS-1920x1080.fd"
    -smbios type=2
    -device ich9-intel-hda -device hda-duplex
    -device ich9-ahci,id=sata
    -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore/OpenCore.qcow2"
    -device ide-hd,bus=sata.2,drive=OpenCoreBoot
    -device ide-hd,bus=sata.3,drive=InstallMedia
    -drive id=InstallMedia,if=none,file="$REPO_PATH/BaseSystem.img",format=raw
    -drive id=MacHDD,if=none,file="$REPO_PATH/mac_hdd_ng.img",format=qcow2
    -device ide-hd,bus=sata.4,drive=MacHDD
    # -netdev tap,id=net0,ifname=tap0,script=no,downscript=no -device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27
    -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27
    # -netdev user,id=net0 -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27  # Note: Use this line for High Sierra
    -monitor stdio
    -device vmware-svga
)

# Ensure the VM stops properly and resets the CPU settings
trap stop_vm EXIT INT TERM

# Start the VM
start_vm
    -device nec-usb-xhci,id=xhci
    -global nec-usb-xhci.msi=off
    # -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
    # -device usb-host,vendorid=0x8086,productid=0x0808  # 2 USD USB Sound Card
    # -device usb-host,vendorid=0x1b3f,productid=0x2008  # Anoth