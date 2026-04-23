-- End-of-day account-level holdings.
DROP TABLE IF EXISTS investments_act.position CASCADE;

CREATE TABLE investments_act.position (
    account_key        BIGINT         NOT NULL,
    security_key       BIGINT         NOT NULL,
    as_of_date         DATE           NOT NULL,
    quantity           NUMERIC(20,6)  NOT NULL,
    price              NUMERIC(18,6)  NOT NULL,
    market_value       NUMERIC(20,4)  NOT NULL,
    cost_basis         NUMERIC(20,4)  NOT NULL,
    currency           CHAR(3)        NOT NULL DEFAULT 'USD',
    source_system      VARCHAR(50)    NOT NULL DEFAULT 'POSTGRES_ACT',
    source_updated_at  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (account_key, security_key, as_of_date)
);

CREATE INDEX ix_position_asof ON investments_act.position (as_of_date);
CREATE INDEX ix_position_sec ON investments_act.position (security_key);
