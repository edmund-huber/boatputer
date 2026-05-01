variable "image_date" {
  default = "2024-11-19"
}

variable "output_image" {
  default = "output/boatputer.img" # /build/output is mounted to the repo root
}

variable "image_size" {
  default = "4G"
}

locals {
  base     = "2024-11-19-raspios-bookworm-arm64-lite"
  base_url = "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-${var.image_date}"
}

source "arm" "raspios" {
  file_urls             = ["${local.base_url}/${local.base}.img.xz"]
  file_checksum_url     = "${local.base_url}/${local.base}.img.xz.sha256"
  file_checksum_type    = "sha256"
  file_target_extension = "xz"
  file_unarchive_cmd    = ["xz", "--decompress", "$ARCHIVE_PATH"]

  image_build_method = "reuse"
  image_path         = var.output_image
  image_size         = var.image_size
  image_type         = "dos"

  image_partitions {
    name         = "boot"
    type         = "c"
    start_sector = "8192"
    filesystem   = "vfat"
    size         = "256M"
    mountpoint   = "/boot/firmware"
  }

  image_partitions {
    name         = "root"
    type         = "83"
    start_sector = "532480"
    filesystem   = "ext4"
    size         = "0"
    mountpoint   = "/"
  }

  image_chroot_env = [
    "PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin",
    "DEBIAN_FRONTEND=noninteractive",
  ]

  qemu_binary_source_path      = "/usr/bin/qemu-aarch64-static"
  qemu_binary_destination_path = "/usr/bin/qemu-aarch64-static"
}

build {
  sources = ["source.arm.raspios"]

  provisioner "shell" {
    script = "scripts/setup.sh"
  }
}
