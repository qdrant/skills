---
name: qdrant-version-upgrade
description: "Guides Qdrant version upgrades without downtime. Use when someone asks 'how to upgrade Qdrant', 'is my version compatible', 'rolling upgrade', 'can I skip versions', 'upgrade broke something', or 'SDK version mismatch'. Also use when planning a major or minor version bump."
---

# What to Do When Upgrading Qdrant

Compatibility is only guaranteed between consecutive minor versions. You must upgrade sequentially (1.15 to 1.16 to 1.17). Qdrant Cloud automates intermediate steps, self-hosted does not. Storage migration is automatic and irreversible. No downgrades.

- Check upgrade details [Cluster upgrades](https://qdrant.tech/documentation/cloud/cluster-upgrades/)


## Planning an Upgrade

Use when: deciding whether and how to upgrade.

- Major and minor versions of Qdrant and SDK are expected to match (1.17.x server with 1.17.x SDK)
- Backward compatible one minor version (server 1.17 works with SDK 1.16, but only for 1.16 features) [Qdrant fundamentals](https://qdrant.tech/documentation/faq/qdrant-fundamentals/)
- Upgrade SDK first, then server. Not the other way around.
- Take a backup before upgrading to allow rollback
- Check release notes for breaking changes [Release notes](https://github.com/qdrant/qdrant/releases)

## Zero-Downtime Upgrade (Rolling)

Use when: production must stay available during upgrade.

- Requires multi-node cluster with `replication_factor: 2` or higher [Replication](https://qdrant.tech/documentation/guides/distributed_deployment/#replication-factor)
- Single-node clusters or `replication_factor: 1` require brief downtime
- Upgrade one node at a time while others continue serving

## Skipping Versions

Use when: need to jump more than one minor version.

- Self-hosted: must upgrade one minor version at a time (1.15 to 1.16 to 1.17). No skipping.
- Qdrant Cloud: handles multi-version jumps automatically with intermediate updates


## What NOT to Do

- Skip minor versions on self-hosted (storage format incompatibility)
- Let SDK drift more than one minor version from cluster (compatibility not guaranteed)
- Upgrade server before SDK (upgrade SDK first, then server)
- Upgrade all nodes simultaneously in a cluster (defeats rolling upgrade, causes downtime)
- Downgrade after upgrading (storage migration is irreversible)
- Upgrade without a backup (no rollback path if something breaks)
