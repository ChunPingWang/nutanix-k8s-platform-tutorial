# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# NKP PoC 方案 B - VirtualBox VM 定義
# 建立 3 個 VM：1 Management Cluster + 2 Workload Cluster Nodes
#

# VM 規格配置
VM_SPECS = {
  mgmt: {
    hostname: "mgmt",
    ip: "192.168.56.10",
    memory: 16384,
    cpus: 4,
    disk_size: 80  # GB
  },
  workload1: {
    hostname: "workload-1",
    ip: "192.168.56.21",
    memory: 8192,
    cpus: 2,
    disk_size: 60
  },
  workload2: {
    hostname: "workload-2",
    ip: "192.168.56.22",
    memory: 8192,
    cpus: 2,
    disk_size: 60
  }
}

# 共用 shell provisioner: 基礎設定
$base_script = <<-SHELL
  # 設定 timezone
  timedatectl set-timezone Asia/Taipei

  # 更新 apt cache
  apt-get update -qq

  # 安裝基本工具
  apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    jq \
    tree \
    net-tools \
    socat \
    conntrack \
    ipset \
    nfs-common \
    bash-completion \
    > /dev/null 2>&1

  echo "Base packages installed."
SHELL

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_version = ">= 20240101.0.0"

  # 全域 VirtualBox 設定
  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  # 停用預設 synced folder（避免 VirtualBox Guest Additions 問題）
  config.vm.synced_folder ".", "/vagrant", disabled: false

  # --- Management Cluster Node ---
  config.vm.define "mgmt", primary: true do |node|
    spec = VM_SPECS[:mgmt]
    node.vm.hostname = spec[:hostname]
    node.vm.network "private_network", ip: spec[:ip]

    node.vm.provider "virtualbox" do |vb|
      vb.name = "nkp-poc-#{spec[:hostname]}"
      vb.memory = spec[:memory]
      vb.cpus = spec[:cpus]
    end

    node.vm.provision "shell", inline: $base_script

    # 在最後一個 VM 建立完後，觸發 Ansible provisioner
    # （或可在所有 VM 建立完後手動跑 ansible-playbook）
  end

  # --- Workload Cluster Nodes ---
  (1..2).each do |i|
    spec_key = "workload#{i}".to_sym
    spec = VM_SPECS[spec_key]

    config.vm.define spec[:hostname] do |node|
      node.vm.hostname = spec[:hostname]
      node.vm.network "private_network", ip: spec[:ip]

      node.vm.provider "virtualbox" do |vb|
        vb.name = "nkp-poc-#{spec[:hostname]}"
        vb.memory = spec[:memory]
        vb.cpus = spec[:cpus]
      end

      node.vm.provision "shell", inline: $base_script
    end
  end
end
