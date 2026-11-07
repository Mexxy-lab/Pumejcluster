# Kubernetes Cluster Upgrade Guide

## Upgrade History: v1.28.15 → v1.29.15 → v1.30.14

This document describes the step-by-step process used to upgrade a two-node Kubernetes cluster using `kubeadm`, from Kubernetes v1.28.15 to v1.30.14.

The upgrade was performed one minor version at a time, following Kubernetes upgrade best practices:

1. Upgrade the control-plane node.
2. Upgrade the worker node.
3. Verify that both nodes are healthy.
4. Verify that application workloads and cluster services are running.

The upgrade was completed successfully, and all workloads were healthy after the v1.30.14 upgrade.

---

## 1. Cluster Environment

### Infrastructure

The Kubernetes cluster consists of two Ubuntu virtual machines.

| Component | Master Node | Worker Node |
| --- | --- | --- |
| Hostname | master-node | worker-node1 |
| Role | Control plane | Worker |
| IP address | 192.168.1.120 | 192.168.1.121 |
| Operating system | Ubuntu 22.04.5 LTS | Ubuntu 22.04.5 LTS |
| Container runtime | containerd 1.6.27 | containerd 1.6.27 |
| Initial Kubernetes version | v1.28.15 | v1.28.15 |

### Software versions

| Component | Version |
| --- | --- |
| Kubernetes initial version | v1.28.15 |
| Kubernetes final version | v1.30.14 |
| kubeadm | v1.30.14 |
| kubelet | v1.30.14 |
| kubectl | v1.30.14 |
| Helm | v3.19.4 |
| Container runtime | containerd 1.6.27 |
| Operating system | Ubuntu 22.04.5 LTS |

### Cluster workloads

The cluster hosts the following applications and infrastructure services:

- Amazon Clone application
- Argo CD
- cert-manager
- cloudflared
- Calico networking
- CoreDNS
- MetalLB
- Traefik ingress controller
- Kubernetes control-plane components

---

## 2. Kubernetes Upgrade Strategy

Kubernetes supports upgrading between consecutive minor versions. Therefore, the cluster was upgraded in two stages.

| Stage | Source version | Target version | Status |
| --- | --- | --- | --- |
| Stage 1 | v1.28.15 | v1.29.15 | Completed |
| Stage 2 | v1.29.15 | v1.30.14 | Completed |
| Stage 3 | v1.30.14 | v1.31.x | Not started |

The control-plane node must be upgraded before the worker node.

### Important considerations

- Upgrade one minor version at a time.
- Upgrade kubeadm before running the cluster upgrade.
- Upgrade the control-plane node before worker nodes.
- Drain the worker before upgrading its Kubernetes components.
- Upgrade kubelet and kubectl to the target version.
- Restart kubelet after upgrading its package.
- Uncordon the worker after the upgrade.
- Verify workloads before proceeding to another Kubernetes version.

---

## 3. Stage 1: Upgrade Kubernetes v1.28.15 to v1.29.15

## 3.1 Upgrade the master node

All commands in this section were executed on `master-node`.

### Step 1: Update the Kubernetes APT repository

The Kubernetes package repository was changed from v1.28 to v1.29.

```bash
sudo sed -i 's/v1.28/v1.29/' /etc/apt/sources.list.d/kubernetes.list
```

Update the package index:

```bash
sudo apt update
```

### Step 2: Check available package versions

```bash
apt-cache madison kubeadm
apt-cache madison kubectl
apt-cache madison kubelet
```

Confirm that the target version is available:

```text
1.29.15-1.1
```

### Step 3: Upgrade kubeadm

Remove the package hold:

```bash
sudo apt-mark unhold kubeadm
```

Install the required version:

```bash
sudo apt-get install -y kubeadm=1.29.15-1.1
```

Hold the package again:

```bash
sudo apt-mark hold kubeadm
```

Verify the installed version:

```bash
kubeadm version
```

Expected result:

```text
v1.29.15
```

### Step 4: Review the upgrade plan

```bash
sudo kubeadm upgrade plan
```

This command checks the cluster's current version and available upgrade targets.

Review the output before proceeding.

### Step 5: Upgrade the Kubernetes control plane

```bash
sudo kubeadm upgrade apply v1.29.15
```

Confirm the upgrade when prompted.

Wait for the command to finish successfully.

### Step 6: Upgrade kubectl and kubelet

Unhold both packages:

```bash
sudo apt-mark unhold kubectl kubelet
```

Install the target versions:

```bash
sudo apt-get install -y kubectl=1.29.15-1.1 kubelet=1.29.15-1.1
```

Hold the packages:

```bash
sudo apt-mark hold kubectl kubelet
```

Reload systemd and restart kubelet:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Verify the versions:

```bash
kubeadm version
kubectl version
kubelet --version
```

The master node should now be running Kubernetes v1.29.15.

---

## 3.2 Upgrade the worker node

Before upgrading the worker, return to the master node.

### Step 1: Drain the worker node

Run:

```bash
kubectl drain worker-node1 --ignore-daemonsets --delete-emptydir-data
```

This command:

- Marks the worker as unschedulable.
- Evicts eligible application pods.
- Allows workloads to be rescheduled elsewhere when possible.
- Leaves DaemonSet-managed pods in place.

**Important:** The `--delete-emptydir-data` option permits eviction of pods using ephemeral `emptyDir` storage. Data stored there can be lost. Ensure that this is acceptable before draining.

Verify the worker is cordoned:

```bash
kubectl get nodes
```

The worker should show:

```text
SchedulingDisabled
```

### Step 2: Update the Kubernetes APT repository on the worker

Switch to the worker terminal:

```bash
sudo sed -i 's/v1.28/v1.29/' /etc/apt/sources.list.d/kubernetes.list
```

Update package information:

```bash
sudo apt update
```

Check the available versions:

```bash
apt-cache madison kubeadm
apt-cache madison kubectl
apt-cache madison kubelet
```

Step 3: Upgrade kubeadm

```bash
sudo apt-mark unhold kubeadm

sudo apt-get install -y kubeadm=1.29.15-1.1

sudo apt-mark hold kubeadm
```

Verify:

```bash
kubeadm version
```

### Step 4: Upgrade the worker node configuration

Run:

```bash
sudo kubeadm upgrade node
```

This updates the local Kubernetes node configuration.

### Step 5: Upgrade kubectl and kubelet

```bash
sudo apt-mark unhold kubectl kubelet

sudo apt-get install -y kubectl=1.29.15-1.1 kubelet=1.29.15-1.1

sudo apt-mark hold kubectl kubelet
```

Restart kubelet:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Verify:

```bash
kubeadm version
kubectl version
kubelet --version
```

### Step 6: Return to the master and uncordon the worker

From the master node:

```bash
kubectl uncordon worker-node1
```

Verify:

```bash
kubectl get nodes -o wide
```

Both nodes should now report v1.29.15 and be Ready.

---

## 4. Stage 2: Upgrade Kubernetes v1.29.15 to v1.30.14

The same upgrade procedure was followed for the next minor release.

## 4.1 Upgrade the master node

Step 1: Update the Kubernetes APT repository

On `master-node`:

```bash
sudo sed -i 's/v1.29/v1.30/' /etc/apt/sources.list.d/kubernetes.list

sudo apt update
```

Check available package versions:

```bash
apt-cache madison kubeadm
apt-cache madison kubectl
apt-cache madison kubelet
```

The target version should be:

```text
1.30.14-1.1
```

### Step 2: Upgrade kubeadm

```bash
sudo apt-mark unhold kubeadm

sudo apt-get install -y kubeadm=1.30.14-1.1

sudo apt-mark hold kubeadm
```

Verify:

```bash
kubeadm version
```

Expected:

```text
v1.30.14
```

### Step 3: Review the upgrade plan

```bash
sudo kubeadm upgrade plan
```

Review the proposed upgrade and component versions.

### Step 4: Upgrade the control plane

```bash
sudo kubeadm upgrade apply v1.30.14
```

The upgrade completed successfully:

```text
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.30.14". Enjoy!
```

Kubeadm also updated the applicable Kubernetes control-plane components and addons.

Step 5: Upgrade kubectl and kubelet

```bash
sudo apt-mark unhold kubectl kubelet

sudo apt-get install -y kubectl=1.30.14-1.1 kubelet=1.30.14-1.1

sudo apt-mark hold kubectl kubelet
```

Restart kubelet:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Verify:

```bash
kubeadm version
kubectl version
kubelet --version
```

---

## 4.2 Upgrade the worker node

### Step 1: Drain the worker

From `master-node`:

```bash
kubectl drain worker-node1 --ignore-daemonsets --delete-emptydir-data
```

Wait for the drain operation to finish.

### Step 2: Update the worker's Kubernetes repository

On `worker-node1`:

```bash
sudo sed -i 's/v1.29/v1.30/' /etc/apt/sources.list.d/kubernetes.list

sudo apt update
```

Check package versions:

```bash
apt-cache madison kubeadm
apt-cache madison kubectl
apt-cache madison kubelet
```

Step 3: Upgrade kubeadm

```bash
sudo apt-mark unhold kubeadm

sudo apt-get install -y kubeadm=1.30.14-1.1

sudo apt-mark hold kubeadm
```

Verify:

```bash
kubeadm version
```

### Step 4: Update the worker node configuration

```bash
sudo kubeadm upgrade node
```

Expected successful message:

