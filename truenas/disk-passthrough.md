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

2. **GRUB Configuration** - Modified `/etc/default/grub`:
   ```bash
   GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
   ```
   
   The `iommu=pt` parameter enables passthrough mode for better performance.

3. **Applied Changes:**
   ```bash
   update-grub
   reboot
   ```

4. **Verified IOMMU Status:**
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

**Driver Blacklisting:**

To prevent Proxmox from claiming the SATA controller, I blacklisted the AHCI drivers in `/etc/modprobe.d/blacklist.conf`:
```
blacklist ahci
blacklist libahci
```

This ensures the controller remains available for VM passthrough.

**Finalized Configuration:**
```bash
update-initramfs -u -k all
reboot
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
hostpci0: 0000:00:1f.2,pcie=1
```

The `pcie=1` parameter enables PCIe mode for better performance and feature support.

## Verification

After booting the TrueNAS VM, I verified successful passthrough:

- **Storage > Disks** shows all three physical Seagate Exos X14 drives
- SMART data is accessible for health monitoring
- Disk serial numbers are visible (ZTM09FD7, ZLM2BF4E, ZTM093QT)
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
