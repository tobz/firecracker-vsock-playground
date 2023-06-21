#!/bin/sh

# Add some required packages to configure the rootfs.
apk add openrc util-linux file bash

# Set up a login terminal on the serial console (ttyS0) and add a new user
# so that we have something to log in with:
ln -s agetty /etc/init.d/agetty.ttyS0
echo ttyS0 > /etc/securetty
rc-update add agetty.ttyS0 default

adduser -g fc fc
adduser fc wheel
echo "fc:fc" | chpasswd

# Make sure special file systems are mounted on boot:
rc-update add devfs boot
rc-update add procfs boot
rc-update add sysfs boot

# Move our guest-runner init script into place and enable the service:
cp /build/guest-runner-init-script /etc/init.d/guest-runner
rc-update add guest-runner default

# Then, copy the newly configured system to the rootfs image:
for d in bin etc lib root sbin usr; do tar c "/$d" | tar x -C /rootfs; done
for dir in dev proc run sys var; do mkdir /rootfs/${dir}; done