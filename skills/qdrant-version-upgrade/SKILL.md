---
name: qdrant-version-upgrade
description: "Covers upgrading Qdrant server and SDKs without interrupting availability or losing data integrity. Use when someone asks 'how do I upgrade Qdrant', 'can I jump from 1.15 to 1.18', 'rolling upgrade without downtime', 'do I upgrade the client or the server first', 'which SDK version matches my server', 'what should I check before upgrading', or 'something changed after we upgraded'."
---


# Qdrant Version Upgrade

Qdrant has the following guarantees about version compatibility:

- Major and minor versions of Qdrant and SDK are expected to match. For example, Qdrant 1.17.x is compatible with SDK 1.17.x.

- Qdrant is tested for backward compatibility between minor versions. For example, Qdrant 1.17.x should be compatible with SDK 1.16.x. Qdrant server 1.16.x is also expected to be compatible with SDK 1.17.x, but only for the subset of features that were available in 1.16.x.

- For migration to the next minor version, it is recommended to first upgrade the SDK to the next minor version and then upgrade the Qdrant server.

- Storage compatibility is only guaranteed for one minor version. For example, data stored with Qdrant 1.16.x is expected to be compatible with Qdrant 1.17.x. If you need to migrate more than one minor version, it is required do the upgrade step by step, one minor version at a time. For example, to migrate from 1.15.x to 1.17.x, you need to first upgrade to 1.16.x and then to 1.17.x. Note: Qdrant Cloud automates this process, so you can directly upgrade from 1.15.x to 1.17.x without intermediate steps.

- A Qdrant cluster with a replication factor of 2 or higher can be upgraded without downtime by performing a rolling upgrade. This means that you can upgrade one node at a time while the other nodes continue to serve requests. This allows you to maintain availability of your application during the upgrade process. More about replication factor: [Replication factor](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=replication-factor)

For managing Qdrant version upgrades in Qdrant Cloud, you can use the [qcloud](https://github.com/qdrant/qcloud-cli) CLI tool.

## Staying Up to Date

Stay up to date with Qdrant releases. Upgrading to newer versions gives you access to the latest bug fixes, security updates, performance improvements, and new features. Regular upgrades also reduce the complexity of future migrations by avoiding large version jumps.

## Pre-Upgrade Checklist

1. Back up first: It's recommended to take a backup or snapshot before updating to allow for rollbacks. If the upgrade fails or you need to revert, you can restore the pre-upgrade snapshot. Qdrant Cloud applies data migrations during upgrades, so there's no live downgrade.

2. It's recommended to run at least 2 CPU cores per node. During upgrades, Qdrant may perform background optimization while still handling regular operations. With only 1 core, these tasks can compete for CPU resources and can significantly slow down the upgrade process.

3. Use replication factor ≥ 2 if you need a zero-downtime rolling upgrade. With a replication factor of 1, the upgrade requires downtime window.

4. Test your client app against the target server version first in a non-prod environment, and check SDK release notes for deprecated/removed methods before switching over.

5. For multi-version jumps, expect to move through each intermediate minor version in sequence (e.g., 1.15→1.16→1.17), with nodes restarting one at a time, and this takes longer than a single-version bump, so plan for it and prefer non-peak hours. Qdrant Cloud automates this chaining for you.

6. Check release notes for default and behavior changes, not just deprecations. Version upgrades may introduce changes to default settings, validation rules, or query behavior that can affect existing workloads even when APIs remain compatible.

## Troubleshooting After an Upgrade

When investigating a bug or unexpected behavior after an upgrade, check the [release notes/changelog](https://github.com/qdrant/qdrant/releases) between the source and target versions for deprecations, default-value changes, and behavior changes that may affect your workload.

## What NOT to Do

- Treat identical absolute scores as an acceptance criterion across versions
- Read only the target version's notes and skip intermediate minor and patch releases
- Jump multiple minor versions at once on self-hosted deployments
- Assume a rolling upgrade finished without confirming that every node reports the target version