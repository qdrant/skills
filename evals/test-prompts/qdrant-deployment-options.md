---
id: qdrant-deployment-options
skill_url: https://skills.qdrant.tech/qdrant-deployment-options/SKILL.md
rubric:
  must:
    - Recommends a managed option (Qdrant Cloud or Hybrid Cloud) given the no-cluster-babysitting constraint
    - Ties the EU data-residency requirement to Hybrid Cloud (managed control plane on the user's own infra)
    - Suggests local mode / Docker for the early CI + laptop prototyping stage
  bonus:
    - Warns local-mode data format is not server-compatible (don't use for production or benchmarking)
    - Frames the choice via decision axes — managed vs control, latency, production vs prototyping
  avoid:
    - Recommends self-managed distributed Docker as the production target despite the explicit low-ops constraint
---
We're kicking off a new RAG project. Today it only runs in pytest CI and on a laptop, but within a few months it has to serve a production app under strict EU data-residency rules, and we'd rather not babysit clusters. How should we run Qdrant across these stages without painting ourselves into a corner?
