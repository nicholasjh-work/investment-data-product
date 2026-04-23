# Changelog : `investments.silver` suite

All notable changes to this data product are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and semantic versioning. The v1 suite is versioned as a single contract covering five published tables (`dim_security`, `dim_issuer`, `fact_position`, `fact_transaction`, `fact_benchmark_constituent`) plus governance tables (`dim_date`, `dim_benchmark`, `ops_investment_data_runs`).

---

## [1.0.0] - 2026-04-23

### Added

- **Source systems (simulated locally in PostgreSQL).**
  - `investments_ref` schema representing Azure SQL reference data: `dim_issuer`, `dim_security`, `benchmark_constituent`, `security_price`.
  - `investments_act` schema representing PostgreSQL activity data: `account`, `position`, `transaction`.
  - DDL checked in under `sources/azure_sql/ddl/` and `sources/postgresql/ddl/`.
- **Seed data generator** (`sources/seed_data/generate_seeds.py`):
  - Scrapes live S&P 500 constituents from Wikipedia, samples 50.
  - Generates synthetic CUSIPs with valid check digits and synthetic ISINs with valid check digits.
  - Generates format-plausible LEIs (20 alnum characters).
  - Builds equal-weight benchmark membership rounded to sum within 0.1% of 100%.
  - Generates 252 trading days of geometric random-walk daily prices.
  - Builds positions for 3 accounts x 20 securities and transactions consistent with position deltas.
- **dbt project** (`investment_data_product`) targeting local PostgreSQL (`investment_data`, schema root `investments_silver`), 4 threads, trust auth.
  - **Staging (views):** `stg_issuer`, `stg_security`, `stg_benchmark_constituent`, `stg_security_price`, `stg_account`, `stg_position`, `stg_transaction`. Each is a 1:1 source-conformed projection with `_source_loaded_at` lineage aliased from `source_updated_at`.
  - **Intermediate (views):** `int_security_versioned` (Type 2 effective dating with `is_current`), `int_issuer_hierarchy` (surrogate regeneration + resolved parent chain), `int_position_enriched` (CUSIP join + `unrealized_pnl`), `int_transaction_enriched`.
  - **Marts (tables):** `dim_security`, `dim_issuer`, `dim_date` (395 rows, 2024-04-01 through 2025-04-30), `dim_benchmark`, `fact_position`, `fact_transaction`, `fact_benchmark_constituent`.
  - **Ops (incremental):** `ops_investment_data_runs` seeded empty via `where false`, keyed on `run_id`.
- **Data quality suite** mapping to the contract:
  - **Generic tests in `schema.yml`:** not_null + unique on `security_key`, `issuer_key`, `transaction_id`; not_null on `cusip`, `isin`, `lei`; accepted_values on `listing_status` and `transaction_type`; relationships from every fact to `dim_security`.
  - **Custom singular tests in `dbt/tests/`:**
    - `test_market_value_coherence` (policy gate: `abs(mv - qty*price)/abs(mv) <= 1%`).
    - `test_position_grain_unique` (grain gate for `(account_key, security_key, as_of_date)`).
    - `test_benchmark_weights_sum` (policy gate: weight sum within 100% +/- 0.1%).
    - `test_issuer_hierarchy_no_orphans` (policy gate: every non-null parent resolves).
    - `test_no_overlapping_security_dates` (grain gate: no overlapping effective periods per CUSIP).
    - `test_survivorship_no_missing_securities` (policy gate: every referenced security_key exists in `dim_security`).
  - Current run: **25 tests PASS, 0 FAIL, 0 ERROR**.
- **Published data contract** (`DATA_CONTRACT.md`) covering ownership, purpose, grain, refresh and SLA, semantics, blocking quality gates, and exclusions by design.
- **Architecture diagram** (`docs/architecture.mmd` + `docs/architecture.png`) showing Azure SQL + PostgreSQL -> dbt staging -> intermediate -> marts -> Power BI with the ops runs table as a sidecar.
- **README v2** following the revenue-data-product pattern: primary trio badges, tech stack row, operational visibility table, blocking DQ gates table with category + severity badges, SLA status logic, repo layout, running instructions, tech stack, ownership, footer trio.

### Design decisions

