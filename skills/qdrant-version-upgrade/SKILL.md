---
name: qdrant-version-upgrade
description: "Covers upgrading Qdrant server and SDKs without interrupting availability or losing data integrity. Use when someone asks 'how do I upgrade Qdrant', 'can I jump from 1.15 to 1.18', 'rolling upgrade without downtime', 'do I upgrade the client or the server first', 'which SDK version matches my server', 'what should I check before upgrading', or 'something changed after we upgraded'."
---

# Qdrant Version Upgrade

Qdrant has the following version compatibility rules [Upgrading Qdrant](https://skills.qdrant.tech/md/documentation/upgrades/):

- Upgrade the cluster first, then the client SDKs, so the application never calls features the older server doesn't support. Keep the SDK within one minor version of the cluster; larger gaps might work but aren't tested. When crossing several minor versions, update the SDKs once the cluster reaches the target version.

- Storage compatibility spans one minor version. Self-hosted clusters, single-node ones included, must step through every intermediate minor version and land on the latest patch of each: from 1.15 to 1.17, upgrade every node to the newest 1.16.x first. Qdrant Cloud chains the intermediate updates for you [Updating Qdrant Cloud clusters](https://skills.qdrant.tech/md/documentation/cloud/cluster-upgrades/).

- A rolling upgrade (one node at a time) is zero-downtime only if every collection has a replication factor of 2 or higher. A single-node cluster, or any collection with a replication factor of 1, needs a short downtime window [Replication factor](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=replication-factor).

For managing Qdrant version upgrades in Qdrant Cloud, you can use the [qcloud](https://github.com/qdrant/qcloud-cli) CLI tool.

## Pre-Upgrade Checklist

1. Back up first: It's recommended to take a backup or snapshot before updating to allow for rollbacks. If the upgrade fails or you need to revert, you can restore the pre-upgrade snapshot. Qdrant Cloud applies data migrations during upgrades, so there's no live downgrade. [Snapshots](https://skills.qdrant.tech/md/documentation/snapshots/) [Cloud backups](https://skills.qdrant.tech/md/documentation/cloud/backups/)

2. Check [release notes](https://github.com/qdrant/qdrant/releases) for default and behavior changes, not just deprecations. Version upgrades may introduce changes to default settings, validation rules, or query behavior that can affect existing workloads even when APIs remain compatible.

3. Test your client app against the target server version first in a non-prod environment, and check SDK release notes for deprecated/removed methods before switching over.

4. It's recommended to run at least 2 CPU cores per node. During upgrades, Qdrant may perform background optimization while still handling regular operations. With only 1 core, these tasks can compete for CPU resources and can significantly slow down the upgrade process.

5. Check the replication factor of every collection, not just the default: one collection at 1 turns the rolling upgrade into a downtime window.

## Crossing More Than One Minor Version

Use when: the running version is two or more minor versions behind the target.

- On self-hosted, each intermediate step is its own rolling restart, so the total is a multiple of a single-version upgrade. This takes longer than a single-version bump, so plan for it and prefer non-peak hours.
- Upgrade on a regular cadence to keep future jumps to one minor version. Regular upgrades also reduce the complexity of future migrations by avoiding large version jumps.

## Troubleshooting Behavior Changes After an Upgrade

Use when: results, scores, or latency look different once the new version is live.

- When investigating a bug or unexpected behavior after an upgrade, check the [release notes/changelog](https://github.com/qdrant/qdrant/releases) between the source and target versions for deprecations, default-value changes, and behavior changes that may affect your workload.

- Compare relative ranking and recall against your pre-upgrade baseline, not absolute score values. Scoring internals can change between versions and still be correct.

## What NOT to Do

- Treat identical absolute scores as an acceptance criterion across versions
- Read only the target version's notes and skip intermediate minor and patch releases
- Jump multiple minor versions at once on self-hosted deployments
- Assume a rolling upgrade finished without confirming that every node reports the target version