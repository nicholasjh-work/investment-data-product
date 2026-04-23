-- Account dimension for the activity system.
DROP TABLE IF EXISTS investments_act.account CASCADE;

CREATE TABLE investments_act.account (
    account_key        BIGINT        NOT NULL PRIMARY KEY,
    account_number     VARCHAR(32)   NOT NULL UNIQUE,
    account_name       VARCHAR(255)  NOT NULL,
    account_type       VARCHAR(32)   NOT NULL,
    base_currency      CHAR(3)       NOT NULL DEFAULT 'USD',
    opened_date        DATE          NOT NULL,
    closed_date        DATE          NULL,
    source_system      VARCHAR(50)   NOT NULL DEFAULT 'POSTGRES_ACT',
    source_updated_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);
