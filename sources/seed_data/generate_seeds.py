"""Seed data generator for the investment data product.

Scrapes S&P 500 constituents from Wikipedia, picks 50, then generates
synthetic issuers, securities, benchmark constituents, daily prices,
positions (3 accounts x 20 securities), and transactions. Everything
is loaded into the investments_ref (Azure SQL sim) and investments_act
(PostgreSQL activity) schemas in the local investment_data database.
"""
from __future__ import annotations

import io
import random
import uuid
from datetime import date, timedelta
from decimal import Decimal

import pandas as pd
import psycopg2
import psycopg2.extras
import requests
from bs4 import BeautifulSoup

DB = dict(host="localhost", dbname="investment_data", user="nickhidalgo")
WIKI_URL = "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"
N_SECURITIES = 50
N_ACCOUNTS = 3
SEC_PER_ACCOUNT = 20
N_TRADING_DAYS = 252
BENCHMARK_KEY = 1
TODAY = date(2026, 4, 23)

RNG = random.Random(42)


def scrape_sp500() -> pd.DataFrame:
    resp = requests.get(WIKI_URL, headers={"User-Agent": "seed-generator/1.0"}, timeout=30)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")
    table = soup.find("table", {"id": "constituents"})
    df = pd.read_html(io.StringIO(str(table)))[0]
    df.columns = [str(c).strip() for c in df.columns]
    return df


def _cusip_check_digit(base8: str) -> str:
    total = 0
    for i, ch in enumerate(base8):
        if ch.isdigit():
            v = int(ch)
        elif ch.isalpha():
            v = ord(ch.upper()) - ord("A") + 10
        elif ch == "*":
            v = 36
        elif ch == "@":
            v = 37
        elif ch == "#":
            v = 38
        else:
            raise ValueError(ch)
        if i % 2 == 1:
            v *= 2
        total += v // 10 + v % 10
    return str((10 - (total % 10)) % 10)


def synth_cusip(seed: int) -> str:
    r = random.Random(seed)
    chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    base = "".join(r.choice(chars) for _ in range(8))
    return base + _cusip_check_digit(base)


def _isin_check_digit(body: str) -> str:
    digits = ""
    for ch in body:
        if ch.isdigit():
            digits += ch
        else:
            digits += str(ord(ch.upper()) - ord("A") + 10)
    total = 0
    for i, d in enumerate(reversed(digits)):
        n = int(d)
        if i % 2 == 0:
            n *= 2
            if n > 9:
                n -= 9
        total += n
    return str((10 - (total % 10)) % 10)


def synth_isin(cusip: str) -> str:
    body = "US" + cusip
    return body + _isin_check_digit(body)


def synth_lei(seed: int) -> str:
    # 20-char LEI: 18 alnum body + 2 digit check digits. For seeding we keep
    # format plausible, not ISO 17442 valid.
    r = random.Random(seed ^ 0xA11CE)
    chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    body = "".join(r.choice(chars) for _ in range(18))
    check = f"{r.randint(0, 99):02d}"
    return body + check


def build_reference(sp500: pd.DataFrame):
    sym_col = next(c for c in sp500.columns if c.lower().startswith("symbol"))
    name_col = next(c for c in sp500.columns if "security" in c.lower() or "company" in c.lower())
    sector_col = next((c for c in sp500.columns if "sector" in c.lower() and "sub" not in c.lower()), None)
    industry_col = next((c for c in sp500.columns if "industry" in c.lower() or "sub-industry" in c.lower()), None)

    picked = sp500.sample(n=N_SECURITIES, random_state=42).reset_index(drop=True)

    issuers = []
    securities = []
    for i, row in picked.iterrows():
        issuer_key = 1000 + i
        security_key = 2000 + i
        cusip = synth_cusip(security_key)
        isin = synth_isin(cusip)
        lei = synth_lei(issuer_key)
        ticker = str(row[sym_col]).replace(".", "-")[:16]
        issuers.append(dict(
            issuer_key=issuer_key,
            lei=lei,
            issuer_name=str(row[name_col])[:255],
            parent_issuer_key=None,
            country_of_domicile="US",
            effective_start_date=date(2015, 1, 1),
            effective_end_date=None,
        ))
        securities.append(dict(
            security_key=security_key,
            cusip=cusip,
            isin=isin,
            ticker=ticker,
            issuer_key=issuer_key,
            sector=(str(row[sector_col])[:64] if sector_col else None),
            industry=(str(row[industry_col])[:128] if industry_col else None),
            listing_status="Active",
            termination_date=None,
            effective_start_date=date(2015, 1, 1),
            effective_end_date=None,
        ))
    return issuers, securities


