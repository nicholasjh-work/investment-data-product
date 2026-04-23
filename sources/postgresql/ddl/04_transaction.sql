-- Executed trades and capital actions.
DROP TABLE IF EXISTS investments_act.transaction CASCADE;

CREATE TABLE investments_act.transaction (
    transaction_id     VARCHAR(64)    NOT NULL PRIMARY KEY,
    account_key        BIGINT         NOT NULL,
    security_key       BIGINT         NOT NULL,
    trade_date         DATE           NOT NULL,
    settle_date        DATE           NOT NULL,
    transaction_type   VARCHAR(16)    NOT NULL,
    quantity           NUMERIC(20,6)  NOT NULL,
    price              NUMERIC(18,6)  NOT NULL,
    gross_amount       NUMERIC(20,4)  NOT NULL,
    net_amount         NUMERIC(20,4)  NOT NULL,
    fees               NUMERIC(18,4)  NOT NULL DEFAULT 0,
    commissions        NUMERIC(18,4)  NOT NULL DEFAULT 0,
    currency           CHAR(3)        NOT NULL DEFAULT 'USD',
    source_system      VARCHAR(50)    NOT NULL DEFAULT 'POSTGRES_ACT',
    source_updated_at  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_txn_type CHECK (transaction_type IN ('Buy','Sell','Dividend','Split','Spinoff','Merger','Other'))
);

CREATE INDEX ix_txn_account ON investments_act.transaction (account_key);
CREATE INDEX ix_txn_sec ON investments_act.transaction (security_key);
CREATE INDEX ix_txn_trade_date ON investments_act.transaction (trade_date);
