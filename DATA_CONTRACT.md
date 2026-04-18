# Data Contract : Investment Data Product (v1)

This contract governs the v1 Investment Data Product suite: a set of five related curated tables published together under a single versioned contract. Consumers reading any one table can assume the full suite is co-refreshed and co-governed.

Covered products:

1. `investments.silver.dim_security` : security master with effective dating
2. `investments.silver.dim_issuer` : issuer master with corporate hierarchy
3. `investments.silver.fact_position` : account-level portfolio holdings
4. `investments.silver.fact_transaction` : executed trades and capital actions
5. `investments.silver.fact_benchmark_constituent` : benchmark membership bridge with effective dating

## Ownership
- **Product owner:** Nicholas Hidalgo (Data Product Owner / Analytics Operations)
- **Producer systems:**
  - Azure SQL : reference and master data (security, issuer, benchmark definitions, corporate actions)
  - PostgreSQL : activity data (positions, transactions, account state)
- **Intended consumers:**
  - Portfolio Analytics (position composition, exposure analysis, attribution)
  - Risk (concentration, issuer rollup, benchmark tracking)
  - Compliance (holdings review, regulatory reporting prep)
  - Data Stewards (reference data quality oversight)
  - Downstream governed marts and reporting systems (read-only via this suite)

## Purpose

### `dim_security`
Governed security master for US-domiciled equities. Each row is a point-in-time statement of a security's descriptive attributes (CUSIP, ISIN, ticker, sector, listing status, termination date if any). Delisted and renamed securities are retained so that historical positions and transactions remain joinable to the state of the security at the time of the event. Non-equity instruments are excluded by policy.

### `dim_issuer`
Governed issuer master with parent/subsidiary hierarchy. Used to aggregate exposure and concentration above the legal-entity level. Hierarchy is effective-dated so that historical attribution does not move when corporate structure changes. Only issuers of in-scope securities are published.

### `fact_position`
End-of-day account-level holdings, one row per (account, security, as_of_date). The metric of record for assets under management, exposure, and attribution at a point in time. Positions are reported at the account level and are not netted across accounts. Intraday holdings are excluded by policy.

### `fact_transaction`
Executed trades and capital actions (dividends, splits, corporate-action driven position changes) at the account level. The metric of record for activity, turnover, and position-delta explanation. Cancelled and unsettled trades are excluded; only settled, effective activity is published. Derivatives activity is excluded by policy.

### `fact_benchmark_constituent`
Benchmark membership bridge with effective dating, one row per (benchmark, security, effective period). Supports active weight, attribution, and relative risk. For v1 the only published benchmark is the S&P 500. Off-benchmark securities held by accounts remain in `fact_position` but do not appear here.

## Grain

| Product | Grain | Uniqueness key |
|---|---|---|
| `dim_security` | One row per security per effective period | (`security_key`, `effective_start_date`) |
| `dim_issuer` | One row per issuer per effective period | (`issuer_key`, `effective_start_date`) |
| `fact_position` | One row per account, security, end-of-day | (`account_key`, `security_key`, `as_of_date`) |
| `fact_transaction` | One row per settled trade or capital action | `transaction_id` |
| `fact_benchmark_constituent` | One row per benchmark, security, effective period | (`benchmark_key`, `security_key`, `effective_start_date`) |

Slowly-changing attributes on the two dimensions use Type 2 effective dating. The currently active row for a key has `effective_end_date IS NULL`.

## Refresh & SLA

| Product | Cadence | Freshness SLA | Change policy |
|---|---|---|---|
| `dim_security` | Daily, T+1 from Azure SQL reference | `max(effective_start_date) >= current_date - 2` | Additive attributes non-breaking; rename or semantic change requires new version |
| `dim_issuer` | Daily, T+1 from Azure SQL reference | `max(effective_start_date) >= current_date - 2` | Same as `dim_security` |
| `fact_position` | Daily, T+1 close from PostgreSQL | `max(as_of_date) >= current_date - 2` | Additive columns non-breaking; grain change is breaking |
| `fact_transaction` | Daily, T+1 from PostgreSQL | `max(trade_date) >= current_date - 2` | Additive columns non-breaking; reclassification of `transaction_type` is breaking |
| `fact_benchmark_constituent` | Monthly scheduled rebalance plus event-driven refresh on corporate actions | `max(effective_start_date) >= current_date - 35` | Additive non-breaking; benchmark scope expansion is breaking |

