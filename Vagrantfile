
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # Ubuntu 22.04 LTS for both Kubernetes nodes.
  config.vm.box = "ubuntu/jammy64"

  # Maintain hostname entries on the host.
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true

  # --------------------------------------------------
  # Kubernetes Control Plane
  # --------------------------------------------------
  config.vm.define "master-node" do |node|

    node.vm.hostname = "master-node"

    # Adapter 2: Existing bridged network.
    # Preserve the current Kubernetes API address.
    node.vm.network "public_network", ip: "192.168.1.120"

    # Adapter 3: New host-only management network.
    # Uses the existing 10.3.0.0/24 VirtualBox network.
    node.vm.network "private_network",
      ip: "10.3.0.10",
      name: "VirtualBox Host-Only Ethernet Adapter #2"

    node.vm.synced_folder ".", "/vagrant", disabled: true

    node.vm.provider :virtualbox do |vb|
      vb.memory = 6144
      vb.cpus = 2
    end

    # Install Python for Ansible management.
    node.vm.provision "shell", inline: <<-SHELL
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get upgrade -yq
      apt-get install -y python3 python3-pip python-is-python3
    SHELL
  end

  # --------------------------------------------------
  # Kubernetes Worker Node 1
  # --------------------------------------------------
  config.vm.define "worker-node1" do |node|

    node.vm.hostname = "worker-node1"

    # Adapter 2: Existing bridged network.
    node.vm.network "public_network", ip: "192.168.1.121"

    # Adapter 3: New host-only management network.
    node.vm.network "private_network",
      ip: "10.3.0.11",
      name: "VirtualBox Host-Only Ethernet Adapter #2"

    node.vm.synced_folder ".", "/vagrant", disabled: true

    node.vm.provider :virtualbox do |vb|
      vb.memory = 4096
      vb.cpus = 2
    end

    # Install Python for Ansible management.
    node.vm.provision "shell", inline: <<-SHELL
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get upgrade -yq
      apt-get install -y python3 python3-pip python-is-python3
    SHELL
  end

end
