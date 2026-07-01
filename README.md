# This is a K8-cluster deployment project. This set up was done with Windows WSL  

- We are deploying a kubernetes cluster using 3 VMs provisioned by Vagrant and ansible for configuration.

        - Step 1: Update and Upgrade Ubuntu (all nodes)
        - Step 2: Disable Swap (all nodes)
        - Step 3: Add Kernel Parameters (all nodes)
        - Step 4: Install Containerd Runtime (all nodes)
        - Step 5: Add Apt Repository for Kubernetes (all nodes)
        - Step 6: Install Kubectl, Kubeadm, and Kubelet (all nodes)
        - Step 7: Initialize Kubernetes Cluster with Kubeadm (master node)
        - Step 8: Add Worker Nodes to the Cluster (worker nodes)
        - Step 9: Install Kubernetes Network Plugin (master node)
        - Step 10: Verify the cluster and test (master node)

## Below command would be used for the VM provisioning

        ```bash
        vagrant plugin install vagrant-vmware-desktop       | Make sure vm ware plug in is installed
        vagrant up     | vagran.exe up                      | Make sure to kepp VB open during this run
        vagrant up --provider=vmware_desktop                | To use vm ware workstation 
        ./start-cluster.sh                                  | Would provision the cluster end to end joining all nodes 
        ```

## Use below command to start up the infra

        ```bash 
        cd ansible
        ansible-playbook -i inventory.ini playbook.yml
        ```

## Once deplooyment is completed: export the kube config file

        ```bash
        export KUBECONFIG=/etc/kubernetes/admin.conf

        kubeadm init \
        --apiserver-advertise-address=192.168.56.13 \
        --pod-network-cidr=192.168.0.0/16 \
        --kubernetes-version=1.28.15 \
        --cri-socket=unix:///run/containerd/containerd.sock | tee /root/kubeadm-init.out
        ```

## Steps to add worker node to cluster

    - On the master node, copy the admin kubeconfig to a shared location:

        ```bash
        sudo cp /etc/kubernetes/admin.conf /home/vagrant/admin.conf                 | Used to copy the admin kube config file
        sudo chown vagrant:vagrant /home/vagrant/admin.conf                         | Used to change ownership 
        ```

    - On the worker node, create the .kube directory and copy the config:

        ```bash
        mkdir -p $HOME/.kube
        scp vagrant@192.168.56.13:/home/vagrant/admin.conf $HOME/.kube/config                           | Used to copy kube config file to worker node home dir. 
        ssh -i /home/pumej/Documents/k8s-cluster/.vagrant/machines/master-node/virtualbox/private_key vagrant@192.168.56.10               | Used to log in using private key
        chmod 600 ~/Documents/k8s-cluster/.vagrant/machines/*/virtualbox/private_key                    | Used to set right permissions for ansible to work
        ssh-keygen -f '/home/pumej/.ssh/known_hosts' -R '192.168.56.13'                                 | Used to remove the previous key 
        ```

    - Use the below command to generate the token and command for worker node to join the cluster 

        ```bash
        kubeadm token create --print-join-command                                   | Used to output the script to run to join a cluster
        kubectl label node worker-node1 node-role.kubernetes.io/worker=worker       | Used to label a node status correct.
        ```


    - Use the below command sequence to reset your cluster and remove the config set up 

        ```bash
        sudo kubeadm reset -f                           | Used to reset cluster so you can reinitialize it
        sudo rm -rf /etc/kubernetes
        sudo rm -f /home/vagrant/kubeadm-join.sh
        sudo rm -rf ~/.kube /etc/kubernetes /var/lib/etcd /var/lib/kubelet /etc/cni/net.d
        sudo systemctl restart containerd
        ```
    - To run the cluster from your terminal, need to configure the kube context using below command: 

        ```bash
        kubectl config get-contexts
        kubectl config current-context
        kubectl config use-context <context-name>
        az aks get-credentials --resource-group <resource-group> --name <cluster-name> --overwrite-existing
        aws eks update-kubeconfig --region <region> --name <cluster-name>
        gcloud container clusters get-credentials <cluster-name> --region <region> --project <project-id>
        ```
