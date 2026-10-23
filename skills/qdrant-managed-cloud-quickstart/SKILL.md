---
name: qdrant-managed-cloud-quickstart
description: "Getting a first Qdrant Managed Cloud cluster running and connected safely: Free, Standard, and Premium tiers, choices that can't be changed later, creating clusters from the Console or the qcloud CLI, Database API keys, ports and TLS, strict mode on new collections, Cloud Inference, and what to set before relying on a cluster. Use when someone says 'getting started with Qdrant Cloud', 'create a Qdrant Cloud cluster', 'is the free tier enough', 'do I need the Premium tier', 'create a cluster with qcloud', 'my free cluster was suspended', 'can't connect to Qdrant Cloud', 'which API key do I use', 'filter works locally but fails on Cloud', or 'Cloud Inference'."
---

# Getting Started with Qdrant Cloud

You've already chosen Qdrant Managed Cloud. If you're still deciding between Cloud, Hybrid Cloud, and self-hosting, use the [deployment options skill](../qdrant-deployment-options/SKILL.md). On Cloud, every request needs an API key over TLS, new collections run in strict mode, and free clusters are suspended when idle. Some cluster choices can't be undone later.

## Choosing and Creating a Cluster

Use when: creating the first cluster, or deciding between Free, Standard, and Premium.

