# MicroShift, disconnected, three nodes

Ansible playbooks that deploy Red Hat build of MicroShift 4.22 on three RHEL 9.8 virtual machines that have no
route to the internet. Everything installed comes from Red Hat subscription content: RHEL, the MicroShift RPM
repositories and Red Hat's container registries. Nothing comes from a community build.

> **Support status.** Red Hat supports MicroShift as a single node. Joining nodes into one cluster
> (`microshift add-node`) ships in the Red Hat RPMs, but Red Hat's documentation describes it as a test setup, not
> a supported one. This lab builds one control-plane node and two workers that way. For a supported three-node
> cluster, use a three-node OpenShift cluster; for supported MicroShift, run each node on its own
> (see [Three single nodes instead](#three-single-nodes-instead)).

## Status

Work in progress. The playbooks are being run end to end now; open issues track what is and is not validated yet.

## How it works

| Step | Where | What happens |
|---|---|---|
| `prepare.yml` | connected | A temporary, registered RHEL VM downloads the MicroShift RPMs with their dependencies and the container images, packs them into one bundle file, unregisters and is deleted. |
| `infra.yml` | disconnected | Creates a libvirt network with no way out and three RHEL VMs on it. |
| `cluster.yml` | disconnected | Copies the bundle to each node, installs MicroShift from it, loads the images into each node's container storage, starts `node1`, joins `node2` and `node3`, and runs a test application with one pod on each node. |

No registry and no package mirror run in the disconnected network: each node installs from the bundle's package
repository on its own disk and finds every image already in its local storage.

In a real disconnected site, run `prepare.yml` on a connected machine, carry
`~/.local/share/microshift-lab/bundle/microshift-bundle.tar` across, and run the other two playbooks there.

## Before you start

A Linux workstation with KVM and at least 16 GiB of free memory, and these packages:

```
sudo dnf install ansible-core libvirt qemu-kvm virt-install
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"
```

Log out and in again after the last command.

Three things from your Red Hat account, saved under `~/.local/share/microshift-lab/inputs/`:

| File | What it is | Where to get it |
|---|---|---|
| `rhel-9.8-x86_64-kvm.qcow2` | RHEL 9.8 KVM guest image | access.redhat.com, Downloads, Red Hat Enterprise Linux 9.8 |
| `pull-secret.json` | Pull secret | console.redhat.com/openshift/install/pull-secret |
| `rhsm-activation` | Organization ID and activation key | console.redhat.com, Subscriptions, Activation keys |

`rhsm-activation` is a text file with two lines. Replace the values with your own:

```
org=1234567
key=my-activation-key
```

Your account needs a subscription that includes MicroShift: Red Hat Device Edge or Red Hat OpenShift.

## Quick start

```
mkdir -p ~/.local/share/microshift-lab/inputs
```

Copy the three files above into that folder. Then:

```
git clone https://github.com/aclater/microshift-disconnected.git
cd microshift-disconnected
ansible-playbook prepare.yml
ansible-playbook infra.yml
ansible-playbook cluster.yml
```

`cluster.yml` ends by listing three `Ready` nodes and three running `hello` pods, one per node.

## Use the cluster

```
ssh -F ~/.local/share/microshift-lab/ssh_config node1
oc get nodes
oc get pods -A -o wide
```

## Check that it is disconnected

```
ssh -F ~/.local/share/microshift-lab/ssh_config node1
curl --max-time 5 https://registry.redhat.io
```

The `curl` command fails: the network has no route out.

## Three single nodes instead

To stay within what Red Hat supports, run MicroShift on each VM separately:

```
ansible-playbook cluster.yml -e multinode=false
```

Each node is then its own single-node MicroShift, and the test application runs on each one.

## Remove everything

```
ansible-playbook teardown.yml
```

This removes the VMs, their disks and the networks. The bundle and your three input files stay.

## Settings

Names, addresses, VM sizes and versions are in [group_vars/all.yml](group_vars/all.yml). Why things are done this
way is in [DECISIONS.md](DECISIONS.md).

## Licence

Apache-2.0. Not an official Red Hat product or document.
