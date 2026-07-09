---
id: qdrant-version-upgrade
skill_url: https://skills.qdrant.tech/qdrant-version-upgrade/SKILL.md
rubric:
  must:
    - States you cannot jump straight 1.15 -> 1.17 on self-hosted — storage compat is one minor at a time, so go 1.15 -> 1.16 -> 1.17
    - Recommends upgrading the SDK to the next minor before the server, stepwise (client/server within one minor)
    - Confirms zero-downtime via rolling upgrade because the 3-node cluster has replication_factor >=2 (one node at a time)
  bonus:
    - Notes Qdrant Cloud would automate the multi-version jump (this self-hosted setup does not)
    - Notes server and SDK major/minor are expected to match (1.17.x server <-> 1.17.x SDK)
  avoid:
    - Tells them to upgrade the server straight to 1.17 in one hop, risking storage incompatibility
---
We're on self-hosted 1.15 and want to get to 1.17. It's a replicated 3-node cluster serving live traffic, and our Python client is pinned to 1.15. Can we jump straight there, what order do we upgrade server vs. client in, and how do we avoid downtime or breaking our stored data?
