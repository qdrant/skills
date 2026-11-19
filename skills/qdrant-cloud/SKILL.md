---
name: qdrant-cloud
description: "Guides running and managing Qdrant Managed Cloud clusters with the Qdrant Cloud MCP, the qcloud CLI, the Cloud API, and Terraform. Use when someone asks 'my Cloud cluster is unhealthy', 'check my Qdrant Cloud cluster', 'use the Cloud MCP', 'manage Qdrant Cloud from my agent', 'qcloud or Terraform', 'automate cluster creation', 'set up backups on Cloud', 'scale my Cloud cluster', 'which Cloud interface should I use', or 'CI pipeline for Qdrant Cloud'."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Cloud

Route first, then answer. Match the user's symptom in the table, `Read` that file, and answer from it.
Do not answer from this page alone: it contains routing only, not the guidance. If two rows match, read both.

| The user says | Read |
|---|---|
| Cluster is unhealthy, restarting, slow, or running out of RAM or disk | `operations/SKILL.md` |
| Want to read cluster health, metrics, logs, or alerts | `operations/SKILL.md` |
| Need to scale, back up, restore, or upgrade a Cloud cluster | `operations/SKILL.md` |
| Which agent actions on a cluster are safe to run without asking | `operations/SKILL.md` |
| Which interface to use: Console, MCP, `qcloud`, Cloud API, Terraform, Pulumi | `automation/SKILL.md` |
| Want to script or automate cluster management, or run it in CI | `automation/SKILL.md` |
| Connecting the Cloud MCP or `qcloud` to an agent, authentication, management keys | `automation/SKILL.md` |
| Creating a first cluster, choosing a tier, connecting an app | [qdrant-managed-cloud-quickstart](../qdrant-managed-cloud-quickstart/SKILL.md) |

The Qdrant Cloud MCP and `qcloud` manage infrastructure: clusters, backups, access, and billing. Neither reads or writes points or collection contents; the MCP can list collection names. For data operations use the [clients-sdk skill](../qdrant-clients-sdk/SKILL.md) or the open-source Qdrant MCP.

Every skill here works without the MCP connected. When it is connected, use it to read cluster state instead of asking the user to paste it. Ask before any change.

[Qdrant Cloud MCP](https://skills.qdrant.tech/md/documentation/qdrant-mcp/cloud/)
