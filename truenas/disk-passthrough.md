# Disk Passthrough

## Overview

I configured PCIe passthrough to allow TrueNAS direct access to the SATA/SAS controller, bypassing Proxmox's virtualization layer. This approach is critical for ZFS performance and reliability in a virtualized environment.

## Rationale for Passthrough

I chose disk passthrough for several critical reasons:

1. **ZFS Architecture Requirements** - ZFS is designed to manage disks directly and requires access to raw block devices to function properly
2. **SMART Monitoring** - Direct hardware access enables TrueNAS to monitor disk health through SMART data
3. **Performance** - Eliminates virtualization overhead for disk I/O operations
4. **Reliability** - Allows ZFS to properly manage write caching and handle disk errors at the hardware level

## Implementation

### Host Configuration (Proxmox)

**IOMMU Enablement:**

I enabled IOMMU support in the Proxmox host to allow PCI device passthrough:

1. **BIOS Configuration** - Enabled Intel VT-d (or AMD-Vi for AMD systems)

2. **Kernel** - Proxmox kernels from 6.8 on (including 7.0 on Proxmox VE 9) enable the Intel IOMMU by default, so no extra GRUB parameters are needed (`GRUB_CMDLINE_LINUX_DEFAULT="quiet"`). Older kernels needed `intel_iommu=on iommu=pt`.

3. **Verified IOMMU Status:**
   ```bash
   dmesg | grep -e DMAR -e IOMMU
   ```
   Confirmed IOMMU was properly enabled with hardware support.

**VFIO Module Configuration:**

I configured the required VFIO (Virtual Function I/O) modules in `/etc/modules`:
```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

These modules enable PCI device assignment to virtual machines.

**Binding the Controller to vfio-pci at Boot:**

Instead of blacklisting the AHCI driver for the whole host, I bind only this controller (PCI ID `8086:7a62`, the only one of its kind in the machine) to `vfio-pci`, and make sure `vfio-pci` loads before `ahci`. In `/etc/modprobe.d/vfio-truenas-sata.conf`:
```
options vfio-pci ids=8086:7a62
softdep ahci pre: vfio-pci
```

**Finalized Configuration:**
```bash
update-initramfs -u -k all
reboot
lspci -nnk -s 00:17.0   # "Kernel driver in use: vfio-pci" right after boot
```

**Why this mattered:** originally the controller was only handed to `vfio-pci` when the TrueNAS VM started. Until then the host's `ahci` driver owned it, could see the data disks, and `zfs-import-scan` found TrueNAS's pools at every boot. Only ZFS's "pool was previously in use from another system" check prevented the host from importing a pool that TrueNAS was about to use (which would corrupt it). Now the host never sees those disks, and because the host has no ZFS pools of its own, its ZFS import services are masked as a second safeguard:
```bash
systemctl mask zfs-import-scan.service zfs-import-cache.service
```

### IOMMU Group Verification

I identified the SATA controller's IOMMU group using:

```bash
#!/bin/bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done
```

The controller was isolated in its own IOMMU group (or grouped only with related devices), which is necessary for clean passthrough.

### VM Configuration

I configured the TrueNAS VM to use the passed-through controller by adding this line to `/etc/pve/qemu-server/<VMID>.conf`:

```
hostpci0: 0000:00:17
```

The VM uses the q35 machine type with OVMF (UEFI) firmware.

## Verification

After booting the TrueNAS VM, I verified successful passthrough:

- **Storage > Disks** shows all three physical Seagate Exos X14 drives
- SMART data is accessible for health monitoring
- Disk serial numbers and models are visible to TrueNAS (omitted here)
- ZFS can directly manage the disks without abstraction layers

## Results

The passthrough configuration is working correctly:
- TrueNAS has direct hardware access to the storage controller
- All disk management features function as if TrueNAS were running on bare metal
- SMART monitoring provides accurate health data
- ZFS pool operations perform without virtualization overhead

## Notes

- The Proxmox host (showing QEMU HARDDISK for boot device) indicates the VM boots from a virtual disk while the data disks are passed through
- This hybrid approach maintains Proxmox management capabilities while giving TrueNAS the direct hardware access it requires
- The configuration successfully bypasses the virtualization layer for storage while maintaining VM lifecycle management
