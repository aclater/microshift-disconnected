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
**Why:** it yields exactly the packages a fresh node lacks (a few hundred MB) without mirroring whole repositories.
**Considered:** `reposync` of BaseOS, AppStream and the MicroShift repositories (tens of GB), or a RHEL DVD plus a
partial mirror.
**Cost:** the bundle fits one guest image version. Build a new bundle when the image changes.

## The disconnected network hands out a default route
**Decided:** libvirt's DHCP gives the nodes a default route to the bridge, although nothing is forwarded.
**Why:** MicroShift takes the node address from the interface holding the default route.
**Cost:** none; packets to outside addresses are dropped at the bridge.
