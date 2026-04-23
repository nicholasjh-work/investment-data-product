<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/nh-logo-dark.svg" width="80">
  <source media="(prefers-color-scheme: light)" srcset="assets/nh-logo-light.svg" width="80">
  <img alt="NH" src="assets/nh-logo-light.svg" width="80">
</picture>

# Investment Data Product

**Governed investment dataset with a published data contract, dbt-modeled marts, and blocking DQ gates feeding a Power BI consumer layer**

[![Data Contract](https://img.shields.io/badge/Data_Contract-Published-16a34a?style=for-the-badge)](DATA_CONTRACT.md)
[![Architecture](https://img.shields.io/badge/Architecture-View-1e40af?style=for-the-badge)](#architecture)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

![Azure SQL](https://img.shields.io/badge/Azure_SQL-0078D4?style=flat&logo=microsoftsqlserver&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)
![Databricks](https://img.shields.io/badge/Databricks-FF3621?style=flat&logo=databricks&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-FF694A?style=flat&logo=dbt&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Delta Lake](https://img.shields.io/badge/Delta_Lake-00ADD4?style=flat)
![Unity Catalog](https://img.shields.io/badge/Unity_Catalog-FF3621?style=flat)

</div>

---

### What This Does

A governed investment data product built with PostgreSQL source systems (simulating Azure SQL + PostgreSQL), modeled in dbt, and delivered to a Power BI consumer layer. The platform standardizes security, issuer, benchmark, position, and transaction data into contract-driven marts with blocking data quality gates, SLA monitoring, and stewardship-ready exception reporting.

---

### Architecture

![Architecture](docs/architecture.png)

Reference data (securities, issuers, benchmark membership, prices) originates in the Azure SQL simulation (`investments_ref`). Activity data (accounts, positions, transactions) originates in the PostgreSQL activity system (`investments_act`). dbt staging views present source-conformed 1:1 projections with a `_source_loaded_at` lineage column. Intermediate views apply Type 2 effective dating, resolve issuer hierarchy, and enrich facts with the governed `security_key` via CUSIP. Marts land as tables in the silver layer and are the contract surface Power BI reads. The `ops_investment_data_runs` table carries dataset-level SLA status and run health for the consumer health tile.

---

### Design Principles

1. The data carries its own health signals. Consumers do not need to check external dashboards to know if the data is trustworthy.
2. Business logic lives at the data layer, not in reports. Reports stay thin, governed, and consistent.
3. The data product has an owner, an SLA, a consumer list, and a published contract. Anything less is a script.
4. SLA is a dataset-level property, not a row-level attribute. Run outcomes live in a separate ops table, never on the fact.
5. Breaking changes require consumer notification, not just a commit.

---

### Operational Visibility

Dataset-level health lives in `investments.silver.ops_investment_data_runs`:

| Column | Purpose |
|---|---|
| ![run_id](https://img.shields.io/badge/run__id-1e293b?style=flat-square) | Unique identifier for the pipeline run |
| ![run_timestamp](https://img.shields.io/badge/run__timestamp-1e293b?style=flat-square) | UTC timestamp of the run |
| ![dataset](https://img.shields.io/badge/dataset-1e293b?style=flat-square) | Mart name being logged (e.g. `fact_position`) |
| ![source_row_count](https://img.shields.io/badge/source__row__count-1e293b?style=flat-square) | Source row count at run time |
| ![curated_row_count](https://img.shields.io/badge/curated__row__count-1e293b?style=flat-square) | Curated row count produced by the run |
| ![drift_pct](https://img.shields.io/badge/drift__pct-1e293b?style=flat-square) | Absolute drift between source and curated |
| ![sla_status](https://img.shields.io/badge/sla__status-1e293b?style=flat-square) | ![GREEN](https://img.shields.io/badge/GREEN-16a34a?style=flat-square) / ![AMBER](https://img.shields.io/badge/AMBER-eab308?style=flat-square) / ![RED](https://img.shields.io/badge/RED-dc2626?style=flat-square) |
| ![checks_passed](https://img.shields.io/badge/checks__passed-1e293b?style=flat-square) | Overall DQ outcome |
| ![failure_message](https://img.shields.io/badge/failure__message-1e293b?style=flat-square) | Populated when `checks_passed = false` |

This is the audit trail and the source of the health tile a Power BI semantic model reads.

---

### Blocking DQ Gates

Every run of the DQ suite enforces these checks. Any failure fails the workflow and blocks publication of the entire suite, so cross-table joins always read a consistent vintage.

| Gate | Check | Severity |
|---|---|---|
| ![Completeness](https://img.shields.io/badge/Completeness-dc2626?style=flat-square) | Zero nulls in `cusip` and `isin` on `dim_security`; CUSIP and ISIN check-digit algorithms pass for every row | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Completeness](https://img.shields.io/badge/Completeness-dc2626?style=flat-square) | Zero nulls in `lei` on `dim_issuer` | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Grain](https://img.shields.io/badge/Grain-ea580c?style=flat-square) | `transaction_id` unique across `fact_transaction`; `(account_key, security_key, as_of_date)` unique across `fact_position`; no overlapping effective periods for the same key in `dim_security`, `dim_issuer`, or `fact_benchmark_constituent` | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Policy](https://img.shields.io/badge/Policy-ea580c?style=flat-square) | Survivorship: every `security_key` referenced in historical `fact_position` or `fact_transaction` exists in `dim_security` | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Policy](https://img.shields.io/badge/Policy-ea580c?style=flat-square) | Market value coherence: `abs(market_value - quantity * price) / abs(market_value)` within 1% for every `fact_position` row | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Policy](https://img.shields.io/badge/Policy-ea580c?style=flat-square) | Issuer hierarchy integrity: every non-null `parent_issuer_key` resolves to an effective-dated parent row; no cycles | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Policy](https://img.shields.io/badge/Policy-ea580c?style=flat-square) | Benchmark weight completeness: `sum(weight_pct)` within 100% +/- 0.1% per `(benchmark_key, effective period)` | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Reconciliation](https://img.shields.io/badge/Reconciliation-2563eb?style=flat-square) | Position-to-transaction tie-out: signed `quantity` from `fact_transaction` between two position snapshots reconciles to the `fact_position` quantity delta within 0.5 shares | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Reconciliation](https://img.shields.io/badge/Reconciliation-2563eb?style=flat-square) | Source-to-curated row count drift within 1% per product | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |
| ![Freshness](https://img.shields.io/badge/Freshness-2563eb?style=flat-square) | Each product meets its freshness SLA stated in the Refresh & SLA table in the data contract | ![Error](https://img.shields.io/badge/Error-dc2626?style=flat-square) |

Referential integrity between facts and dimensions is enforced at build time via inner joins on the effective-dated dimension row, not as a runtime gate.

---

### SLA Status Logic

| Freshness Lag | Status |
|---|---|
| `max(as_of_date) >= current_date - 2` | ![GREEN](https://img.shields.io/badge/GREEN-16a34a?style=flat-square) |
| `current_date - 3` to `current_date - 5` | ![AMBER](https://img.shields.io/badge/AMBER-eab308?style=flat-square) |
| older than `current_date - 5` | ![RED](https://img.shields.io/badge/RED-dc2626?style=flat-square) |

`RED` blocks the run. `AMBER` passes with a warning logged to the runs table. Benchmark constituents use a relaxed window (`current_date - 35`) because the published cadence is monthly plus event-driven.

---

### Repo Layout

```
.
├── sources/
│   ├── azure_sql/ddl/                        # Reference system DDL (dim_issuer, dim_security, benchmark, price)
│   ├── postgresql/ddl/                       # Activity system DDL (account, position, transaction)
│   └── seed_data/generate_seeds.py           # S&P 500 scrape + synthetic CUSIP/ISIN/LEI generator
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml                          # gitignored; local postgres connection
│   ├── models/
│   │   ├── staging/                          # 1:1 source-conformed views + sources.yml
│   │   ├── intermediate/                     # Type 2 versioning + hierarchy + fact enrichment
│   │   └── marts/                            # dim_security, dim_issuer, dim_date, dim_benchmark,
│   │                                         # fact_position, fact_transaction, fact_benchmark_constituent,
│   │                                         # ops_investment_data_runs, schema.yml
│   ├── tests/                                # Custom singular tests (coherence, grain, survivorship, etc.)
│   └── macros/
├── contracts/                                # Contract source of truth + machine-readable copies
├── consumer/
│   └── powerbi/                              # Semantic model, measures, report assets
├── docs/
│   ├── architecture.mmd                      # Mermaid source
│   └── architecture.png                      # Rendered diagram
├── assets/                                   # Branding (nh-logo SVGs)
├── DATA_CONTRACT.md                          # Ownership, SLA, schema, exclusions
├── CHANGELOG.md                              # Versioned changes
├── LICENSE                                   # MIT
└── README.md
```

---

### Running

**1. Local PostgreSQL.** Provision a local PostgreSQL 15+ instance with trust authentication for user `nickhidalgo` and create the `investment_data` database:

```bash
createdb -U nickhidalgo investment_data
```

**2. Apply source DDL.** Create the three schemas and all source tables:

```bash
for f in sources/azure_sql/ddl/*.sql sources/postgresql/ddl/*.sql; do
  psql -U nickhidalgo -h localhost -d investment_data -v ON_ERROR_STOP=1 -f "$f"
done
```

**3. Generate seed data.** Scrapes S&P 500 constituents from Wikipedia, samples 50, generates synthetic identifiers and 252 trading days of prices, and loads positions and transactions across three accounts:

```bash
python3 sources/seed_data/generate_seeds.py
```

**4. Run dbt.** A local `dbt/profiles.yml` (gitignored) targets the same PostgreSQL database:

```bash
cd dbt
DBT_PROFILES_DIR="$PWD" dbt debug
DBT_PROFILES_DIR="$PWD" dbt run
DBT_PROFILES_DIR="$PWD" dbt test
```

`dbt run` materializes staging and intermediate as views and marts as tables into `investments_silver_staging`, `investments_silver_intermediate`, and `investments_silver_marts`. `dbt test` runs generic schema tests plus the custom singular tests that mirror the contract gates.

**5. Connect Power BI.** Point Power BI Desktop at the PostgreSQL connector (`localhost / investment_data`) and import the `investments_silver_marts` schema. The semantic model and measure set live in `consumer/powerbi/`.

---

### Tech Stack

| Component | Technology |
|---|---|
| ![Source](https://img.shields.io/badge/Source-0078D4?style=flat-square) | Azure SQL Database (reference data, simulated in local PostgreSQL) |
| ![Source](https://img.shields.io/badge/Source-4169E1?style=flat-square) | PostgreSQL (activity data) |
| ![Transform](https://img.shields.io/badge/Transform-FF694A?style=flat-square) | dbt (staging, intermediate, marts) |
| ![Platform](https://img.shields.io/badge/Platform-FF3621?style=flat-square) | Databricks (target production runtime, Unity Catalog, Delta Lake) |
| ![Storage](https://img.shields.io/badge/Storage-00ADD4?style=flat-square) | Delta Lake |
| ![Governance](https://img.shields.io/badge/Governance-FF3621?style=flat-square) | Unity Catalog |
| ![Quality](https://img.shields.io/badge/Quality-dc2626?style=flat-square) | dbt generic tests + custom singular tests for contract gates |
| ![Monitoring](https://img.shields.io/badge/Monitoring-00ADD4?style=flat-square) | `investments.silver.ops_investment_data_runs` incremental table |
| ![Consumer](https://img.shields.io/badge/Consumer-F2C811?style=flat-square) | Power BI semantic model |
| ![Contract](https://img.shields.io/badge/Contract-7c3aed?style=flat-square) | Published data contract + CHANGELOG-tracked versioning |

---

### Ownership

Data Product Owner: Nicholas Hidalgo. See [`DATA_CONTRACT.md`](DATA_CONTRACT.md) for SLA, schema, semantics, and exclusion policy. See [`CHANGELOG.md`](CHANGELOG.md) for versioned changes.

---

<div align="center">

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Nicholas_Hidalgo-0A66C2?style=for-the-badge&logo=linkedin)](https://linkedin.com/in/nicholashidalgo)&nbsp;
[![Website](https://img.shields.io/badge/Website-nicholashidalgo.com-000000?style=for-the-badge)](https://nicholashidalgo.com)&nbsp;
[![Email](https://img.shields.io/badge/Email-analytics@nicholashidalgo.com-EA4335?style=for-the-badge&logo=gmail)](mailto:analytics@nicholashidalgo.com)

</div>