All products refresh as a single workflow. A failure in any upstream task blocks publication of the entire suite so that cross-table joins always read a consistent vintage.

## Semantics

### `dim_security`
| Field | Meaning |
|---|---|
| `security_key` | Surrogate key. Stable across Type 2 versions of the same natural security. |
| `cusip` | 9-character CUSIP. Identifier of record for US equities. |
| `isin` | 12-character ISIN. Cross-reference identifier. |
| `ticker` | Current listing ticker. Can change over time; use `security_key` for joins. |
| `issuer_key` | FK to `dim_issuer`. Always resolvable at publication time. |
| `sector` / `industry` | GICS classification at the effective date. |
| `listing_status` | `Active` or `Delisted`. |
| `termination_date` | Populated for delisted securities. Null while active. |
| `effective_start_date` / `effective_end_date` | Type 2 validity window. |

### `dim_issuer`
| Field | Meaning |
|---|---|
| `issuer_key` | Surrogate key. Stable across Type 2 versions. |
| `lei` | Legal Entity Identifier. Identifier of record for the issuer. |
| `issuer_name` | Legal name at the effective date. |
| `parent_issuer_key` | FK to `dim_issuer` on self. Null for ultimate parents. |
| `country_of_domicile` | ISO-3166 alpha-2. Expected `US` for v1. |
| `effective_start_date` / `effective_end_date` | Type 2 validity window. |

### `fact_position`
| Field | Meaning |
|---|---|
| `account_key` | FK to account dimension. |
| `security_key` | FK to `dim_security` effective on `as_of_date`. |
| `as_of_date` | End-of-day date the position is stated for. |
| `quantity` | Share count held at close. Signed; negative indicates short. |
| `price` | Closing price used for valuation. Source of truth for the row's `market_value`. |
| `market_value` | `quantity * price`. Metric of record for exposure. |
| `cost_basis` | Running basis. Source of truth for unrealized P&L at the row level. |
| `currency` | Position reporting currency. Expected `USD` for v1. |

### `fact_transaction`
| Field | Meaning |
|---|---|
| `transaction_id` | Unique. Natural key from source. |
| `account_key` | FK to account dimension. |
| `security_key` | FK to `dim_security` effective on `trade_date`. |
| `trade_date` | Execution date. |
| `settle_date` | Settlement date. |
| `transaction_type` | Enum: `Buy`, `Sell`, `Dividend`, `Split`, `Spinoff`, `Merger`, `Other`. |
| `quantity` | Share count transacted. Signed. |
| `price` | Execution price per share. |
| `gross_amount` | `quantity * price`. |
| `net_amount` | `gross_amount` net of fees and commissions. Metric of record for cash impact. |
| `fees` / `commissions` | Components of `gross_amount - net_amount`. Do not recompute downstream. |

### `fact_benchmark_constituent`
| Field | Meaning |
|---|---|
| `benchmark_key` | FK to benchmark dimension. For v1 a single value (S&P 500). |
| `security_key` | FK to `dim_security` effective on `effective_start_date`. |
| `effective_start_date` / `effective_end_date` | Membership validity window. |
| `weight_pct` | Index weight at the effective date. Metric of record for active-weight calculation. |
| `shares_held` | Index-implied share count. Reference field, not a weight input. |

## Quality gates (blocking)

All gates are blocking. Any failure fails the workflow and blocks publication of the entire suite. Gates are grouped by category following the revenue data product pattern (Completeness, Policy, Grain, Freshness, Reconciliation).

