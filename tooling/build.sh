#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OUTPUT_DIR="${SCRIPT_DIR}/output"
ALPINE_IMAGE="alpine:3.18"

# Unmount any existing rootfs mount from previous runs and remove the rootfs image too
if [ -d "${OUTPUT_DIR}/rootfs" ]; then
  sudo umount -q "${OUTPUT_DIR}/rootfs"
  rm -rf "${OUTPUT_DIR}/rootfs" 
fi

if [ -f $"{OUTPUT_DIR}/rootfs.ext4" ]; then
  rm -f "${OUTPUT_DIR}/rootfs.ext4"
fi

# Create our rootfs image, which involves a scratch file we `dd` to an acceptable size and then
# format as an EXT4 filesystem. This is what we'll copy all of our OS bits and guest-runner into.
dd if=/dev/zero of="${OUTPUT_DIR}/rootfs.ext4" bs=1M count=50
mkfs.ext4 "${OUTPUT_DIR}/rootfs.ext4"

# Mount it so we can put things into it.
mkdir "${OUTPUT_DIR}/rootfs"
sudo mount "${OUTPUT_DIR}/rootfs.ext4" "${OUTPUT_DIR}/rootfs"

# Copy in our OS bits, which we do by using an Alpine base image as our source, and running some
# commands on top of that to configure init for guest-runner and so on.
docker run --rm \
  -v "${OUTPUT_DIR}/rootfs":/rootfs \
  -v "${SCRIPT_DIR}/docker":/build \
  "${ALPINE_IMAGE}" \
  /build/build.sh

# Build guest-runner in release mode and then copy it into the rootfs image.
cargo build --target x86_64-unknown-linux-musl --release --package guest-runner
sudo cp target/x86_64-unknown-linux-musl/release/guest-runner "${OUTPUT_DIR}/rootfs/usr/bin/guest-runner"

# Now unmount the rootfs image and clean up the directory.
sudo umount "${OUTPUT_DIR}/rootfs"
rm -rf "${OUTPUT_DIR}/rootfs"

# Grab the 5.10 kernel from the Firecracker CI artifacts bucket.
wget https://s3.amazonaws.com/spec.ccfc.min/ci-artifacts/kernels/x86_64/vmlinux-5.10.bin \
  -O "${OUTPUT_DIR}/vmlinux-5.10.bin"