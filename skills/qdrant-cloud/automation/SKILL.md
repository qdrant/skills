---
name: qdrant-cloud-automation
description: "Choosing and wiring up the interface for managing Qdrant Managed Cloud: Console, the Cloud MCP, the qcloud CLI, the Cloud API, Terraform, or Pulumi, plus authentication, management keys, and CI use. Use when someone says 'which Cloud interface should I use', 'qcloud or Terraform', 'automate cluster creation', 'connect the Cloud MCP', 'run qcloud in CI', 'management key for a pipeline', 'manage Qdrant Cloud from my agent', or 'Terraform drift on a cluster'."
---

# Automating Qdrant Cloud

The Console, MCP, `qcloud`, Terraform, and Pulumi all call the same Cloud API. Pick by who is acting and how long the result must live, not by feature. [Automate Qdrant Cloud](https://skills.qdrant.tech/md/documentation/cloud-automation/) [Cloud API](https://skills.qdrant.tech/md/documentation/cloud-automation/cloud-api/)

## Which Interface to Use

Use when: the user asks how to create or manage clusters, or an agent must choose a tool.

- Use the Console for one-off changes and anything an interactive screen is best at [Console](https://skills.qdrant.tech/md/documentation/cloud/create-cluster/?s=create-a-cluster)
- Use the Cloud MCP for an agent to explore and read cluster state in conversation, with changes confirmed one by one. It signs in through the browser, so no key is stored [Qdrant Cloud MCP](https://skills.qdrant.tech/md/documentation/qdrant-mcp/cloud/)
- Use `qcloud` when an agent or script has a shell: output piped through `jq`, waiting for a cluster, loops over clusters, and CI jobs [Cloud CLI](https://skills.qdrant.tech/md/documentation/cloud-automation/cloud-cli/)
- Use Terraform or Pulumi for clusters that live long and should be reviewed, repeatable, and recreated from code [Terraform](https://skills.qdrant.tech/md/documentation/cloud-automation/terraform/) [Pulumi](https://skills.qdrant.tech/md/documentation/cloud-automation/pulumi/)
- Call the Cloud API directly only for custom integrations that none of the above fit
- When an agent has both MCP and shell, read with the MCP and run long or repeated jobs with `qcloud`. For operating steps, see the [operations skill](../operations/SKILL.md)
- Prototype in the Console or MCP, then move what should last into Terraform

## Connecting the Cloud MCP

Use when: the user wants an agent to manage Cloud, or the MCP shows no tools.

- Claude Code needs `--transport http` when adding the server, then `/mcp` to sign in. Claude Desktop, Codex, and Copilot CLI each have their own steps, listed in the docs [Qdrant Cloud MCP](https://skills.qdrant.tech/md/documentation/qdrant-mcp/cloud/)
- Start read-only: the docs recommend escalating to manage access only when a change is needed. A read-only connection must be re-authorized before it can change anything, so grant manage access only for the task at hand
- Some clients cache tool lists, so restart the assistant if tools are missing after sign-in
- The MCP manages infrastructure only, and its docs say it doesn't create Database API keys; `qcloud cluster key create`, the Cloud API, Terraform, and the Console all do. For points and collection contents, use the open-source Qdrant MCP or the [clients-sdk skill](../../qdrant-clients-sdk/SKILL.md)

## Authenticating qcloud and the API

Use when: setting up `qcloud` for a person, a script, or a pipeline.

- Interactively, use `qcloud auth login`. For automation, use a Cloud Management Key through `qcloud context set` or the `QDRANT_CLOUD_API_KEY` and `QDRANT_CLOUD_ACCOUNT_ID` environment variables [CLI configuration](https://skills.qdrant.tech/md/documentation/cloud-automation/cloud-cli/?s=configuration)
- A Management Key authorizes the Cloud platform, not the database. Database access needs a separate Database API key, and mixing them up is the usual cause of auth errors [Cloud API authentication](https://skills.qdrant.tech/md/documentation/cloud-automation/cloud-api/?s=authentication)
- Create one Management Key per pipeline so it can be revoked alone, keep it in the CI secret store, and never paste it into a prompt or commit it. Revoke it when its owner leaves
- With several accounts, run `qcloud context show` before any change, and switch with `qcloud context use`

## Scripting qcloud

Use when: running `qcloud` unattended or from an agent.

- Add `--json` and parse the output. Don't scrape the table view
- Creation takes time, so use `--wait` on create or `qcloud cluster wait` with `--timeout` (default 10 minutes) before the next step [Quick start](https://skills.qdrant.tech/md/documentation/cloud-automation/cloud-cli/?s=quick-start)
- Without `--force`, `qcloud` asks for confirmation on scale, restart, suspend, delete, and backup restore. With no one at the terminal it prints `Aborted.` and exits 0, so a script or agent sees success when nothing ran. Check the output for `Aborted.`
- For an agent, get the user's yes in chat first, then run that one command with `--force`. In a pipeline, use `--force` only in jobs a person reviewed, and never on delete, suspend, or restore
- Version, replication factor, and vectors-on-disk changes restart the nodes. The restart is rolling only if some collection has a replication factor of 2 or higher, so schedule them like any other restart [Restarts and downtime](https://skills.qdrant.tech/md/documentation/cloud/configure-cluster/?s=restarts-and-downtime)

## What NOT to Do

- Change a Terraform-managed cluster with `qcloud`, the MCP, or the Console; the next apply reverts it or fails on drift
- Use a Management Key as a Database API key, or the reverse
- Share one Management Key across pipelines and people
- Run `qcloud` with `--force` in an agent loop, or before the user has said yes
- Treat a `qcloud` exit code of 0 as proof the change ran; a declined prompt also exits 0
- Give the MCP manage access for a task that only reads