### Identifier integrity (Completeness)
- Zero nulls in `cusip` and `isin` on `dim_security`.
- `cusip` passes the standard CUSIP check-digit algorithm for every row.
- `isin` passes the standard ISIN check-digit algorithm for every row.
- Zero nulls in `lei` on `dim_issuer`.

### Grain uniqueness (Grain)
- `transaction_id` unique across `fact_transaction`.
- (`account_key`, `security_key`, `as_of_date`) unique across `fact_position`.
- No overlapping effective periods for the same `security_key` in `dim_security`.
- No overlapping effective periods for the same `issuer_key` in `dim_issuer`.
- No overlapping effective periods for the same (`benchmark_key`, `security_key`) in `fact_benchmark_constituent`.

### Survivorship (Policy)
- Delisted securities are retained in `dim_security` with `listing_status = 'Delisted'` and a populated `termination_date`. The gate asserts that no prior `security_key` observed in historical `fact_position` or `fact_transaction` is missing from `dim_security`.

### Position-to-transaction tie-out (Reconciliation)
- For every (`account_key`, `security_key`) with activity in the window, the sum of signed `quantity` from `fact_transaction` between two consecutive position snapshots reconciles to the `fact_position` quantity delta within a tolerance of 0.5 shares. Breaks are logged with the reconciling delta and failing key.

### Market value check (Policy)
- For every `fact_position` row, `abs(market_value - quantity * price) / abs(market_value)` is within 1%. The gate guards against stale prices, rounding regressions, and unit-of-measure drift.

### Issuer hierarchy integrity (Policy)
- Every non-null `parent_issuer_key` in `dim_issuer` resolves to an effective-dated parent row.
- No cycles in the `issuer_key -> parent_issuer_key` graph, validated at publication time.

### Benchmark constituent completeness (Policy)
- For every (`benchmark_key`, effective period), `sum(weight_pct)` is within `100% +/- 0.1%`. The tolerance accommodates rounding at the published weight precision and is enforced per snapshot, not across snapshots.

### Corporate action detection (Policy)
- Day-over-day absolute change in `quantity` for a given (`account_key`, `security_key`) exceeding 50% day-over-day without a matching `Split`, `Spinoff`, `Merger`, or `Other` row in `fact_transaction` on or before `as_of_date` is flagged. This gate emits a warning to the runs table rather than blocking, because legitimate rebalances can trip the heuristic. Unreviewed warnings older than 5 business days escalate to blocking on the subsequent run.
- Gate severity: warning with escalation. A warning on first detection; blocking if unreviewed after 5 business days.

### Freshness (Freshness)
- Each product meets its freshness SLA stated in the Refresh & SLA table.

### Source-to-curated reconciliation (Reconciliation)
- Row count drift between the source row population and the curated row count is within 1% for each product, computed against the same source systems the ingestion reads.

Referential integrity between facts and dimensions is enforced at build time via inner joins on the effective-dated dimension row, not as a runtime gate.

## Exclusions (by design)

The following are intentionally out of scope for v1. Consumers needing any of them should use a separate pipeline product, not this suite.

- **Non-equity instruments.** Fixed income, derivatives, funds, and structured products are excluded. Only listed US common and preferred equity is in scope.
- **Non-US domicile.** Only securities with `country_of_domicile = 'US'` on `dim_issuer` are published.
- **Benchmarks other than S&P 500.** Additional benchmark scope is a breaking change and will be versioned.
- **Derivatives pricing and greeks.** Out of scope; no pricing model is published.
- **Private and illiquid valuations.** Only exchange-close prices are accepted. Level 2 and Level 3 valuations are out of scope.
- **Currency conversion.** All amounts are reported in the transaction's native currency, expected `USD` for v1. No FX translation is performed.
- **Intraday granularity.** Positions and transactions are end-of-day only. Intraday snapshots, tick data, and order-book state are out of scope.
- **Corporate actions as a standalone product.** Corporate actions are reflected in `fact_transaction` rows and in `dim_security` effective dating. A dedicated corporate actions product is a future iteration.
