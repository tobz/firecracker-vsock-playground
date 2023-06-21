#!/usr/bin/bash

set -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BIN_DIR="${SCRIPT_DIR}/bin"
OUTPUT_DIR="${SCRIPT_DIR}/output"
TMP_DIR="${SCRIPT_DIR}/tmp"
RO_DRIVE="${OUTPUT_DIR}/rootfs.ext4"
KERNEL="${OUTPUT_DIR}/vmlinux-5.10.bin"
TARGET="$(uname -m)"
FC_VERSION="v1.3.3"
FC_BIN="${BIN_DIR}/firecracker"
API_SOCKET="/tmp/fc-firesmacker-api.sock"
VSOCK_SOCKET="/tmp/fc-firesmacker-vsock.sock"

download_firecracker() {
    TMP_FOLDER="${TMP_DIR}/firecracker"
    TMP_ARCHIVE="${TMP_DIR}/firecracker.tgz"

    wget -q "https://github.com/firecracker-microvm/firecracker/releases/download/${FC_VERSION}/firecracker-${FC_VERSION}-${TARGET}.tgz" \
	  -O "${TMP_ARCHIVE}"

    mkdir -p "${TMP_FOLDER}" "${BIN_DIR}"
    tar -zxf "${TMP_ARCHIVE}" -C "${TMP_FOLDER}"
    cp "$(find "${TMP_FOLDER}" -name "firecracker*${TARGET}")" "${FC_BIN}"
    chmod +x "${FC_BIN}"

    rm -rf "${TMP_FOLDER}"
    rm "${TMP_ARCHIVE}"
}

API_SOCKET="/tmp/firecracker.sock"
CURL=(curl --silent --show-error --header "Content-Type: application/json" --unix-socket "${API_SOCKET}" --write-out "HTTP %{http_code}")

curl_put() {
    local URL_PATH="$1"
    local OUTPUT RC
    OUTPUT="$("${CURL[@]}" -X PUT --data @- "http://localhost/${URL_PATH#/}" 2>&1)"
    RC="$?"
    if [ "$RC" -ne 0 ]; then
        echo "Error: curl PUT ${URL_PATH} failed with exit code $RC, output:"
        echo "$OUTPUT"
        return 1
    fi
    # Error if output doesn't end with "HTTP 2xx"
    if [[ "$OUTPUT" != *HTTP\ 2[0-9][0-9] ]]; then
        echo "Error: curl PUT ${URL_PATH} failed with non-2xx HTTP status code, output:"
        echo "$OUTPUT"
        return 1
    fi
}

# Ensure we have Firecracker.
if [ ! -f "${FC_BIN}" ]; then
  download_firecracker
fi

# Ensure we have the necessary build artifacts.
if [ ! -f "${OUTPUT_DIR}/rootfs.ext4" ]; then
  echo "No rootfs image found. Please run ./build.sh first."
  exit 1
fi

if [ ! -f "${OUTPUT_DIR}/vmlinux-5.10.bin" ]; then
  echo "No kernel image found. Please run ./build.sh first."
  exit 1
fi

# Run Firecracker with our rootfs image and kernel.
CURL=(curl --silent --show-error --header "Content-Type: application/json" --unix-socket "${API_SOCKET}" --write-out "HTTP %{http_code}")

curl_put() {
    local URL_PATH="$1"
    local OUTPUT RC
    OUTPUT="$("${CURL[@]}" -X PUT --data @- "http://localhost/${URL_PATH#/}" 2>&1)"
    RC="$?"
    if [ "${RC}" -ne 0 ]; then
        echo "Error: curl PUT ${URL_PATH} failed with exit code ${RC}, output:"
        echo "${OUTPUT}"
        return 1
    fi
    # Error if output doesn't end with "HTTP 2xx"
    if [[ "${OUTPUT}" != *HTTP\ 2[0-9][0-9] ]]; then
        echo "Error: curl PUT ${URL_PATH} failed with non-2xx HTTP status code, output:"
        echo "${OUTPUT}"
        return 1
    fi
}

# Make sure the log and metrics files exist.
logfile="/tmp/fc-firesmacker-log"
metricsfile="/tmp/fc-firesmacker-metrics"

touch "${logfile}"
touch "${metricsfile}"

KERNEL_BOOT_ARGS="panic=1 pci=off nomodules reboot=k tsc=reliable quiet console=ttyS0 i8042.nokbd i8042.noaux 8250.nr_uarts=0 ipv6.disable=1"

# Start the Firecracker API server so we can configure the microVM.
rm -f "${API_SOCKET}"
"${FC_BIN}" --api-sock "${API_SOCKET}" --id firesmacker --boot-timer >> "${logfile}" &

sleep 0.015s

# Wait for API server to start.
while [ ! -e "${API_SOCKET}" ]; do
    echo "FC 'firesmacker' still not ready..."
    sleep 0.01s
done

curl_put '/logger' <<EOF
{
  "level": "Info",
  "log_path": "${logfile}",
  "show_level": false,
  "show_log_origin": false
}
EOF

curl_put '/metrics' <<EOF
{ "metrics_path": "${metricsfile}" }
EOF

curl_put '/boot-source' <<EOF
{
  "kernel_image_path": "${KERNEL}",
  "boot_args": "${KERNEL_BOOT_ARGS}"
}
EOF

curl_put '/drives/1' <<EOF
{
  "drive_id": "1",
  "path_on_host": "${RO_DRIVE}",
  "is_root_device": true,
  "is_read_only": true
}
EOF

curl_put '/vsock' <<EOF
{
	"guest_cid": 3,
	"uds_path": "${VSOCK_SOCKET}"
}
EOF

curl_put '/actions' <<EOF
{ "action_type": "InstanceStart" }
EOF
