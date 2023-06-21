# firecracker-vsock-playground

## quick start

```shell
# build the guest-runner application and its microVM image:
tooling/build.sh

# run the microVM using that image:
tooling/run.sh

# send a request to guest-runner, which is running in the microVM, and get back the output:
tooling/send-request.sh
```
