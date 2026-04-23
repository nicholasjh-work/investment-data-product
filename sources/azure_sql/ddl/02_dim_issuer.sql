-- Issuer master with Type 2 effective dating and self-referential parent hierarchy.
-- Simulates Azure SQL reference data.
DROP TABLE IF EXISTS investments_ref.dim_issuer CASCADE;

CREATE TABLE investments_ref.dim_issuer (
    issuer_key            BIGINT        NOT NULL,
    lei                   CHAR(20)      NOT NULL,
    issuer_name           VARCHAR(255)  NOT NULL,
    parent_issuer_key     BIGINT        NULL,
    country_of_domicile   CHAR(2)       NOT NULL DEFAULT 'US',
    effective_start_date  DATE          NOT NULL,
    effective_end_date    DATE          NULL,
    source_system         VARCHAR(50)   NOT NULL DEFAULT 'AZURE_SQL_REF',
    source_updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (issuer_key, effective_start_date)
);

CREATE INDEX ix_dim_issuer_lei ON investments_ref.dim_issuer (lei);
CREATE INDEX ix_dim_issuer_parent ON investments_ref.dim_issuer (parent_issuer_key);
CREATE INDEX ix_dim_issuer_active ON investments_ref.dim_issuer (issuer_key) WHERE effective_end_date IS NULL;
