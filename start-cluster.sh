#!/bin/bash

set -e  # Exit on first error
set -o pipefail

MASTER_NODE_IP="192.168.1.120"
WORKER_NODE1_IP="192.168.1.121"
# WORKER_NODE2_IP="192.168.1.122"
VAGRANT_KEY_PATH="/home/pumej/Projects/pumej-cluster/.vagrant/machines/master-node/virtualbox/private_key"
LOCAL_KUBECONFIG="$HOME/.kube/config"

echo -e "\n🌐 ===================== KUBERNETES CLUSTER DEPLOYMENT =====================\n"

echo "➡️  Starting up VMs..."
vagrant.exe up --provision

echo -e "\n🔑 Removing old SSH fingerprints..."
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$MASTER_NODE_IP" || true
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$WORKER_NODE1_IP" || true
# ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$WORKER_NODE2_IP" || true

echo -e "\n🔐 Fixing private key permissions..."
chmod 600 /home/pumej/Projects/pumej-cluster/.vagrant/machines/*/virtualbox/private_key

# ✅ Function to check SSH availability
wait_for_ssh() {
  local ip="$1"
  echo -e "\n⏳ Waiting for SSH to become available on $ip..."
  for _ in {1..20}; do
    if nc -z "$ip" 22; then
      echo "✅ SSH is up on $ip"
      return 0
    fi
    sleep 3
  done
  echo "❌ Timed out waiting for SSH on $ip"
  return 1
}

wait_for_ssh "$MASTER_NODE_IP"
wait_for_ssh "$WORKER_NODE1_IP"
# wait_for_ssh "$WORKER_NODE2_IP"

echo -e "\n📡 Checking connectivity to all nodes with Ansible ping..."
if ! ANSIBLE_HOST_KEY_CHECKING=False ansible -i ansible-ubuntu/inventory.ini all -m ping; then
    echo "❌ One or more nodes are unreachable. Check network or SSH access."
    exit 1
fi

echo -e "\n🚀 Running Ansible playbook to deploy the cluster..."
if ! ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible-ubuntu/inventory.ini ansible-ubuntu/playbook.yml; then
  echo "❌ Ansible playbook execution failed."
  exit 1
fi
echo "✅ Ansible playbook executed successfully."

# ==================== NEW SECTION: COPY AND CONFIGURE KUBECONFIG ====================

echo -e "\n📂 Setting up local Kubernetes config from master node..."

# Step 1: Copy admin.conf on master
ssh -i "$VAGRANT_KEY_PATH" -o StrictHostKeyChecking=no vagrant@"$MASTER_NODE_IP" <<'EOF'
  echo "⚙️  Copying admin.conf to home directory..."
  sudo cp /etc/kubernetes/admin.conf /home/vagrant/
  sudo chown vagrant:vagrant /home/vagrant/admin.conf
  echo "✅ admin.conf prepared successfully on master node."
EOF

# Step 2: Copy the file to local machine
echo "⬇️  Transferring admin.conf to local machine..."
mkdir -p ~/.kube
scp -i "$VAGRANT_KEY_PATH" -o StrictHostKeyChecking=no vagrant@"$MASTER_NODE_IP":/home/vagrant/admin.conf "$LOCAL_KUBECONFIG"

# Step 3: Fix local permissions
chmod 600 "$LOCAL_KUBECONFIG"
kubectl label node worker-node1 kubernetes.io/role=worker-node --overwrite

# Step 4: Verify config setup
echo -e "\n🔍 Verifying Kubernetes context..."
if kubectl config current-context &>/dev/null; then
  echo -e "✅ Kubernetes context successfully set to: \e[32m$(kubectl config current-context)\e[0m"
else
  echo "⚠️  Unable to detect current context. Please check your kubeconfig file."
fi

echo -e "\n🎉 ===================== CLUSTER DEPLOYMENT COMPLETE ====================="
echo "✅ Kubeconfig successfully copied to: $LOCAL_KUBECONFIG"
echo "🌿 You can now run: kubectl get nodes"
echo -e "=====================================================================\n"