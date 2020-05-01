# vagrant-docker-osx

This is the equivalent of a vagrant base box for vagrant's docker
provider. Since it runs in a hypervisor it may be faster than
solutions like VirtualBox that emulate the entire machine.

Tested in Docker Desktop on OSX.

This also demonstrates building a yum cache in one stage of a multistage
build, then installing from that cache in another stage, avoiding both network
traffic and bloat in the final image.

## Project setup
Requires buildkit. Export DOCKER_BUILDKIT=1 or add
`{ "features": { "buildkit": true } }` to the configuration.

```
export DOCKER_BUILDKIT=1
vagrant up --provider=docker
```
