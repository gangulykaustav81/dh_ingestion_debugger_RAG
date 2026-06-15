# AI RCA Agent Proposal for DICOM Ingestion Pipeline

## Context

The current DICOM ingestion and analytics pipeline has multiple stages:

1. The ingestion service reads DICOM files from a Windows file location, parses them, and stores the parsed data in MariaDB under the `Datahub` schema.
2. An hourly ETL service extracts data from `Datahub` into the Analytics Exposition schema in the same database.
3. A daily ETL extracts data into the Analytics Exposition Extract schema, which is hosted in another database.
4. The Analytics schema, in the same database as the Analytics Exposition schema, builds views using data from the Analytics Exposition schema.
5. The analytics UI app uses views from the Analytics schema to build widgets and dashboards.

In production, dashboard data may sometimes not reflect the expected values. Developers then need to debug the full pipeline to identify where the issue occurred. This is difficult for new developers and support engineers when data mapping and lineage knowledge is incomplete or distributed across people, SQL scripts, ETL jobs, and documentation.

## Goal

Build an AI-powered RCA assistant using Retrieval-Augmented Generation (RAG) that support engineers can use to describe a dashboard or data issue and receive guided root cause analysis support.

The assistant should help answer questions such as:

> The modality dashboard count for yesterday is lower than expected for site X. Where should I check?

The agent should return:

1. Likely pipeline stages involved.
2. Exact tables, views, ETL jobs, or dashboard mappings to inspect.
3. Data lineage from dashboard widget back to source DICOM fields.
4. SQL queries or investigation checks to run.
5. Probable RCA patterns based on known failures.

## Recommended Approach

The solution should be a lineage-first RAG agent rather than a generic chatbot.

The main purpose of the agent should be to answer:

> For this dashboard symptom, what upstream entities should I inspect, in what order, and why?

## Knowledge Base

The RAG knowledge base should index the following sources:

- Pipeline architecture documentation.
- DICOM tag to `Datahub` table and column mappings.
- `Datahub` schema table definitions.
- Hourly ETL mappings from `Datahub` to the Analytics Exposition schema.
- Daily ETL mappings from the Analytics Exposition schema to the Analytics Exposition Extract schema.
- Analytics schema view definitions.
- Dashboard and widget to view/table mappings.
- Known production incidents and RCA notes.
- ETL job logs or runbook documentation.
- Common data quality rules.

The most important input is lineage metadata. Without lineage, the RAG system will only provide generic responses instead of useful RCA guidance.

## Agent Workflow

When a support engineer describes a problem, the agent should:

1. Classify the issue type:
   - Missing data.
   - Wrong count.
   - Stale dashboard.
   - Partial site or facility data.
   - Incorrect patient, study, or series values.
   - Delayed ETL.
   - View or dashboard mismatch.
2. Identify the affected dashboard or widget.
3. Trace lineage backwards:

```text
Dashboard Widget
-> Analytics Schema View
-> Analytics Exposition Schema Table
-> Hourly ETL
-> Datahub Schema Table
-> DICOM tag/source file
```

4. Generate investigation steps:
   - Check ingestion status.
   - Check source DICOM availability.
   - Check parsed records in `Datahub`.
   - Check hourly ETL completion.
   - Check daily ETL completion if the extract schema is involved.
   - Check Analytics view logic.
   - Check dashboard filters, date logic, and site/facility filters.
5. Return recommended SQL or debug queries.

## Possible Architecture

```text
User Question
   |
AI RCA Agent
   |
Retriever / RAG Layer
   |
Vector DB + Metadata Store
   |
Docs, Schema DDL, ETL mappings, View SQL, Dashboard mappings, RCA history
   |
Optional Tools:
- DB query tool
- Log search tool
- ETL status checker
```

## Implementation Phases

### Phase 1: Knowledge RCA Assistant

The agent answers using indexed documentation, mappings, schemas, view SQL, dashboard mappings, and runbooks.

In this phase, the agent suggests queries and investigation steps but does not connect directly to the production database.

This phase is safer, easier to approve, and suitable for an initial DLC or proof of concept.

### Phase 2: Interactive RCA Agent

The agent can run approved read-only SQL queries, inspect ETL run status, search logs, and summarize actual evidence.

This phase is more powerful but requires stronger governance, database access controls, audit logging, and production safety rules.

## Minimum Viable DLC Scope

For the first version, build:

1. A small RAG application.
2. Document ingestion for:
   - Schema DDLs.
   - ETL mapping documents.
   - Dashboard-to-view mappings.
   - Sample RCA runbooks.
3. A chat interface for support engineers.
4. A response format that includes:
   - Pipeline path.
   - Likely causes.
   - Ordered checks.
   - SQL snippets.
   - Source citations from mappings or docs.

Example user question:

> CT study count is wrong in dashboard for yesterday.

Expected agent response:

- Identify the relevant dashboard/widget.
- Trace the widget to its Analytics view.
- Trace the view to the Analytics Exposition table.
- Trace the ETL path back to `Datahub`.
- Suggest checks for ingestion, hourly ETL, view filters, date logic, and dashboard filters.
- Provide SQL snippets for each stage.

## Required Artifacts

To build the first useful prototype, the following artifacts are needed:

1. DICOM tag to `Datahub` table and column mapping.
2. `Datahub` to Analytics Exposition ETL mapping.
3. Analytics Exposition to Analytics Exposition Extract schema mapping.
4. Analytics schema view SQL definitions.
5. Dashboard/widget to view mapping.
6. Sample production issue and RCA examples.

## Success Criteria

The first version should be considered successful if a support engineer can describe a dashboard issue and the agent can:

1. Identify the relevant pipeline path.
2. Explain the most likely failure points.
3. Provide ordered investigation steps.
4. Suggest concrete SQL checks.
5. Cite the source mappings or documentation used in the answer.

