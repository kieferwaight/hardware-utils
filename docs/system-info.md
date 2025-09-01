# System Information

On Linux, you won’t see the glossy Apple “About This Mac” screen, but you can still query the hardware pretty well.

Here are a few ways:

---

### 1. Check DMI/SMBIOS info (best way)

```bash
sudo dmidecode -s system-manufacturer
sudo dmidecode -s system-product-name
sudo dmidecode -s system-version
```

That should print something like:

```sh
Apple Inc.
MacPro6,1
1.0
```

👉 `MacPro6,1` is the model identifier for the **2013 “trash can” Mac Pro**.

---

### 2. Quick one-liner

```bash
sudo dmidecode -t system
```

This shows manufacturer, product name, version, serial number.

---

### 3. Get CPU + memory info (to double-check)

```bash {"terminalRows":"23"}
lscpu | grep "Model name"
sudo lshw -short | grep -E "system|memory|processor"
```

---

### 4. Serial number (if you need it)

```bash
sudo dmidecode -s system-serial-number
```

---

### 5. Product Name

```bash
sudo dmidecode -s system-product-name
```

## Hardware

```bash
sudo dmidecode -t system
sudo dmidecode -t baseboard
sudo dmidecode -t processor
sudo dmidecode -t memory
```

```bash
lspci -nnk
```

```bash
lspci -nnk | grep -i -A3 vga
```

```bash
lsusb
```

```bash
ip link show
```

```bash
nmcli device show | grep -i 'mac\|hardware'
```

```bash
sudo lshw -short
```

```bash
mkdir -p ../logs
touch ../logs/hardware.json

sudo lshw -json > ../logs/hardware.json
```

```bash
lspci -nn | grep -E 'VGA|Display'
```

Perfect, this gives a lot of clarity. Here’s what your system is telling us:

---

### **Analysis**

1. **PCI IDs:** Both GPUs are detected as `[1002:6810]`, which is indeed **Curacao XT / Trinidad XT** (R9 270X / 370X). ✅
2. **Modules:** Only `amdgpu` is loaded — no `radeon` module is active. That’s good; it means you’re not in conflict.
3. **Module alias check:** `grep -i curacao /lib/modules/$(uname -r)/modules.alias` returned nothing. This is expected because **these older GPUs are not enabled by default in `amdgpu`**; they fall under “CIK support” (Sea Islands / GCN 1.1).

---

### **Next Steps**

You need to **enable experimental CIK support** in the kernel so `amdgpu` can properly handle Curacao / Trinidad GPUs.

1. **Edit GRUB:**

```bash
sudo nano /etc/default/grub
```

2. **Add kernel parameters** to the default line:

```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amdgpu.cik_support=1 radeon.cik_support=0"
```

* `amdgpu.cik_support=1` → enables amdgpu for Curacao / Tonga / CIK GPUs
* `radeon.cik_support=0` → disables radeon for these GPUs

3. **Update GRUB and reboot:**

```bash
sudo update-grub
sudo reboot
```

---

### **Step 2: Verify After Reboot**

```bash
lsmod | grep amdgpu
dmesg | grep amdgpu
lspci -k | grep -A 3 -E "VGA|Display"
```

* You should see your GPUs claimed by **amdgpu**.
* Look for lines in `dmesg` showing `amdgpu CIK support enabled`.

---

### **Step 3: Install Firmware & Mesa Updates**

Make sure firmware and graphics stack are installed:

```bash
sudo apt update
sudo apt install firmware-amd-graphics mesa-utils mesa-vulkan-drivers
```

Check OpenGL / Vulkan:

```bash
glxinfo | grep "OpenGL renderer"
vulkaninfo | head -n 20
```

Expected: “AMD Radeon R9 200 Series” or similar.

---

If you want, I can write a **full one-shot shell script** that:

* Enables CIK support in GRUB
* Updates GRUB
* Installs all needed firmware and Mesa packages
* Verifies the GPUs

This will save you manual editing.

Do you want me to do that?
