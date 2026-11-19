---
name: qdrant-cloud-automation
description: "Choosing and wiring up the interface for managing Qdrant Managed Cloud: Console, the Cloud MCP, the qcloud CLI, the Cloud API, Terraform, or Pulumi, plus authentication, management keys, and CI use. Use when someone says 'which Cloud interface should I use', 'qcloud or Terraform', 'automate cluster creation', 'connect the Cloud MCP', 'run qcloud in CI', 'management key for a pipeline', 'manage Qdrant Cloud from my agent', or 'Terraform drift on a cluster'."
---

# Automating Qdrant Cloud

The Console, MCP, `qcloud`, Terraform, and Pulumi all call the same Cloud API. Pick by who is acting and how long the result must live, not by feature. [Cloud API](https://skills.qdrant.tech/md/documentation/cloud-api/)

## Which Interface to Use

Use when: the user asks how to create or manage clusters, or an agent must choose a tool.

- Use the Console for one-off changes and anything an interactive screen is best at, such as creating Database API keys [Console](https://skills.qdrant.tech/md/documentation/cloud/create-cluster/?s=create-a-cluster)
- Use the Cloud MCP for an agent to explore and read cluster state in conversation, with changes confirmed one by one. It signs in through the browser, so no key is stored [Qdrant Cloud MCP](https://skills.qdrant.tech/md/documentation/qdrant-mcp/cloud/)
- Use `qcloud` when an agent or script has a shell: output piped through `jq`, waiting for a cluster, loops over clusters, and CI jobs [Cloud CLI](https://skills.qdrant.tech/md/documentation/cloud-cli/)
- Use Terraform or Pulumi for clusters that live long and should be reviewed, repeatable, and recreated from code [Terraform](https://skills.qdrant.tech/md/documentation/cloud-tools/terraform/) [Pulumi](https://skills.qdrant.tech/md/documentation/cloud-tools/pulumi/)
- Call the Cloud API directly only for custom integrations that none of the above fit
- When an agent has both MCP and shell, read with the MCP and run long or repeated jobs with `qcloud`. For operating steps, see the [operations skill](../operations/SKILL.md)
- Prototype in the Console or MCP, then move what should last into Terraform

## Connecting the Cloud MCP

Use when: the user wants an agent to manage Cloud, or the MCP shows no tools.

- Claude Code needs `--transport http` when adding the server, then `/mcp` to sign in. Claude Desktop, Codex, and Copilot CLI each have their own steps, listed in the docs [Qdrant Cloud MCP](https://skills.qdrant.tech/md/documentation/qdrant-mcp/cloud/)
- Access starts read-only. Changes need re-authorization with manage access, so grant that only for the task at hand
- Some clients cache tool lists, so restart the assistant if tools are missing after sign-in
- The MCP manages infrastructure only. For points and collections, use the open-source Qdrant MCP or the [clients-sdk skill](../../qdrant-clients-sdk/SKILL.md)

## Authenticating qcloud and the API

Use when: setting up `qcloud` for a person, a script, or a pipeline.

- Interactively, use `qcloud auth login`. For automation, use a Cloud Management Key through `qcloud context set` or the `QDRANT_CLOUD_API_KEY` and `QDRANT_CLOUD_ACCOUNT_ID` environment variables [CLI configuration](https://skills.qdrant.tech/md/documentation/cloud-cli/?s=configuration)
- A Management Key authorizes the Cloud platform, not the database. Database access needs a separate Database API key, and mixing them up is the usual cause of auth errors [Cloud API authentication](https://skills.qdrant.tech/md/documentation/cloud-api/?s=authentication)
- Create one Management Key per pipeline so it can be revoked alone, keep it in the CI secret store, and never paste it into a prompt or commit it. Revoke it when its owner leaves
- With several accounts, run `qcloud context show` before any change, and switch with `qcloud context use`

## Scripting qcloud

Use when: running `qcloud` unattended or from an agent.

- Add `--json` and parse the output. Don't scrape the table view
- Creation takes time, so use `--wait` on create or `qcloud cluster wait` with `--timeout` (default 10 minutes) before the next step [Quick start](https://skills.qdrant.tech/md/documentation/cloud-cli/?s=quick-start)
- `--force` skips confirmation prompts. Use it only in reviewed jobs, and never on delete, suspend, or restore commands
- Changes to replication factor, version, or vectors-on-disk trigger a rolling restart, so schedule them like any other restart

## What NOT to Do

- Change a Terraform-managed cluster with `qcloud`, the MCP, or the Console; the next apply reverts it or fails on drift
- Use a Management Key as a Database API key, or the reverse
- Share one Management Key across pipelines and people
- Run `qcloud` with `--force` in an agent loop
- Give the MCP manage access for a task that only reads