def build_benchmark(securities):
    n = len(securities)
    weight = round(100.0 / n, 6)
    rows = []
    for s in securities:
        rows.append(dict(
            benchmark_key=BENCHMARK_KEY,
            security_key=s["security_key"],
            effective_start_date=date(2025, 1, 1),
            effective_end_date=None,
            weight_pct=weight,
            shares_held=RNG.randint(1_000_000, 50_000_000),
        ))
    # nudge last row so sum == 100 exactly within 0.1%
    drift = round(100.0 - weight * n, 6)
    rows[-1]["weight_pct"] = round(weight + drift, 6)
    return rows


def build_prices(securities):
    start = TODAY - timedelta(days=int(N_TRADING_DAYS * 1.5))
    trading_days = []
    d = start
    while len(trading_days) < N_TRADING_DAYS:
        if d.weekday() < 5:
            trading_days.append(d)
        d += timedelta(days=1)

    rows = []
    for s in securities:
        r = random.Random(s["security_key"])
        price = r.uniform(30.0, 450.0)
        for day in trading_days:
            # geometric-ish random walk
            price *= 1.0 + r.gauss(0.0003, 0.015)
            price = max(price, 1.0)
            rows.append(dict(
                security_key=s["security_key"],
                price_date=day,
                close_price=round(price, 6),
                currency="USD",
            ))
    return rows, trading_days


def build_accounts():
    types = ["Institutional", "Pension", "SeparatelyManaged"]
    rows = []
    for i in range(N_ACCOUNTS):
        rows.append(dict(
            account_key=100 + i,
            account_number=f"ACC-{1000 + i}",
            account_name=f"Seed Account {i + 1}",
            account_type=types[i % len(types)],
            base_currency="USD",
            opened_date=date(2020, 1, 1),
            closed_date=None,
        ))
    return rows


