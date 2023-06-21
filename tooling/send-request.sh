#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
VSOCK_PATH="${SCRIPT_DIR}/tmp/fc-firesmacker-vsock.sock"

pushd ${SCRIPT_DIR}/..
cargo build --release --package host-controller
VSOCK_PATH="${VSOCK_PATH}" target/release/host-controller
popd
