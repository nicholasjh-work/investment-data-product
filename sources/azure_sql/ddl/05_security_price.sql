-- Daily closing prices used for position valuation.
DROP TABLE IF EXISTS investments_ref.security_price CASCADE;

CREATE TABLE investments_ref.security_price (
    security_key       BIGINT         NOT NULL,
    price_date         DATE           NOT NULL,
    close_price        NUMERIC(18,6)  NOT NULL,
    currency           CHAR(3)        NOT NULL DEFAULT 'USD',
    source_system      VARCHAR(50)    NOT NULL DEFAULT 'AZURE_SQL_REF',
    source_updated_at  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (security_key, price_date)
);

CREATE INDEX ix_price_date ON investments_ref.security_price (price_date);