def build_activity(accounts, securities, prices, trading_days):
    price_map = {(p["security_key"], p["price_date"]): p["close_price"] for p in prices}
    positions = []
    txns = []

    for acct in accounts:
        r = random.Random(acct["account_key"])
        sec_sample = r.sample(securities, SEC_PER_ACCOUNT)
        for s in sec_sample:
            # Opening buy at first trading day's price
            qty = r.randint(500, 5000)
            open_day = trading_days[0]
            open_px = price_map[(s["security_key"], open_day)]
            commissions = round(qty * 0.005, 4)
            fees = round(qty * 0.0002, 4)
            gross = round(qty * float(open_px), 4)
            net = round(gross + commissions + fees, 4)
            txns.append(dict(
                transaction_id=str(uuid.UUID(int=r.getrandbits(128))),
                account_key=acct["account_key"],
                security_key=s["security_key"],
                trade_date=open_day,
                settle_date=open_day + timedelta(days=2),
                transaction_type="Buy",
                quantity=qty,
                price=open_px,
                gross_amount=gross,
                net_amount=net,
                fees=fees,
                commissions=commissions,
                currency="USD",
            ))

            running_qty = qty
            running_cost = Decimal(str(net))

            # A handful of additional trades through the window
            n_extra = r.randint(2, 6)
            extra_days = sorted(r.sample(trading_days[5:-5], n_extra))
            for d in extra_days:
                side = r.choice(["Buy", "Sell"])
                trade_qty = r.randint(50, 500)
                if side == "Sell":
                    trade_qty = min(trade_qty, max(running_qty - 10, 1))
                    signed_qty = -trade_qty
                else:
                    signed_qty = trade_qty
                px = price_map[(s["security_key"], d)]
                commissions = round(trade_qty * 0.005, 4)
                fees = round(trade_qty * 0.0002, 4)
                gross = round(signed_qty * float(px), 4)
                if side == "Buy":
                    net = round(gross + commissions + fees, 4)
                    running_cost += Decimal(str(net))
                else:
                    net = round(gross - commissions - fees, 4)
                    # reduce cost basis proportionally
                    if running_qty > 0:
                        running_cost -= running_cost * Decimal(trade_qty) / Decimal(running_qty)
                running_qty += signed_qty
                txns.append(dict(
                    transaction_id=str(uuid.UUID(int=r.getrandbits(128))),
                    account_key=acct["account_key"],
                    security_key=s["security_key"],
                    trade_date=d,
                    settle_date=d + timedelta(days=2),
                    transaction_type=side,
                    quantity=signed_qty,
                    price=px,
                    gross_amount=gross,
                    net_amount=net,
                    fees=fees,
                    commissions=commissions,
                    currency="USD",
                ))

            # Build positions for every trading day, applying txns as they occur
            txn_by_day = {}
            for t in txns:
                if t["account_key"] == acct["account_key"] and t["security_key"] == s["security_key"]:
                    txn_by_day.setdefault(t["trade_date"], []).append(t)

            q = Decimal("0")
            cb = Decimal("0")
            for d in trading_days:
                for t in txn_by_day.get(d, []):
                    q += Decimal(str(t["quantity"]))
                    if t["transaction_type"] == "Buy":
                        cb += Decimal(str(t["net_amount"]))
                    elif t["transaction_type"] == "Sell":
                        if q + Decimal(str(-t["quantity"])) > 0:
                            prev_q = q - Decimal(str(t["quantity"]))
                            if prev_q > 0:
                                cb -= cb * (Decimal(str(-t["quantity"])) / prev_q)
                if q == 0:
                    continue
                px = price_map[(s["security_key"], d)]
                mv = (q * Decimal(str(px))).quantize(Decimal("0.0001"))
                positions.append(dict(
                    account_key=acct["account_key"],
                    security_key=s["security_key"],
                    as_of_date=d,
                    quantity=float(q),
                    price=float(px),
                    market_value=float(mv),
                    cost_basis=float(cb.quantize(Decimal("0.0001"))),
                    currency="USD",
                ))

    return positions, txns


def bulk_insert(cur, table: str, rows: list[dict]):
    if not rows:
        return 0
    cols = list(rows[0].keys())
    values = [[r[c] for c in cols] for r in rows]
    sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES %s"
    psycopg2.extras.execute_values(cur, sql, values, page_size=1000)
    return len(rows)


def truncate_all(cur):
    cur.execute("""
        TRUNCATE TABLE investments_act.transaction,
                       investments_act.position,
                       investments_act.account,
                       investments_ref.security_price,
                       investments_ref.benchmark_constituent,
                       investments_ref.dim_security,
                       investments_ref.dim_issuer
        RESTART IDENTITY
    """)


def main():
    print("Scraping S&P 500 constituents...")
    sp500 = scrape_sp500()
    print(f"  scraped {len(sp500)} rows; sampling {N_SECURITIES}")

    issuers, securities = build_reference(sp500)
    bench = build_benchmark(securities)
    prices, trading_days = build_prices(securities)
    accounts = build_accounts()
    print("Building activity...")
    positions, txns = build_activity(accounts, securities, prices, trading_days)

    conn = psycopg2.connect(**DB)
    conn.autocommit = False
    counts = {}
    try:
        with conn.cursor() as cur:
            truncate_all(cur)
            counts["investments_ref.dim_issuer"] = bulk_insert(cur, "investments_ref.dim_issuer", issuers)
            counts["investments_ref.dim_security"] = bulk_insert(cur, "investments_ref.dim_security", securities)
            counts["investments_ref.benchmark_constituent"] = bulk_insert(cur, "investments_ref.benchmark_constituent", bench)
            counts["investments_ref.security_price"] = bulk_insert(cur, "investments_ref.security_price", prices)
            counts["investments_act.account"] = bulk_insert(cur, "investments_act.account", accounts)
            counts["investments_act.position"] = bulk_insert(cur, "investments_act.position", positions)
            counts["investments_act.transaction"] = bulk_insert(cur, "investments_act.transaction", txns)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    print("\nRow counts:")
    for t, n in counts.items():
        print(f"  {t:50s} {n:>10,d}")


if __name__ == "__main__":
    main()
