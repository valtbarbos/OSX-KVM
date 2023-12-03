#!/bin/bash

# VM Configuration Variables
VM_NAME="MacOS.Monterey"
VM_UUID="666a2830-1daf-442f-ab97-159caeb1c371"
MEMORY_SIZE="65536M" # 64 GB
CPU_OPTS="Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on" # Replace with your CPU flags
OVMF_CODE="/var/lib/virtual-machines/OSX-KVM/OVMF_CODE.fd"
OVMF_VARS="/var/lib/virtual-machines/OSX-KVM/OVMF_VARS.fd"
OPEN_CORE_DISK="/var/lib/virtual-machines/OSX-KVM/OpenCore/OpenCore.qcow2"
MAC_HDD_DISK="/var/lib/virtual-machines/OSX-KVM/mac_hdd_ng.img"
BASE_SYSTEM_DISK="/var/lib/virtual-machines/OSX-KVM/BaseSystem.img"
NET_MAC_ADDR="52:54:00:26:44:6b"
GPU_VFIO_DEVICES="-device vfio-pci,host=05:00.0,multifunction=on -device vfio-pci,host=05:00.1"
# Modify GPU_VFIO_DEVICES to match your GPU's PCI addresses
REPO_PATH="."
OVMF_DIR="."
# QEMU Command
qemu-system-x86_64 \
  -name $VM_NAME \
  -uuid $VM_UUID \
  -m $MEMORY_SIZE \
  -cpu $CPU_OPTS \
  -machine q35 \
  -usb -device usb-kbd -device usb-tablet -device usb-mouse \
  -device qemu-xhci,id=usb \
  -smp cores=2,sockets=1,threads=4 \
  -device ich9-ahci,id=sata \
  -drive file=$OPEN_CORE_DISK,format=qcow2,id=OpenCoreBoot,if=none \
  -device ide-hd,bus=sata.2,drive=OpenCoreBoot \
  -drive file=$BASE_SYSTEM_DISK,format=raw,id=InstallMedia \
  -device ide-hd,bus=sata.3,drive=InstallMedia \
  -drive file=$MAC_HDD_DISK,format=qcow2,id=MacHDD \
  -device ide-hd,bus=sata.4,drive=MacHDD \
  -netdev user,id=net0 -device e1000,netdev=net0,mac=$NET_MAC_ADDR \
  $GPU_VFIO_DEVICES \
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
  -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/$OVMF_DIR/OVMF_CODE.fd" \
  -drive if=pflash,format=raw,file="$REPO_PATH/$OVMF_DIR/OVMF_VARS-1920x1080.fd" \
  -smbios type=2 \
  -device ich9-intel-hda -device hda-duplex \
  -vnc 0.0.0.0:1,password=on -k en-us \
  -monitor stdio \
  -display none

# Add additional custom input devices if needed
# -object input-linux,id=kbd1,evdev=/dev/input/by-id/uinput-persist-keyboard0,grab_all=on,repeat=on
# -object input-linux,id=mouse1,evdev=/dev/input/by-id/uinput-persist-mouse0
