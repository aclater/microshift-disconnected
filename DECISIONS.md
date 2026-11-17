# Decisions

Each entry: what was decided, why, what else was considered, and the cost.

## RPM install on the RHEL guest image, not an image-mode build
**Decided:** nodes are RHEL 9.8 KVM guest images with MicroShift installed from RPMs.
**Why:** the goal is the shortest path to a running disconnected cluster. An image-mode (bootc) build adds an
image build and a disk build before the first node boots.
**Considered:** image mode with the container images embedded. Better for fleets of devices; slower to a first result.
**Cost:** nodes are not atomic; updates are `dnf` transactions.

## Multi-node through `microshift add-node`
**Decided:** one control-plane node, two workers joined with `microshift add-node`, and a switch
(`multinode=false`) for three separate single nodes.
**Why:** the request was a three-node cluster from supported subscription content. The command ships in the Red Hat
RPMs. Red Hat documents multi-node MicroShift as a test setup and supports single-node only, so the README says so
at the top and offers the supported layout.
**Considered:** a three-node OpenShift cluster (supported, but a different product and far larger).
**Cost:** the default layout is outside Red Hat support. The control plane is not highly available.

## The bundle's package set is resolved against the guest image
**Decided:** the prep VM runs `dnf install --downloadonly` from the same guest image the nodes use.
**Why:** it yields exactly the packages a fresh guest image lacks (a few hundred MB) without mirroring whole repositories.
**Considered:** `reposync` of BaseOS, AppStream and the MicroShift repositories (tens of GB), or a RHEL DVD plus a
partial mirror.
**Cost:** the bundle fits one guest image version. Build a new bundle when the image changes.

## The disconnected network hands out a default route
**Decided:** libvirt's DHCP gives the nodes a default route to the bridge, although nothing is forwarded.
**Why:** MicroShift takes the node address from the interface holding the default route.
**Cost:** none; packets to outside addresses are dropped at the bridge.

## A distribution server inside the disconnected network
**Decided:** one VM, `dist`, is staged from the bundle and serves the RPM repository over HTTP and the images from
a registry. Nodes install only from it.
**Why:** the request was a server from which MicroShift machines can be built offline. It matches Red Hat's
documented disconnected method for package installs (a mirror registry plus a local RPM repository), and new
machines need no further transfer from outside.
**Considered:** copying the bundle to every node and loading the images straight into each node's container
storage. Fewer parts, but every new machine needs the whole bundle again.
**Cost:** one more VM (6 GiB) and a few minutes to install the registry.

## Mirror registry for Red Hat OpenShift as the registry
**Decided:** the registry is Red Hat's mirror registry (a small Quay), installed from its offline installer.
**Why:** it is the Red Hat registry meant for disconnected mirrors and installs with no outside access.
**Considered:** a plain community registry container: lighter, but not Red Hat content.
**Cost:** about 3 GiB of memory on `dist`.

## Image signatures are served by the web server
**Decided:** signatures that come with Red Hat-signed images are stored under `/var/www/html/sigstore` on `dist`,
and clients are pointed there.
**Why:** RHEL's default policy rejects unsigned images from `registry.redhat.io` and `registry.access.redhat.com`,
also when they arrive through a mirror. Keeping the signatures keeps the policy unchanged on every client.
**Considered:** relaxing the policy on the clients.
**Cost:** one more client settings file.

## Clients pull from the registry without a login
**Decided:** repositories in the registry are readable anonymously. The administrator login is generated per lab,
kept in the working folder, and used only on the distribution server to push.
**Why:** the first release gave every node the administrator login, with a fixed password, so any machine on the
network could replace images. Every machine on a disconnected network may read the mirror anyway; none should be
able to write to it.
**Considered:** a pull-only account for clients. It needs the registry's API with a token the installer does not
keep, for no gain over anonymous read on an isolated network.
**Cost:** anyone on the disconnected network can read the mirrored images.

## The playbooks deliver client settings over SSH
**Decided:** `cluster.yml` reads the client settings on the distribution server and copies them to the nodes over
SSH. The same files stay published under `/client/` for machines set up by hand.
**Why:** the settings include the certificate authority a node will trust; fetched over plain HTTP, another machine
on the network could substitute it.
**Cost:** the manual route still uses HTTP, and the README says when that is acceptable.