```text
The configuration for this node was successfully updated!
```

Step 5: Upgrade kubectl and kubelet

```bash
sudo apt-mark unhold kubectl kubelet

sudo apt-get install -y kubectl=1.30.14-1.1 kubelet=1.30.14-1.1

sudo apt-mark hold kubectl kubelet
```

Restart kubelet:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Verify the versions:

```bash
kubeadm version
kubectl version
kubelet --version
```

### Step 6: Uncordon the worker

From the master node:

```bash
kubectl uncordon worker-node1
```

Verify:

```bash
kubectl get nodes -o wide
```

Expected result:

```text
NAME           STATUS   ROLES           VERSION
master-node    Ready    control-plane   v1.30.14
worker-node1   Ready    <none>          v1.30.14
```

---

## 5. Post-Upgrade Verification

After upgrading both nodes, several checks were performed to confirm the cluster was healthy.

All commands in this section can be executed from either node, provided kubectl has access to the cluster.

## 5.1 Verify Kubernetes node versions

```bash
kubectl get nodes -o wide
```

Expected:

- `master-node` is Ready.
- `worker-node1` is Ready.
- Both nodes report v1.30.14.

## 5.2 Verify all pods

```bash
kubectl get pods -A -o wide
```

This displays pods across all namespaces, including their readiness, status, restart counts, IP addresses, and assigned nodes.

Expected:

- Application pods are Running.
- System pods are Running.
- No pods are stuck in Pending, CrashLoopBackOff, ImagePullBackOff, or Error.

## 5.3 Verify deployments

```bash
kubectl get deployments -A
```

Check that:

- READY matches the desired replica count.
- UP-TO-DATE matches the desired replica count.
- AVAILABLE matches the desired replica count.

For example:

```text
NAMESPACE       NAME                 READY   UP-TO-DATE   AVAILABLE
amazon-clone    amazon-deployment    1/1     1            1
```

## 5.4 Verify StatefulSets

```bash
kubectl get statefulsets -A
```

The Argo CD application controller should report:

```text
READY
1/1
```

## 5.5 Identify unhealthy pods

```bash
kubectl get pods -A | grep -v Running | grep -v Completed
```

If this command returns no results, no pods are currently reporting a status other than Running or Completed.

Note that Completed pods are normally expected for finished Jobs.

## 5.6 Check node conditions

```bash
kubectl describe nodes
```

Review the Conditions section for:

- Ready: True
- MemoryPressure: False
- DiskPressure: False
- PIDPressure: False

## 5.7 Check kubelet service

On each node:

```bash
sudo systemctl status kubelet
```

Confirm that kubelet is active and running.

---

## 6. Final Upgrade Results

The final verification after upgrading to v1.30.14 returned the following results.

### Node status

| Node | Kubernetes version | Status |
| --- | --- | --- |
| master-node | v1.30.14 | Ready |
| worker-node1 | v1.30.14 | Ready |

### Application and infrastructure health

| Namespace | Component | Result |
| --- | --- | --- |
| amazon-clone | Amazon Clone deployment | 1/1 Running |
| argocd | Application controller | 1/1 Running |
| argocd | Applicationset controller | 1/1 Running |
| argocd | Dex server | 1/1 Running |
| argocd | Notifications controller | 1/1 Running |
| argocd | Redis | 1/1 Running |
| argocd | Repo server | 1/1 Running |
| argocd | Argo CD server | 1/1 Running |
| cert-manager | Controller | 1/1 Running |
| cert-manager | CA injector | 1/1 Running |
| cert-manager | Webhook | 1/1 Running |
| cloudflared | Cloudflared | 1/1 Running |
| kube-system | Calico | Running |
| kube-system | CoreDNS | 2/2 Running |
| kube-system | etcd | 1/1 Running |
| kube-system | Kubernetes API server | 1/1 Running |
| kube-system | Controller manager | 1/1 Running |
| kube-system | Scheduler | 1/1 Running |
| kube-system | kube-proxy | Running |
| metallb-system | Controller | 1/1 Running |
| metallb-system | Speakers | Running |
| traefik | Traefik | 1/1 Running |

### Deployment health

All deployments reported their desired replicas as available.

The Argo CD application controller StatefulSet reported:

```text
READY
1/1
```

The unhealthy-pod check returned no results:

```bash
kubectl get pods -A | grep -v Running | grep -v Completed
```

**Final result: The Kubernetes v1.30.14 upgrade was completed successfully.**

---

## 7. Important Notes and Lessons Learned

## 7.1 Kubernetes version compatibility

Kubernetes minor releases should be upgraded sequentially.

This lab followed:

```text
v1.28.15
    |
    v
v1.29.15
    |
    v
v1.30.14
```

Do not skip minor releases when upgrading a kubeadm-managed cluster.

