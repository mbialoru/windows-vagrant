packer {
  required_plugins {
    windows-update = {
      version = "0.14.1"
      source = "github.com/rgl/windows-update"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "61440"
}

variable "iso_url" {
  type    = string
  default = "https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/22000.318.211104-1236.co_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:684bc16adbd792ef2f7810158a3f387f23bf95e1aee5f16270c5b7f56db753b6"
}

variable "vagrant_box" {
  type = string
}

source "qemu" "windows-11-21h2-uefi-amd64" {
  accelerator  = "kvm"
  machine_type = "q35"
  cpus         = 2
  memory       = 4096
  qemuargs = [
    ["-bios", "/usr/share/ovmf/OVMF.fd"],
    ["-cpu", "host"],
    ["-audiodev", "id=pa,driver=pa"],
    ["-device", "qemu-xhci"],
    ["-device", "virtio-tablet"],
    ["-device", "virtio-scsi-pci,id=scsi0"],
    ["-device", "scsi-hd,bus=scsi0.0,drive=drive0"],
    ["-device", "virtio-net,netdev=user.0"],
    ["-vga", "qxl"],
    ["-device", "virtio-serial-pci"],
    ["-chardev", "socket,path=/tmp/{{ .Name }}-qga.sock,server,nowait,id=qga0"],
    ["-device", "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"],
    ["-chardev", "spicevmc,id=spicechannel0,name=vdagent"],
    ["-device", "virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"],
    ["-spice", "unix,addr=/tmp/{{ .Name }}-spice.socket,disable-ticketing"],
  ]
  boot_wait      = "5s"
  boot_command   = ["<enter>"]
  disk_interface = "virtio-scsi"
  disk_cache     = "unsafe"
  disk_discard   = "unmap"
  disk_size      = var.disk_size
  floppy_files = [
    "windows-11-21h2-uefi/autounattend.xml",
    "winrm.ps1",
    "provision-powershell.ps1",
    "provision-psremoting.ps1",
    "provision-openssh.ps1",
    "drivers/vioserial/w10/amd64/*.cat",
    "drivers/vioserial/w10/amd64/*.inf",
    "drivers/vioserial/w10/amd64/*.sys",
    "drivers/viostor/w10/amd64/*.cat",
    "drivers/viostor/w10/amd64/*.inf",
    "drivers/viostor/w10/amd64/*.sys",
    "drivers/vioscsi/w10/amd64/*.cat",
    "drivers/vioscsi/w10/amd64/*.inf",
    "drivers/vioscsi/w10/amd64/*.sys",
    "drivers/NetKVM/w10/amd64/*.cat",
    "drivers/NetKVM/w10/amd64/*.inf",
    "drivers/NetKVM/w10/amd64/*.sys",
    "drivers/qxldod/w10/amd64/*.cat",
    "drivers/qxldod/w10/amd64/*.inf",
    "drivers/qxldod/w10/amd64/*.sys",
  ]
  format           = "qcow2"
  headless         = true
  net_device       = "virtio-net"
  http_directory   = "."
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  shutdown_command = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator     = "ssh"
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "4h"
}

source "virtualbox-iso" "windows-11-21h2-uefi-amd64" {
  cpus      = 2
  memory    = 4096
  disk_size = var.disk_size
  cd_files = [
    "windows-11-21h2-uefi/autounattend.xml",
    "winrm.ps1",
    "provision-powershell.ps1",
    "provision-psremoting.ps1",
    "provision-openssh.ps1",
  ]
  guest_additions_interface = "sata"
  guest_additions_mode      = "attach"
  guest_os_type             = "Windows10_64"
  hard_drive_interface      = "sata"
  headless                  = true
  iso_url                   = var.iso_url
  iso_checksum              = var.iso_checksum
  iso_interface             = "sata"
  shutdown_command          = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  vboxmanage = [
    ["storagectl", "{{ .Name }}", "--name", "IDE Controller", "--remove"],
    ["modifyvm", "{{ .Name }}", "--firmware", "efi"],
    ["modifyvm", "{{ .Name }}", "--vrde", "off"],
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vboxsvga"],
    ["modifyvm", "{{ .Name }}", "--vram", "128"],
    ["modifyvm", "{{ .Name }}", "--accelerate3d", "on"],
    ["modifyvm", "{{ .Name }}", "--usb", "on"],
    ["modifyvm", "{{ .Name }}", "--mouse", "usbtablet"],
    ["modifyvm", "{{ .Name }}", "--audio", "none"],
    ["modifyvm", "{{ .Name }}", "--nictype1", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype2", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype3", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype4", "82540EM"],
  ]
  boot_wait    = "3s"
  boot_command = ["<up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait>"]
  communicator = "ssh"
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout  = "4h"
}

build {
  sources = [
    "source.qemu.windows-11-21h2-uefi-amd64",
    "source.virtualbox-iso.windows-11-21h2-uefi-amd64"
  ]

  provisioner "powershell" {
    script = "disable-windows-updates.ps1"
  }

  provisioner "powershell" {
    script = "disable-windows-defender.ps1"
  }

  provisioner "powershell" {
    script = "remove-one-drive.ps1"
  }

  provisioner "powershell" {
    script = "remove-apps.ps1"
  }

  provisioner "powershell" {
    only   = ["virtualbox-iso.windows-11-21h2-uefi-amd64"]
    script = "virtualbox-prevent-vboxsrv-resolution-delay.ps1"
  }

  provisioner "powershell" {
    only   = ["qemu.windows-11-21h2-uefi-amd64"]
    script = "provision-guest-tools-qemu-kvm.ps1"
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    only   = ["qemu.windows-11-21h2-uefi-amd64"]
    script = "libvirt-fix-cpu-driver.ps1"
  }

  provisioner "powershell" {
    script = "provision.ps1"
  }

  provisioner "windows-update" {
  }

  provisioner "powershell" {
    script = "enable-remote-desktop.ps1"
  }

  provisioner "powershell" {
    script = "provision-cloudbase-init.ps1"
  }

  provisioner "powershell" {
    script = "eject-media.ps1"
  }

  provisioner "powershell" {
    script = "optimize.ps1"
  }

  post-processor "vagrant" {
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile-uefi.template"
  }
}
