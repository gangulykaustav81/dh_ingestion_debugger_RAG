# DICOM Ingestion Debugger RAG

Phase 1 builds a Knowledge RCA Assistant for a mock DICOM ingestion and analytics pipeline.

The assistant helps support engineers describe dashboard data problems and receive:

- likely pipeline stages involved,
- table/view lineage,
- ordered investigation steps,
- starter SQL checks,
- source references from local project knowledge.

## Current Scope

This is a local Phase 1 prototype. It does not connect to production systems and does not run SQL automatically.

It uses local project files as the knowledge base:

- `AI_RCA_AGENT_PROPOSAL.md`
- `SCHEMA_OVERVIEW.md`
- `knowledge/rca_runbook.md`
- `knowledge/widget_catalog.md`
- `sql/create_schemas.sql`

## Run the Assistant

From the repo root:

```powershell
python -m src.rca_assistant "CT study count is low for yesterday at facility SITE_A"
```

Another example:

```powershell
python -m src.rca_assistant "The dashboard is stale and the daily trend did not refresh"
```

## Recreate Mock Schemas

```powershell
& 'C:\Program Files\MariaDB 12.3\bin\mariadb.exe' --skip-ssl -h localhost -P 3306 -u root -ppassword < .\sql\create_schemas.sql
```

## AIDLC Phase 1 Outcome

The first cycle establishes:

- mock schema assets,
- schema documentation,
- widget and lineage catalog,
- RCA runbook knowledge,
- a runnable local retrieval-based assistant.

Future cycles can add:

- vector embeddings,
- an LLM response generator,
- a web UI,
- read-only database tools,
- ETL log search,
- incident memory and RCA feedback loops.