- Use the free cluster for prototyping only: a single node with 1 GB RAM and 4 GB disk, no automatic backups, and it's suspended after 1 week without use and deleted after 4 weeks unless reactivated [Free clusters](https://skills.qdrant.tech/md/documentation/cloud/create-cluster/?s=free-clusters)
- If a node runs out of RAM, the operating system stops the Qdrant process; without high availability, expect disruption until the cluster is scaled up. If it runs out of disk, it can't store new vectors, which can also lead to disruption. Scale the cluster before either happens; on the free tier, that means upgrading to Standard [Cluster alerts](https://skills.qdrant.tech/md/documentation/cloud/cluster-monitoring/?s=alerts)
- Size a Standard cluster before creating it with the [sizing skill](../qdrant-sizing/SKILL.md).
- For anything production-facing, enable High Availability: 3 or more nodes and replication factor 2 or more. Without it each shard has a single replica, so upgrades and vertical scaling cause downtime [Production-ready cluster](https://skills.qdrant.tech/md/documentation/cloud/create-cluster/?s=creating-a-production-ready-cluster)
- Premium is an account-wide plan with a minimum spend agreed with the [Qdrant team](https://qdrant.tech/contact-us/). It adds a higher uptime SLA, 24/7 support for severe issues, Multi-AZ clusters, SSO, private network connectivity, and customer-managed encryption keys. Standard already includes scaling, high availability, and backups, so consider Premium if you need one of these [Premium tier](https://skills.qdrant.tech/md/documentation/cloud-premium/)
- Decide on Multi-AZ (Premium) at creation: it can't be enabled later, and node counts must then be multiples of 3 [Production-ready cluster](https://skills.qdrant.tech/md/documentation/cloud/create-cluster/?s=creating-a-production-ready-cluster)
- Memory and disk can both be scaled down, but the cluster must still fit its data. Memory can't go below current usage. Scaling disk down replaces nodes one at a time, without downtime, but it takes a while and adds disk I/O load until it's done [Vertical scaling](https://skills.qdrant.tech/md/documentation/cloud/cluster-scaling/?s=vertical-scaling) [Scaling down disk](https://skills.qdrant.tech/md/documentation/cloud/cluster-scaling/?s=scaling-down-disk-space)
- Paying through the AWS, GCP, or Azure Marketplace limits cluster creation to paid clusters in that provider's regions. To run clusters in other regions or on other providers, create a separate account with a different payment method [Billing](https://skills.qdrant.tech/md/documentation/cloud-pricing-payments/)
- Use separate accounts to separate clusters across teams or environments, such as dev and prod: each account has its own clusters, permissions, and payment method [Accounts](https://skills.qdrant.tech/md/documentation/cloud-account-setup/?s=creating-additional-accounts)
- Create clusters in the Cloud Console, or through the Cloud API, either by calling it directly or via the qcloud CLI, Terraform, or Pulumi. All the Cloud API options need a Cloud Management Key. Provisioning takes time; qcloud's `--wait` flag blocks until the cluster is healthy [Console](https://skills.qdrant.tech/md/documentation/cloud/create-cluster/?s=create-a-cluster) [Cloud API](https://skills.qdrant.tech/md/documentation/cloud-api/) [qcloud](https://skills.qdrant.tech/md/documentation/cloud-cli/?s=quick-start) [Terraform](https://skills.qdrant.tech/md/documentation/cloud-tools/terraform/) [Pulumi](https://skills.qdrant.tech/md/documentation/cloud-tools/pulumi/)
- For a step-by-step walkthrough in the Console, from sign-up to a free cluster, a first collection, and a first search, see the [Cloud quickstart](https://skills.qdrant.tech/md/documentation/cloud-quickstart/)

## Can't Connect or Authenticate

Use when: the first request to the cluster fails, or an SDK reports an authentication or TLS error.

- Send a Database API key with every REST and gRPC request, as the `api-key` header or `Authorization: Bearer`. Each key works only on the cluster it was created in. It is shown once at creation; if it's lost, create a new one [Authentication](https://skills.qdrant.tech/md/documentation/cloud/authentication/) [Database API keys](https://skills.qdrant.tech/md/documentation/production-operations/access-control/?s=database-api-keys)
- Don't use a Cloud Management Key here. Those authorize the Cloud platform API for managing clusters and backups, not the database [Cloud API](https://skills.qdrant.tech/md/documentation/cloud-api/?s=authentication)
- Connect over HTTPS to the cluster endpoint: port 6333 or 443 for REST, 6334 for gRPC. For working connection code in each language, use the [clients-sdk skill](../qdrant-clients-sdk/SKILL.md) snippet search [Cluster access](https://skills.qdrant.tech/md/documentation/cloud/cluster-access/)
- Test access with a single request to the cluster root URL with the key in the header [Test cluster access](https://skills.qdrant.tech/md/documentation/cloud/authentication/?s=test-cluster-access)
- Read-only and collection-scoped keys are denied some actions, such as creating collections. Check what a key was granted [Table of access](https://skills.qdrant.tech/md/documentation/security/?s=table-of-access)
- Keys expire after 90 days by default; an empty expiration means no expiry [Create Database API keys](https://skills.qdrant.tech/md/documentation/cloud/authentication/?s=create-database-api-keys)
- If IP restrictions are configured, clients outside the allowed ranges can't reach the cluster [Client IP restrictions](https://skills.qdrant.tech/md/documentation/cloud/configure-cluster/?s=client-ip-restrictions)

## Filtered Requests Rejected on Cloud

Use when: retrieving or updating points by a filter is rejected on a Cloud collection.

- New Cloud collections run in strict mode, which rejects retrieving or updating by a filter on a payload field without an index. Create a payload index for each filtered field rather than disabling strict mode; a Cloud collection can have up to 100 payload indexes [Cloud defaults](https://skills.qdrant.tech/md/documentation/cloud/configure-cluster/) [Payload index](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=payload-index)

## Generating Embeddings on Qdrant Cloud

Use when: the user wants Qdrant to create embeddings (Cloud Inference) instead of running a model themselves.

- [Cloud Inference](https://skills.qdrant.tech/md/documentation/cloud/inference/) lets Qdrant embed and store or search in the same API call. It's on by default for clusters created after July 7, 2025; enabling it on an older cluster restarts the cluster
- Use a Qdrant-hosted model, or an external provider through Qdrant, which needs your own API key from that provider [Embedding models](https://skills.qdrant.tech/md/documentation/cloud/inference/?s=embedding-models)
- Free models run in the US, even for EU-region clusters. With EU data-residency requirements, use a paid Qdrant-hosted model or embed before upload.

## Before Relying on the Cluster

Use when: moving from a prototype to something users or other services depend on.

- Set a backup schedule (Standard clusters only). Restoring into the same cluster also rolls back its CPU, memory, node count, and Qdrant version, and the cluster is unavailable during the restore. You can restore into a new cluster instead [Backups](https://skills.qdrant.tech/md/documentation/cloud/backups/?s=restore-a-backup)
- Adding nodes doesn't change a collection's replication factor. After moving to more nodes, check each existing collection and set its replication factor to 2 or more; on Cloud, its shards are then replicated or dropped automatically to match [Replication](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=replication)
- Create collections with at least twice as many shards as nodes so they can spread as the cluster grows; see the [horizontal scaling skill](../qdrant-scaling/scaling-data-volume/horizontal-scaling/SKILL.md) [Production-ready cluster](https://skills.qdrant.tech/md/documentation/cloud/create-cluster/?s=creating-a-production-ready-cluster)
- Cloud caps a cluster at 1000 collections. For many tenants, use the [multitenancy skill](../qdrant-multitenancy/SKILL.md) instead of a collection per tenant [Multitenancy](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/)
- Before upgrading the cluster's Qdrant version, follow the [version upgrade skill](../qdrant-version-upgrade/SKILL.md)
- When removing a user, revoke the Database API keys and Cloud Management Keys they created: keys keep working after their creator is gone [Removing a user](https://skills.qdrant.tech/md/documentation/cloud-rbac/user-management/?s=removing-a-user-from-an-account)
- Run through the [Production checklist](https://skills.qdrant.tech/md/documentation/production-checklist/) before launch.

## What NOT to Do

- Disable strict mode to make an unindexed filter pass instead of indexing the field
- Restore a backup into the live cluster without expecting its size and version to roll back
- Send EU-resident text to a free inference model, which runs in the US
- Remove a user without revoking the API keys they created
