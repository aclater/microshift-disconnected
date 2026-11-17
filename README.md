# MicroShift, disconnected, three nodes

Ansible playbooks that deploy Red Hat build of MicroShift 4.22 on three RHEL 9.8 virtual machines that have no
route to the internet. Everything installed comes from Red Hat subscription content: RHEL, the MicroShift RPM
repositories, Red Hat's container registries and Red Hat's mirror registry installer. Nothing comes from a
community build.

> **Support status.** Red Hat supports MicroShift as a single node. Joining nodes into one cluster
> (`microshift add-node`) ships in the Red Hat RPMs, but Red Hat's documentation states that multi-node is not
> supported, and the MicroShift project describes it as a setup for testing only. This lab builds one control-plane
> node and two workers that way. For a supported three-node
> cluster, use a three-node OpenShift cluster; for supported MicroShift, run each node on its own
> (see [Three single nodes instead](#three-single-nodes-instead)).

## How it works

| Step | Where | What happens |
|---|---|---|
| `prepare.yml` | connected | A temporary, registered RHEL VM downloads the MicroShift RPMs with their dependencies, the container images and the mirror registry installer, packs them into one bundle file, unregisters and is deleted. |
| `infra.yml` | disconnected | Creates a libvirt network with no way out, and four RHEL VMs on it: `dist`, `node1`, `node2`, `node3`. |
| `dist.yml` | disconnected | Stages the distribution server `dist` from the bundle: a package repository and a container registry holding everything a MicroShift machine is built from. |
| `cluster.yml` | disconnected | Installs MicroShift on the three nodes from `dist`, starts `node1`, joins `node2` and `node3`, and runs a test application with one pod on each node. |

Only `dist` ever sees the bundle. Every other machine installs from `dist`, so more MicroShift machines can be built
later without another trip outside (see [Build another machine](#build-another-machine)).

In a real disconnected site, run `prepare.yml` on a connected machine, carry
`~/.local/share/microshift-lab/bundle/microshift-bundle.tar` across, and run the other playbooks there.

## Before you start

A Linux workstation with KVM and at least 20 GiB of free memory, and these packages:

```
sudo dnf install ansible-core libvirt qemu-kvm virt-install
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"
```

Log out and in again after the last command. Membership of the `libvirt` group lets a user manage every VM on the
workstation, which is equivalent to root access.

The playbooks keep everything in `~/.local/share/microshift-lab`, readable only by you. So that libvirt can open
the VM disks there, they give the `qemu` user permission to pass through (not list or read) each folder above the
disks, up to your home folder, where it does not have it already. `teardown.yml` leaves that permission in place.

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
ansible-playbook dist.yml
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

## The distribution server

`dist.microshift.internal` serves:

| What | Where |
|---|---|
| RPM repository: MicroShift and its dependencies | `http://dist.microshift.internal/bundle/rpms` |
| Container registry (mirror registry for Red Hat OpenShift): the MicroShift release images | `https://dist.microshift.internal:8443`, pulls need no login |
| Image signatures for images Red Hat signs | `http://dist.microshift.internal/sigstore` |
| Settings a client needs | `http://dist.microshift.internal/client/` |

Pushing to the registry needs its administrator login, `init`. Its password is generated on the first run and kept
in `~/.local/share/microshift-lab/registry-password`; only `dist.yml` uses it, and no other machine receives it.

The playbooks deliver the client settings to the nodes over SSH.

## Build another machine

Any RHEL 9.8 machine on the disconnected network, started from the same guest image, becomes a single-node
MicroShift machine with the four files under `/client/` and one install. These commands fetch the settings,
including the certificate authority the machine will trust, over plain HTTP: use them only where you trust every
machine on the disconnected network, and copy the files by another route otherwise. As root on that machine:

```
curl -o /etc/yum.repos.d/microshift-dist.repo http://dist.microshift.internal/client/microshift-dist.repo
curl -o /etc/pki/ca-trust/source/anchors/microshift-dist.pem http://dist.microshift.internal/client/rootCA.pem
update-ca-trust
dnf install -y --disablerepo=* --enablerepo=microshift-dist microshift openshift-clients
curl -o /etc/containers/registries.conf.d/microshift-dist.conf http://dist.microshift.internal/client/registries.conf
curl -o /etc/containers/registries.d/microshift-dist.yaml http://dist.microshift.internal/client/registries.d.yaml
systemctl enable --now microshift
```

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

If `prepare.yml` stops part-way, run `teardown.yml` before trying again: it releases the prep VM's registration
with Red Hat and removes the VM.

## What was tested

Run on MicroShift 4.22.20 and the RHEL 9.8 guest image, on a Fedora workstation with libvirt:

| Step | Result | Time |
|---|---|---|
| `prepare.yml` | Bundle of 2.0 GiB: 83 RPMs, 10 images, the registry installer. The prep VM is unregistered and removed. | 3 min |
| `infra.yml` | Network with no route out, four VMs | under 1 min |
| `dist.yml` | Repository, registry and signatures served | 3 min |
| `cluster.yml` | Three `Ready` nodes, one test pod on each, pods reach each other across nodes; a second run changes nothing | 7 min |
| `cluster.yml -e multinode=false` | Three separate single-node MicroShifts, a test pod on each | 7 min |
| Build another machine | The commands above, typed on a fresh VM, give a running single-node MicroShift | |
| Restart | After shutting down and starting all four VMs the cluster and the registry come back | |
| `teardown.yml` | No VMs, disks or networks left | under 1 min |

The runs used other network names, addresses and input file locations than the defaults, set with `-e`.

Not tested:

- the `dnf install` and `usermod` lines under "Before you start" (the test workstation already had the packages);
- carrying the bundle to a physically separate site: `prepare.yml` and the other playbooks ran on the same workstation;
- any guest image other than RHEL 9.8, or any MicroShift release other than 4.22;
- updating a running cluster from a newer bundle.

## Settings

Names, addresses, VM sizes and versions are in [group_vars/all.yml](group_vars/all.yml). Why things are done this
way is in [DECISIONS.md](DECISIONS.md).

## Licence

Apache-2.0. Not an official Red Hat product or document.