## 7.2 Why kubeadm is upgraded first

The kubeadm binary manages the Kubernetes upgrade process.

It should be upgraded to the target minor version before running:

```bash
sudo kubeadm upgrade plan
```

or:

```bash
sudo kubeadm upgrade apply <target-version>
```

## 7.3 Why the worker is drained

Draining the worker safely evicts eligible workloads before its Kubernetes components are upgraded.

This reduces the risk of abruptly interrupting running workloads.

The worker is returned to service using:

```bash
kubectl uncordon worker-node1
```

## 7.4 DaemonSet pods

Pods managed by DaemonSets, such as Calico, kube-proxy, and MetalLB speakers, are not evicted by a normal drain operation.

This is why the following option is used:

```bash
--ignore-daemonsets
```

These pods remain managed by their DaemonSets and are expected to continue operating.

## 7.5 Package holds

After installing each Kubernetes package, the package was held:

```bash
sudo apt-mark hold kubeadm kubectl kubelet
```

This prevents accidental package upgrades during routine APT operations.

Before installing a new target version, remove the hold for the relevant package:

```bash
sudo apt-mark unhold kubeadm kubectl kubelet
```

After installation, hold them again.

## 7.6 etcd version observation

During the v1.30.14 control-plane upgrade, kubeadm reported that the installed etcd version was:

```text
3.5.16-0
```

The version targeted by the upgrade configuration was:

```text
3.5.15-0
```

Because the installed version was newer, kubeadm skipped the etcd downgrade.

This was a non-fatal message. The etcd pod remained Running and healthy.

**Do not downgrade etcd just to match the older version displayed in the kubeadm upgrade plan.** Any etcd version change should be planned separately, with compatibility checks and a verified backup.

---

## 8. Troubleshooting Reference

### Node remains NotReady

Check:

```bash
kubectl get nodes
kubectl describe node worker-node1
```

On the affected node:

```bash
sudo systemctl status kubelet
sudo journalctl -u kubelet -xe --no-pager
```

### Pod is stuck in Pending

Check:

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Review scheduling events, node resources, taints, and node selectors.

### Pod is in CrashLoopBackOff

Check:

```bash
kubectl logs <pod-name> -n <namespace>
```

For a previously terminated container:

```bash
kubectl logs <pod-name> -n <namespace> --previous
```

Inspect the pod:

```bash
kubectl describe pod <pod-name> -n <namespace>
```

### Worker cannot be drained

Check:

```bash
kubectl get pdb -A
kubectl get pods -A -o wide
```

Review PodDisruptionBudgets and identify workloads that cannot be safely evicted.

Do not bypass disruption protection without understanding the impact.

### Worker does not return to Ready

Check the node:

```bash
kubectl describe node worker-node1
```

Check kubelet:

```bash
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 100 --no-pager
```

Once the underlying problem is resolved, verify that the node is schedulable:

```bash
kubectl uncordon worker-node1
```

---

## 9. Preparation for the Next Upgrade: Kubernetes v1.31

The cluster is currently running v1.30.14.

The next planned upgrade is:

```text
v1.30.14 → v1.31.x
```

Before starting:

1. Review the official Kubernetes v1.31 release notes.
2. Confirm the selected v1.31 patch version is available in the Kubernetes APT repository.
3. Review the Kubernetes upgrade documentation.
4. Back up the etcd datastore.
5. Check the compatibility of cluster add-ons, including Calico, MetalLB, cert-manager, Traefik, and Argo CD.
6. Verify the cluster is healthy.
7. Repeat the same control-plane-first, worker-second upgrade procedure.

Useful official documentation:

- Kubernetes kubeadm upgrade guide: <https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/>
- Kubernetes version skew policy: <https://kubernetes.io/releases/version-skew-policy/>
- Kubernetes release information: <https://kubernetes.io/releases/>

**Do not begin the v1.31 upgrade until the target patch version, add-on compatibility, and backup have been reviewed.**

---

## 10. Final Summary

This lab successfully upgraded a two-node kubeadm-managed Kubernetes cluster through two consecutive minor releases.

| Item | Final result |
| --- | --- |
| Initial Kubernetes version | v1.28.15 |
| Intermediate Kubernetes version | v1.29.15 |
| Final Kubernetes version | v1.30.14 |
| Control-plane upgrade | Successful |
| Worker upgrade | Successful |
| Node readiness | Both nodes Ready |
| Application workloads | Healthy |
| Argo CD | Healthy |
| Cluster networking | Running |
| Ingress controller | Running |
| Unhealthy pods | None |

The upgrade was completed without a reported application or infrastructure workload remaining unhealthy.

## **Current cluster version: Kubernetes v1.30.14**

## **Next planned milestone: Kubernetes v1.31.x**
