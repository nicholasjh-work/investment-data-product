-- Security master with Type 2 effective dating.
DROP TABLE IF EXISTS investments_ref.dim_security CASCADE;

CREATE TABLE investments_ref.dim_security (
    security_key          BIGINT        NOT NULL,
    cusip                 CHAR(9)       NOT NULL,
    isin                  CHAR(12)      NOT NULL,
    ticker                VARCHAR(16)   NOT NULL,
    issuer_key            BIGINT        NOT NULL,
    sector                VARCHAR(64)   NULL,
    industry              VARCHAR(128)  NULL,
    listing_status        VARCHAR(16)   NOT NULL DEFAULT 'Active',
    termination_date      DATE          NULL,
    effective_start_date  DATE          NOT NULL,
    effective_end_date    DATE          NULL,
    source_system         VARCHAR(50)   NOT NULL DEFAULT 'AZURE_SQL_REF',
    source_updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (security_key, effective_start_date),
    CONSTRAINT ck_dim_security_listing CHECK (listing_status IN ('Active','Delisted'))
);

CREATE INDEX ix_dim_security_cusip ON investments_ref.dim_security (cusip);
CREATE INDEX ix_dim_security_isin ON investments_ref.dim_security (isin);
CREATE INDEX ix_dim_security_ticker ON investments_ref.dim_security (ticker);
CREATE INDEX ix_dim_security_issuer ON investments_ref.dim_security (issuer_key);
CREATE INDEX ix_dim_security_active ON investments_ref.dim_security (security_key) WHERE effective_end_date IS NULL;
