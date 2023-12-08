#!/usr/bin/env bash

# Special thanks to:
# https://github.com/Leoyzen/KVM-Opencore
# https://github.com/thenickdude/KVM-Opencore/
# https://github.com/qemu/qemu/blob/master/docs/usb2.txt

# qemu-img create -f qcow2 mac_hdd_ng.img 128G
# echo 1 > /sys/module/kvm/parameters/ignore_msrs (this is required)

MY_OPTIONS="+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check" # Add or remove CPU features based on your processor
CPU_SOCKETS="1"
CPU_CORES="4"
CPU_THREADS="2"
ALLOCATED_RAM="65536" # in MiB
REPO_PATH="."
OVMF_DIR="."

# Set use-gpu to 1 for GPU passthrough, 0 for normal operation
use_gpu=0

osx_in_use="ventura"

start_vm() {
    echo "starting vm..."
    cpupower frequency-set -g performance # Set CPU governor to performance

    # Restrict the host to specific CPUs when the VM starts (modify as needed)
    EMULATOR_CPUSET="4-9,14-19"
    HOST_CPUS="4-9,14-19"
    ALL_CPUS="0-19"

    systemctl set-property --runtime -- system.slice AllowedCPUs=$HOST_CPUS
    systemctl set-property --runtime -- user.slice AllowedCPUs=$HOST_CPUS
    systemctl set-property --runtime -- init.scope AllowedCPUs=$HOST_CPUS

    taskset -c $EMULATOR_CPUSET qemu-system-x86_64 "${args[@]}"
}

stop_vm() {
    echo "shutdowing vm..."
    cpupower frequency-set -g powersave # Set CPU governor back to powersave

    # Release all CPUs back to the host when the VM stops
    systemctl set-property --runtime -- system.slice AllowedCPUs=$ALL_CPUS
    systemctl set-property --runtime -- user.slice AllowedCPUs=$ALL_CPUS
    systemctl set-property --runtime -- init.scope AllowedCPUs=$ALL_CPUS
}

if [ "$use_gpu" -eq 1 ]; then
    # GPU Passthrough Configuration
    args=(
        -enable-kvm -m "$ALLOCATED_RAM" -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
        -machine q35
        -usb -device usb-kbd -device usb-tablet
        -smp cores=$CPU_CORES,threads=$CPU_THREADS,sockets=$CPU_SOCKETS
        -vga none
        -device vfio-pci,host=05:00.0,multifunction=on,x-no-kvm-intx=on
        -device vfio-pci,host=05:00.1
        -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
        -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/../macos-machines/"$osx_in_use"/OVMF_CODE.fd"
        -drive if=pflash,format=raw,file="$REPO_PATH/../macos-machines/"$osx_in_use"/OVMF_VARS-GPU.fd"
        -smbios type=2
        -device ich9-intel-hda -device hda-duplex
        -device ich9-ahci,id=sata
        -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore/OpenCore.qcow2"
        -device ide-hd,bus=sata.2,drive=OpenCoreBoot
        -device ide-hd,bus=sata.3,drive=InstallMedia
        -drive id=InstallMedia,if=none,file="$REPO_PATH/../macos-machines/"$osx_in_use"/BaseSystem.img",format=raw
        -drive id=MacHDD,if=none,file="$REPO_PATH/mac_hdd_ng.img",format=qcow2
        -device ide-hd,bus=sata.4,drive=MacHDD
        -netdev user,id=net0 -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27
        -monitor stdio
        -display none
    )
else
    # Normal VM Configuration (No GPU Passthrough)
    args=(
        -enable-kvm -m "$ALLOCATED_RAM" -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
        -machine q35
        -usb -device usb-kbd -device usb-tablet
        -smp cores=$CPU_CORES,threads=$CPU_THREADS,sockets=$CPU_SOCKETS
        -device usb-ehci,id=ehci
        -device nec-usb-xhci,id=xhci
        -global nec-usb-xhci.msi=off
        -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
        -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/../macos-machines/"$osx_in_use"/OVMF_CODE.fd"
        -drive if=pflash,format=raw,file="$REPO_PATH/../macos-machines/"$osx_in_use"/OVMF_VARS-VGA.fd"
        -smbios type=2
        -device ich9-intel-hda -device hda-duplex
        -device ich9-ahci,id=sata
        -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore/OpenCore.qcow2"
        -device ide-hd,bus=sata.2,drive=OpenCoreBoot
        -device ide-hd,bus=sata.3,drive=InstallMedia
        -drive id=InstallMedia,if=none,file="$REPO_PATH/../macos-machines/"$osx_in_use"/BaseSystem.img",format=raw
        -drive id=MacHDD,if=none,file="$REPO_PATH/mac_hdd_ng.img",format=qcow2
        -device ide-hd,bus=sata.4,drive=MacHDD
        -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27
        -monitor stdio
        -device vmware-svga
    )
fi

trap stop_vm EXIT INT TERM

start_vm
