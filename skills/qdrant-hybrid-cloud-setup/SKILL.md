---
name: qdrant-hybrid-cloud-setup
description: "Setting up and running Qdrant Hybrid Cloud on your own Kubernetes cluster (managed, on-prem, or edge): prerequisites, storage/CSI and backups, installing the Qdrant Cloud agent and operator, creating/exposing/securing clusters, registry mirroring, and secret rotation. Use when someone wants to set up, install, deploy, or configure Hybrid Cloud (or Private Cloud) on their own infrastructure; is running Qdrant on their own EKS, GKE, AKS, OpenShift, or other Kubernetes; asks about the agent or operator, a storage class or volume snapshots for Hybrid Cloud, exposing a cluster, mirroring Qdrant images, or rotating secrets; or when a Hybrid Cloud install"
---

# Setting Up Qdrant Hybrid Cloud

You've already chosen Hybrid Cloud (managed control plane on your own infra). If you're still deciding, that's the `qdrant-deployment-options` skill. Most setup failures trace to one of two things: **storage** (the CSI driver can't do what Qdrant needs) or **connectivity** (the agent can't reach Qdrant Cloud). Diagnose which before touching anything else.

## Preparing the Kubernetes cluster (do this first)

Use when: about to create the environment, or the install/cluster provisioning failed on storage.

- Qdrant needs a block-storage CSI driver. Network storage (NFS) and object storage (S3) are unsupported: a cluster wired to those will fail, not degrade [Prerequisites](https://skills.qdrant.tech/md/documentation/hybrid-cloud/hybrid-cloud-setup/).
- Create the `StorageClass` (with `allowVolumeExpansion: true`) and the `VolumeSnapshotClass` *beforehand*, not after. Without volume expansion you can't grow disk later; without a `VolumeSnapshotClass` and the CSI snapshot controller you can't take backups.
- Any standards-compliant Kubernetes works, and there's platform-specific setup guidance for the managed ones: Akamai (Linode/LKE), AWS (EKS), Civo, DigitalOcean (DOKS), Gcore, GCP (GKE), Azure (AKS), Oracle (OKE), OVHcloud, Red Hat OpenShift, Scaleway, STACKIT, and Vultr [Deployment Platforms](https://skills.qdrant.tech/md/documentation/hybrid-cloud/platform-deployment-options/).
- Platform matters for what storage supports: some (e.g. Linode/LKE, Vultr) don't support CSI volume snapshots at all, so backups are unavailable there. Check your provider's snapshot page and prefer its recommended instance and disk types (e.g. gp3 on EKS, Premium SSD v2 on AKS) before committing.
- Confirm outbound connectivity: the agent opens connections to `grpc.cloud.qdrant.io` and `api.cloud.qdrant.io` on 443. Firewalls/egress proxies block this silently: a "stuck installing" agent is usually this.
- You need `cluster-admin` plus `kubectl` and `helm` configured against the target cluster.

## Creating the environment

Use when: running the install wizard in the Cloud Console.

- The **Kubernetes namespace is permanent**: it's the one choice you can't change later. Everything else (node selectors, tolerations, registry URLs, proxy) is editable after creation, so don't over-think them now.
- The wizard generates a one-time install command that creates secrets and installs the agent + operator via Helm. You only need it for the initial install; updates happen from the Console afterward [Setup guide](https://skills.qdrant.tech/md/documentation/hybrid-cloud/hybrid-cloud-setup/).
- Advanced operator behavior (pod scheduling, security context, ingress, networking, and snapshot management) is tuned in the operator configuration at the environment level, and can be changed after install [Operator configuration](https://skills.qdrant.tech/md/documentation/hybrid-cloud/operator-configuration/).
- Air-gapped or registry-restricted? Mirror the `/qdrant/` images and `/qdrant-charts/` charts into your own registry and set the container + chart URLs in the environment's advanced section. Sync *all* architectures (or the right one) or ARM/x86 nodes will fail to pull.

## Creating a cluster in the environment

Use when: the environment exists and you're provisioning a database.

- Pick the Database Storage Class and Volume Snapshot Class here. Setting Volume Snapshot Class to `None` disables backups; `emptyDir` for the snapshot volume makes it ephemeral (lost on pod restart): deliberate choices, not defaults to accept blindly [Cluster creation](https://skills.qdrant.tech/md/documentation/hybrid-cloud/hybrid-cloud-cluster-creation/).
- By default Qdrant Cloud reserves ~20% CPU/memory per pod for the OS and system components. Small nodes may need more reserved; large nodes less. Aim for one database pod per node.
- Use node selectors / tolerations / topology spread constraints to keep databases on dedicated nodes and spread across zones.

## Exposing and securing a cluster

Use when: apps outside the Kubernetes cluster need to reach Qdrant, or asked about API keys/TLS.

- Default is a `ClusterIP` service: internal-only, **no API key**. The moment you expose it (LoadBalancer, NodePort, or Ingress) you MUST configure an API key, supplied as a Kubernetes secret referenced in the cluster config [Networking & security](https://skills.qdrant.tech/md/documentation/hybrid-cloud/networking-logging-monitoring/).
- Internal node-to-node gRPC uses port 6335 and is never protected by API key or TLS. It must never be publicly reachable; Hybrid Cloud ships a NetworkPolicy restricting it, so don't loosen that.
- TLS: offload at the ingress/LB, or terminate in Qdrant via a TLS secret. Don't do both by accident.

## Logging

Use when: setting log levels or wiring cluster logs into your stack. (For metrics/Prometheus/Grafana, use the `qdrant-monitoring` skill instead.)

- Log levels are set in two different places: per-database in the Cluster detail page, but for the **Agent and Operator** in the Hybrid Cloud Environment config, not per-cluster [Networking, Logging & Monitoring](https://skills.qdrant.tech/md/documentation/hybrid-cloud/networking-logging-monitoring/).
- Logs are plain pod logs with no Qdrant-specific format. Point any Kubernetes-aware log collector at all pods in the Qdrant namespace; nothing Qdrant-specific to configure.

## What NOT to Do

- Provision on NFS, S3, or any non-block storage: it's unsupported and will fail outright, not just run slowly.
- Create the `StorageClass`/`VolumeSnapshotClass` (or enable `allowVolumeExpansion`) after the fact, then discover you can't scale disk or take backups. They must exist beforehand.
- Assume backups "just work" on Linode or Vultr: verify CSI snapshot support for your platform first.
- Expose a cluster via LoadBalancer/Ingress without setting an API key, or leave port 6335 publicly reachable.
- Regenerate the install command (or rotate secrets) and forget to reapply it: the agent-to-Cloud link breaks silently until you do.
- Delete a Hybrid Cloud environment before deleting its clusters: tear down clusters first, then the environment, then run the cleanup script, or you'll strand resources in the cluster.
