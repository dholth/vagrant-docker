# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "centos/8"

  # See https://bitbucket.org/double16/linux-dev-workstation/src/master/Vagrantfile
  config.vm.provider "docker" do |docker, override|
    override.vm.box = nil
    docker.build_dir = "."
    # docker.name must be unique for a host but need not match the Dockerfile
    docker.name = "vagrant-docker"
    docker.remains_running = true
    docker.has_ssh = true
    docker.create_args = ['--tmpfs', '/tmp:exec', '--tmpfs', '/run', '-v', '/sys/fs/cgroup:/sys/fs/cgroup:ro']
  end
end

# Run without vagrant: docker run --tmpfs /tmp:exec --tmpfs /run -v /sys/fs/cgroup:/sys/fs/cgroup:ro vagrant-docker-osx