- **Suite-level contract, not per-table.** The five published tables refresh as a single workflow and are versioned together so cross-table joins always read a consistent vintage. A failure in any upstream task blocks publication of the entire suite.
- **Simulated Azure SQL on local PostgreSQL.** v1 scaffolds the contract, the marts, and the DQ surface on a single local database. Production target is Databricks + Unity Catalog + Delta. Schema names (`investments_ref`, `investments_act`, `investments_silver`) were chosen to mirror the eventual catalog layout without requiring cloud credentials for the demo.
- **Regenerated surrogate keys in intermediate.** `int_security_versioned` and `int_issuer_hierarchy` regenerate surrogates via `row_number()` over the natural key (CUSIP, LEI) so the intermediate layer is independent of source-side key drift. Enriched fact views bridge through CUSIP to resolve the governed `security_key`.
- **CUSIP as the fact-to-dimension join key.** Positions and transactions are enriched via inner join on CUSIP against the current security version. Off-contract securities are dropped at build time, not at runtime gates.
- **SLA lives on the runs table, never on the fact.** Consumers read the fact for data and the runs table for health. Dataset-level GREEN/AMBER/RED replaces row-level flags.
- **Equity-only, US-only, native currency.** The contract excludes non-equity, non-US domicile, derivatives pricing, Level 2/3 valuations, FX translation, and intraday granularity. Each exclusion is listed in the contract with a pointer to where consumers should go instead.
- **Benchmark scope frozen at S&P 500 for v1.** Additional benchmarks are a breaking change.

### Known limitations

- **Synthetic identifiers.** Seed CUSIPs and ISINs have valid check digits; seed LEIs are format-plausible only (20 alnum characters) and are not ISO 17442 check-digit valid. A production LEI check-digit gate would fail on seed data.
- **No real Type 2 history yet.** Seed data produces one effective-dated row per security and per issuer (`is_current = true` for all). The Type 2 machinery is in place but has no version churn to demonstrate.
- **No parent/subsidiary issuers in the seed.** `parent_issuer_key` is null for every seed issuer, so the hierarchy resolution path is exercised by shape but not by value.
- **Intermediate surrogates diverge from source keys.** `int_*` surrogates are regenerated from natural keys, so source-side `security_key` and `issuer_key` values are not preserved. Facts are bridged correctly via CUSIP, but direct joins from source to mart surrogates will not match.
- **Position-to-transaction tie-out is declared, not yet automated.** The contract gate is written and the tolerance (0.5 shares) is set; a dbt test implementing the full reconciliation logic is deferred to v1.1.
- **Corporate action detection gate is stubbed.** The warning-with-escalation policy is captured in the contract but not yet wired as a dbt singular test.
- **Power BI consumer layer is scaffolded only.** `consumer/powerbi/` exists as a placeholder; the semantic model, measure set, and health tile are planned for v1.1.
- **Freshness gate is date-based, not time-based.** SLA thresholds use calendar-day comparisons, not hour-level lag, because v1 data arrives daily on T+1.

### Planned (v1.1)

- Implement the position-to-transaction tie-out gate as a dbt singular test at the `(account_key, security_key, snapshot_pair)` grain with a 0.5-share tolerance.
- Implement the corporate action detection gate with warning/escalation behavior and a scheduled review queue.
- Add LEI ISO 17442 check-digit validation as a completeness gate once seed data carries valid LEIs.
- Build the Power BI semantic model under `consumer/powerbi/` with a health tile that reads `ops_investment_data_runs`.
- Introduce a snapshotted Type 2 example (renamed ticker, sector reclassification) so effective dating is exercised end-to-end in the test data.
- Add a runs-table writer macro so every dbt invocation appends a row with source/curated counts, drift, and SLA status.

### Planned (v2)

- Port the pipeline from local PostgreSQL to Databricks + Unity Catalog + Delta Lake. Silver marts land under `investments.silver.*`; ops runs under `investments.ops.*`.
- Expand benchmark scope beyond S&P 500 (breaking change; new contract version).
- Add a dedicated corporate actions product and remove the embedded `Split` / `Spinoff` / `Merger` rows from `fact_transaction`.
- Optional bronze landing zone if downstream replay or ingestion debugging becomes a recurring need.
