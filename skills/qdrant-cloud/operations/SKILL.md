---
name: qdrant-cloud-operations
description: "Operating a running Qdrant Managed Cloud cluster: reading health, metrics, logs, and alerts, resizing, backups and restores, version updates, access audits, and which changes an agent may make unprompted. Use when someone says 'my Cloud cluster is unhealthy', 'cluster keeps restarting', 'check cluster health', 'is it safe to scale down', 'set up backups', 'restore a backup', 'upgrade my Cloud cluster', 'who has access to my account', or 'what can the Cloud MCP change'."
---

# Operating a Qdrant Cloud Cluster

Read cluster state through the Qdrant Cloud MCP when it is connected, otherwise through `qcloud` with `--json`, otherwise ask the user to paste it from the Console. Tool names below come from the Cloud public API; use what the client lists and don't assume a tool exists [Qdrant Cloud MCP](https://skills.qdrant.tech/md/documentation/qdrant-mcp/cloud/) [Cloud CLI](https://skills.qdrant.tech/md/documentation/cloud-automation/cloud-cli/)

## Cluster Is Unhealthy, Restarting, or Slow

Use when: the user reports errors, restarts, or degraded search on a Cloud cluster.

- Most tools need an `accountId`, so call `list_accounts` first. If a list comes back empty, check the account before assuming the cluster is gone
- Check in this order: `get_cluster` for status and configuration, `list_cluster_alerts` for what is firing, `get_cluster_summary_metrics` for per-node CPU, RAM, and disk against capacity, then `get_cluster_usage_metrics` for request rate, latency, and trends. The `qcloud` equivalents are `cluster describe`, `cluster alert list`, `cluster metrics summary`, and `cluster metrics history` [Cluster alerts](https://skills.qdrant.tech/md/documentation/cloud/cluster-alerts/)
- Read `get_cluster_logs` last, narrowed to the incident window. `qcloud cluster logs` defaults to the last 3 days, so pass `--since 6h` or similar
- Summary metrics are short-term averages, and a node that just restarted can show no data. Read missing values as unknown, not zero
- `list_cluster_collections` lists collection names, which tells you what to check next in the Qdrant API. RAM above about 80%, or disk close to full, points to scaling; see the [vertical scaling skill](../../qdrant-scaling/scaling-data-volume/vertical-scaling/SKILL.md). The MCP can't see optimizer state, segments, or slow queries, so for those use the [monitoring debugging skill](../../qdrant-monitoring/debugging/SKILL.md)
- `get_cluster_events` works only for Hybrid Cloud clusters [Monitor clusters](https://skills.qdrant.tech/md/documentation/cloud/cluster-monitoring/)

## Resizing a Cluster

Use when: the user wants to scale a Cloud cluster up or down.

- Before scaling down, call `get_cluster_downscale_risk` with the target package ID (from `list_packages`). It changes nothing and checks against current measurements, so call it again if load has moved
- Scale with `update_cluster` or `qcloud cluster scale`. Reducing RAM is always allowed, even when the data no longer fits and the cluster can run out of memory [Cluster scaling](https://skills.qdrant.tech/md/documentation/cloud/cluster-scaling/)
- Lowering disk replaces nodes one at a time without downtime, but it takes a while and adds disk I/O load [Scaling down disk](https://skills.qdrant.tech/md/documentation/cloud/cluster-scaling/?s=scaling-down-disk-space)
- Per `qcloud cluster scale --help`, lowering disk deletes the cluster's local snapshots, so have the user copy any they need first. It needs Qdrant 1.19.2 or newer, and `qcloud` refuses it without `--allow-disk-decrease`, even with `--force`. The MCP equivalent is `allowAdditionalDiskDecrease` on `update_cluster`
- Changing CPU or RAM restarts the nodes. Increasing only the disk, or changing the disk speed tier, restarts nothing. With at least one collection at a replication factor of 2 or higher the restart is rolling and the replicated collections stay available. If every collection is at 1, all nodes restart at the same time and the cluster is briefly down. Check the replication factors, and take a backup, before starting [Restarts and downtime](https://skills.qdrant.tech/md/documentation/cloud/configure-cluster/?s=restarts-and-downtime)

## Backups and Restores

Use when: the user wants scheduled backups, or needs to recover data.

- Create a schedule with `create_backup_schedule` or `qcloud backup schedule create`. The cron expression is in UTC, and retention is 1 to 365 days. Take an on-demand `create_backup` before risky changes. Backups are for Standard clusters only [Backups](https://skills.qdrant.tech/md/documentation/cloud/backups/)
- Prefer `create_cluster_from_backup`, which restores into a new cluster and leaves the live one untouched. `restore_backup` onto the same cluster loses everything written since the backup, also rolls back its size and version, and leaves the cluster unavailable meanwhile
- Check `list_backups` and `list_backup_restores` before and after, so the user knows which backup was used and whether the restore finished

## Updating the Qdrant Version

Use when: the user wants to move a Cloud cluster to a newer Qdrant version.

- List targets with `list_qdrant_releases` or `qcloud cluster version list`, then apply the version through `update_cluster`. This restarts the nodes, rolling only if some collection has a replication factor of 2 or higher [Updating clusters](https://skills.qdrant.tech/md/documentation/cloud/cluster-upgrades/)
- Follow the [version upgrade skill](../../qdrant-version-upgrade/SKILL.md) checklist first, and afterward poll `get_cluster` until the cluster state reports the target version and a healthy phase

## Auditing Access

Use when: the user asks who can reach the account or a cluster.

- List people and permissions with `list_account_members`, `list_users_with_roles`, and `list_roles`. The MCP doesn't list Cloud Management Keys; use `qcloud iam key list` or the Console. They keep working after their creator leaves [Removing a user](https://skills.qdrant.tech/md/documentation/cloud-account-setup/user-management/?s=removing-a-user-from-an-account)
- The MCP docs say it doesn't create Database API keys. Create them in the Cloud Console, with `qcloud cluster key create`, or through the Cloud API or Terraform [Authentication](https://skills.qdrant.tech/md/documentation/cloud/authentication/)

## Making Changes Safely

Use when: about to run anything other than a read.

- Read freely. For every change, state the account, cluster, and action, and wait for the user's yes. A read-only MCP connection must be re-authorized with manage access before it can change anything
- `delete_cluster` and enabling JWT RBAC can't be undone. `suspend_cluster` and `restart_cluster` interrupt service. Ask for explicit confirmation naming the cluster, and never run them as a side effect of a diagnosis
- `qcloud` asks for confirmation on scale, restart, suspend, delete, and backup restore. With no one at the terminal it prints `Aborted.` and exits 0, which looks like success. After the user says yes in chat, run that one command with `--force`, then check the output for `Aborted.` and confirm the change with `get_cluster` or `qcloud cluster describe`
- When the user has several accounts, confirm which one before changing anything
- Free clusters are suspended after 1 week idle and deleted after 4 weeks, so a missing free cluster may be lifecycle, not an incident [Free clusters](https://skills.qdrant.tech/md/documentation/cloud/create-cluster/?s=free-clusters)

## What NOT to Do

- Change, restart, suspend, or delete a cluster without the user's explicit confirmation
- Scale down without running `get_cluster_downscale_risk` first
- Restore a backup onto the live cluster when a new cluster would do
- Treat empty tool results as proof the cluster is gone before checking the account
- Look for points or collection contents in the Cloud MCP; it manages infrastructure, and at most lists collection names with `list_cluster_collections`
- Run `qcloud` with `--force` before the user has confirmed, or treat an exit code of 0 as proof it ran
