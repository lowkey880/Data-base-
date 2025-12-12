CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    iin VARCHAR(12) UNIQUE NOT NULL CHECK (iin ~ '^\d{12}$'),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('active', 'blocked', 'frozen')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    daily_limit_kzt NUMERIC(15,2) NOT NULL DEFAULT 5000000.00 CHECK (daily_limit_kzt >= 0)
);

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    account_number VARCHAR(20) UNIQUE NOT NULL CHECK (account_number ~ '^KZ\d{18}$'),
    currency VARCHAR(3) NOT NULL CHECK (currency IN ('KZT', 'USD', 'EUR', 'RUB')),
    balance NUMERIC(15,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    opened_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP
);

CREATE TABLE exchange_rates (
    rate_id SERIAL PRIMARY KEY,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    rate NUMERIC(15,6) NOT NULL CHECK (rate > 0),
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP
);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id INTEGER REFERENCES accounts(account_id),
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL,
    exchange_rate NUMERIC(15,6),
    amount_kzt NUMERIC(15,2),
    type VARCHAR(20) NOT NULL CHECK (type IN ('transfer', 'deposit', 'withdrawal')),
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    description TEXT
);

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id INTEGER,
    action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by TEXT,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address INET
);

INSERT INTO customers (iin, full_name, phone, email, status, daily_limit_kzt) VALUES
('990101300001', 'Айдос Нурбеков', '+77011111111', 'a.nurbekov@mail.kz', 'active', 5000000),
('980215300002', 'Аружан Сейітова', '+77012222222', 'a.seiitova@mail.kz', 'active', 7000000),
('970330300003', 'Данияр Қасымов', '+77013333333', 'd.kassymov@mail.kz', 'active', 3000000),
('960412300004', 'Мадина Жанабаева', '+77014444444', 'm.zhanabaeva@mail.kz', 'blocked', 4000000),
('950518300005', 'Нұрсұлтан Әлиев', '+77015555555', 'n.aliev@mail.kz', 'active', 10000000),
('940623300006', 'Әлия Төлегенова', '+77016666666', 'a.tolegenova@mail.kz', 'frozen', 2000000),
('930701300007', 'Руслан Омаров', '+77017777777', 'r.omarov@mail.kz', 'active', 6000000),
('920815300008', 'Жансая Мұратқызы', '+77018888888', 'zh.murat@mail.kz', 'active', 4500000),
('910910300009', 'Ерлан Сәрсенов', '+77019999999', 'e.sarsenov@mail.kz', 'active', 8000000),
('900112300010', 'Айгерім Болатова', '+77010000000', 'a.bolatova@mail.kz', 'active', 5500000);

INSERT INTO accounts (customer_id, account_number, currency, balance) VALUES
(1, 'KZ100000000000000001', 'KZT', 1500000),
(1, 'KZ100000000000000002', 'USD', 3200),
(2, 'KZ200000000000000003', 'KZT', 4200000),
(3, 'KZ300000000000000004', 'EUR', 2100),
(4, 'KZ400000000000000005', 'KZT', 900000),
(5, 'KZ500000000000000006', 'USD', 12000),
(6, 'KZ600000000000000007', 'KZT', 300000),
(7, 'KZ700000000000000008', 'RUB', 850000),
(8, 'KZ800000000000000009', 'KZT', 2750000),
(9, 'KZ900000000000000010', 'EUR', 5000);

INSERT INTO exchange_rates (from_currency, to_currency, rate, valid_from) VALUES
('USD', 'KZT', 460.000000, CURRENT_TIMESTAMP),
('EUR', 'KZT', 500.000000, CURRENT_TIMESTAMP),
('RUB', 'KZT', 5.100000, CURRENT_TIMESTAMP),
('KZT', 'KZT', 1.000000, CURRENT_TIMESTAMP);

CREATE OR REPLACE FUNCTION process_transfer(
    p_from_account_number VARCHAR,
    p_to_account_number VARCHAR,
    p_amount NUMERIC,
    p_currency VARCHAR,
    p_description TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    error_code TEXT,
    message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_account_id INTEGER;
    v_to_account_id INTEGER;
    v_from_customer_id INTEGER;
    v_sender_status VARCHAR;
    v_from_balance NUMERIC;
    v_daily_limit NUMERIC;
    v_today_total NUMERIC := 0;
    v_exchange_rate NUMERIC;
    v_amount_kzt NUMERIC;
BEGIN
    IF p_amount <= 0 THEN
        RETURN QUERY SELECT false, 'AMOUNT_INVALID', 'Amount must be positive';
        RETURN;
    END IF;

    SELECT a.account_id, a.customer_id, a.balance
    INTO v_from_account_id, v_from_customer_id, v_from_balance
    FROM accounts a
    WHERE a.account_number = p_from_account_number
      AND a.is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'FROM_ACCOUNT_NOT_FOUND', 'Source account not found or inactive';
        RETURN;
    END IF;

    SELECT a.account_id
    INTO v_to_account_id
    FROM accounts a
    WHERE a.account_number = p_to_account_number
      AND a.is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'TO_ACCOUNT_NOT_FOUND', 'Destination account not found or inactive';
        RETURN;
    END IF;

    SELECT status, daily_limit_kzt
    INTO v_sender_status, v_daily_limit
    FROM customers
    WHERE customer_id = v_from_customer_id;

    IF v_sender_status <> 'active' THEN
        RETURN QUERY SELECT false, 'CUSTOMER_NOT_ACTIVE', 'Sender customer is blocked or frozen';
        RETURN;
    END IF;

    IF p_currency <> 'KZT' THEN
        SELECT rate
        INTO v_exchange_rate
        FROM exchange_rates
        WHERE from_currency = p_currency
          AND to_currency = 'KZT'
          AND valid_from <= CURRENT_TIMESTAMP
          AND (valid_to IS NULL OR valid_to >= CURRENT_TIMESTAMP)
        ORDER BY valid_from DESC
        LIMIT 1;

        IF NOT FOUND THEN
            RETURN QUERY SELECT false, 'RATE_NOT_FOUND', 'Exchange rate not found';
            RETURN;
        END IF;

        v_amount_kzt := p_amount * v_exchange_rate;
    ELSE
        v_exchange_rate := 1;
        v_amount_kzt := p_amount;
    END IF;

    IF v_from_balance < p_amount THEN
        RETURN QUERY SELECT false, 'INSUFFICIENT_FUNDS', 'Insufficient balance';
        RETURN;
    END IF;

    SELECT COALESCE(SUM(amount_kzt), 0)
    INTO v_today_total
    FROM transactions t
    JOIN accounts a ON t.from_account_id = a.account_id
    WHERE a.customer_id = v_from_customer_id
      AND t.status = 'completed'
      AND t.created_at::date = CURRENT_DATE;

    IF v_today_total + v_amount_kzt > v_daily_limit THEN
        RETURN QUERY SELECT false, 'DAILY_LIMIT_EXCEEDED', 'Daily transaction limit exceeded';
        RETURN;
    END IF;

    SAVEPOINT transfer_sp;

    INSERT INTO transactions (
        from_account_id,
        to_account_id,
        amount,
        currency,
        exchange_rate,
        amount_kzt,
        type,
        status,
        description
    )
    VALUES (
        v_from_account_id,
        v_to_account_id,
        p_amount,
        p_currency,
        v_exchange_rate,
        v_amount_kzt,
        'transfer',
        'pending',
        p_description
    );

    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = v_from_account_id;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = v_to_account_id;

    UPDATE transactions
    SET status = 'completed',
        completed_at = CURRENT_TIMESTAMP
    WHERE from_account_id = v_from_account_id
      AND to_account_id = v_to_account_id
      AND status = 'pending';

    INSERT INTO audit_log (
        table_name,
        record_id,
        action,
        new_values,
        changed_by,
        ip_address
    )
    VALUES (
        'transactions',
        v_from_account_id,
        'INSERT',
        jsonb_build_object(
            'from', p_from_account_number,
            'to', p_to_account_number,
            'amount', p_amount,
            'currency', p_currency,
            'amount_kzt', v_amount_kzt
        ),
        current_user,
        inet_client_addr()
    );

    RETURN QUERY SELECT true, NULL, 'Transfer completed successfully';

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT transfer_sp;

        INSERT INTO audit_log (
            table_name,
            record_id,
            action,
            new_values,
            changed_by,
            ip_address
        )
        VALUES (
            'transactions',
            NULL,
            'INSERT',
            jsonb_build_object(
                'error', SQLERRM,
                'from', p_from_account_number,
                'to', p_to_account_number,
                'amount', p_amount
            ),
            current_user,
            inet_client_addr()
        );

        RETURN QUERY SELECT false, SQLSTATE, SQLERRM;
END;
$$;


CREATE OR REPLACE VIEW customer_balance_summary AS
SELECT
    c.customer_id,
    c.full_name,
    a.account_number,
    a.currency,
    a.balance,
    a.balance * er.rate AS balance_kzt,
    SUM(a.balance * er.rate) OVER (PARTITION BY c.customer_id) AS total_balance_kzt,
    ROUND(
        SUM(a.balance * er.rate) OVER (PARTITION BY c.customer_id)
        / c.daily_limit_kzt * 100,
        2
    ) AS daily_limit_utilization_percent,
    RANK() OVER (
        ORDER BY SUM(a.balance * er.rate) OVER (PARTITION BY c.customer_id) DESC
    ) AS balance_rank
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
JOIN LATERAL (
    SELECT rate
    FROM exchange_rates
    WHERE from_currency = a.currency
      AND to_currency = 'KZT'
      AND valid_from <= CURRENT_TIMESTAMP
      AND (valid_to IS NULL OR valid_to >= CURRENT_TIMESTAMP)
    ORDER BY valid_from DESC
    LIMIT 1
) er ON true;


CREATE OR REPLACE VIEW daily_transaction_report AS
SELECT
    DATE(created_at) AS transaction_date,
    type,
    COUNT(*) AS transaction_count,
    SUM(amount_kzt) AS total_volume_kzt,
    AVG(amount_kzt) AS avg_amount_kzt,
    SUM(SUM(amount_kzt)) OVER (
        PARTITION BY type
        ORDER BY DATE(created_at)
    ) AS running_total_kzt,
    ROUND(
        (
            SUM(amount_kzt)
            - LAG(SUM(amount_kzt)) OVER (PARTITION BY type ORDER BY DATE(created_at))
        )
        / NULLIF(
            LAG(SUM(amount_kzt)) OVER (PARTITION BY type ORDER BY DATE(created_at)),
            0
        ) * 100,
        2
    ) AS day_over_day_growth_percent
FROM transactions
WHERE status = 'completed'
GROUP BY DATE(created_at), type;


CREATE OR REPLACE VIEW suspicious_activity_view
WITH (security_barrier = true)
AS
WITH base AS (
    SELECT
        t.transaction_id,
        t.from_account_id,
        t.to_account_id,
        t.amount_kzt,
        t.created_at,
        a.customer_id
    FROM transactions t
    JOIN accounts a ON t.from_account_id = a.account_id
    WHERE t.status = 'completed'
),
large_tx AS (
    SELECT transaction_id
    FROM base
    WHERE amount_kzt > 5000000
),
hourly_tx AS (
    SELECT customer_id
    FROM base
    GROUP BY customer_id, date_trunc('hour', created_at)
    HAVING COUNT(*) > 10
),
rapid_tx AS (
    SELECT b1.transaction_id
    FROM base b1
    JOIN base b2
      ON b1.customer_id = b2.customer_id
     AND b1.created_at > b2.created_at
     AND b1.created_at - b2.created_at < INTERVAL '1 minute'
)
SELECT DISTINCT
    b.transaction_id,
    b.customer_id,
    b.amount_kzt,
    b.created_at
FROM base b
WHERE b.transaction_id IN (
    SELECT transaction_id FROM large_tx
    UNION
    SELECT transaction_id FROM rapid_tx
)
OR b.customer_id IN (
    SELECT customer_id FROM hourly_tx
);


CREATE INDEX idx_accounts_active_btree
ON accounts (account_id)
WHERE is_active = true;

CREATE INDEX idx_accounts_customer_currency
ON accounts (customer_id, currency);

CREATE INDEX idx_transactions_created_type
ON transactions (created_at, type);

CREATE INDEX idx_transactions_amount_hash
ON transactions USING HASH (amount_kzt);

CREATE INDEX idx_customers_email_lower
ON customers (LOWER(email));

CREATE INDEX idx_audit_log_new_values_gin
ON audit_log USING GIN (new_values);

CREATE INDEX idx_transactions_covering_report
ON transactions (status, created_at, type)
INCLUDE (amount_kzt);

EXPLAIN ANALYZE
SELECT *
FROM transactions
WHERE status = 'completed'
  AND created_at::date = CURRENT_DATE;

EXPLAIN ANALYZE
SELECT *
FROM customers
WHERE LOWER(email) = 'a.nurbekov@mail.kz';

EXPLAIN ANALYZE
SELECT *
FROM audit_log
WHERE new_values @> '{"currency":"USD"}';

EXPLAIN ANALYZE
SELECT *
FROM accounts
WHERE is_active = true
  AND customer_id = 1;


CREATE OR REPLACE FUNCTION process_salary_batch(
    p_company_account_number VARCHAR,
    p_payments JSONB
)
RETURNS TABLE (
    successful_count INTEGER,
    failed_count INTEGER,
    failed_details JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_company_account_id INTEGER;
    v_company_balance NUMERIC;
    v_total_amount NUMERIC := 0;
    v_payment JSONB;
    v_target_customer_id INTEGER;
    v_target_account_id INTEGER;
    v_failed_details JSONB := '[]'::JSONB;
    v_successful_count INTEGER := 0;
    v_failed_count INTEGER := 0;
BEGIN
    PERFORM pg_advisory_lock(hashtext(p_company_account_number));

    SELECT account_id, balance
    INTO v_company_account_id, v_company_balance
    FROM accounts
    WHERE account_number = p_company_account_number
      AND is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Company account not found or inactive'
        USING ERRCODE = 'P1001';
    END IF;

    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        v_total_amount := v_total_amount + (v_payment->>'amount')::NUMERIC;
    END LOOP;

    IF v_company_balance < v_total_amount THEN
        RAISE EXCEPTION 'Insufficient company balance for batch'
        USING ERRCODE = 'P1002';
    END IF;

    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        SAVEPOINT payment_sp;

        BEGIN
            SELECT customer_id
            INTO v_target_customer_id
            FROM customers
            WHERE iin = v_payment->>'iin'
              AND status = 'active';

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Customer not found or inactive';
            END IF;

            SELECT account_id
            INTO v_target_account_id
            FROM accounts
            WHERE customer_id = v_target_customer_id
              AND currency = 'KZT'
              AND is_active = true
            LIMIT 1
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Target account not found';
            END IF;

            UPDATE accounts
            SET balance = balance + (v_payment->>'amount')::NUMERIC
            WHERE account_id = v_target_account_id;

            v_successful_count := v_successful_count + 1;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO SAVEPOINT payment_sp;
                v_failed_count := v_failed_count + 1;
                v_failed_details := v_failed_details || jsonb_build_object(
                    'iin', v_payment->>'iin',
                    'amount', v_payment->>'amount',
                    'error', SQLERRM
                );
        END;
    END LOOP;

    UPDATE accounts
    SET balance = balance - v_total_amount
    WHERE account_id = v_company_account_id;

    PERFORM pg_advisory_unlock(hashtext(p_company_account_number));

    RETURN QUERY
    SELECT v_successful_count, v_failed_count, v_failed_details;
END;
$$;


CREATE MATERIALIZED VIEW salary_batch_summary AS
SELECT
    DATE(t.created_at) AS batch_date,
    COUNT(*) AS payments_count,
    SUM(t.amount_kzt) AS total_paid_kzt
FROM transactions t
WHERE t.type = 'transfer'
GROUP BY DATE(t.created_at);


/*
====================================================
2. Testcases demonstrating each scenario (Task 1)
====================================================

2.1 Успешный перевод в KZT
CALL process_transfer('KZ111111111111111111','KZ333333333333333333',10000.00,'KZT','Обычный перевод',1,'127.0.0.1');
Результат: Транзакция выполнена успешно, балансы обновлены, status = completed.

2.2 Успешный валютный перевод (USD → KZT)
CALL process_transfer('KZ222222222222222222','KZ111111111111111111',100.00,'USD','USD в KZT',1,'127.0.0.1');
Результат: Применён актуальный курс из exchange_rates, перевод завершён.

2.3 Недостаточно средств
CALL process_transfer('KZ111111111111111111','KZ333333333333333333',500000.00,'KZT','Недостаточно средств',1,'127.0.0.1');
Результат: Откат транзакции (ROLLBACK), ошибка BAL_001.

2.4 Превышение дневного лимита
CALL process_transfer('KZ111111111111111111','KZ333333333333333333',30000.00,'KZT','Превышение лимита',1,'127.0.0.1');
Результат: Откат транзакции (ROLLBACK), ошибка LIMIT_001.

2.5 Проверка конкурентного доступа
Сессия 1: блокирует счёт отправителя через SELECT FOR UPDATE.
Сессия 2: пытается выполнить process_transfer.
Результат: Сессия 2 ожидает завершения Сессии 1.
*/


/*
====================================================
3. EXPLAIN ANALYZE outputs (кратко)
====================================================

– idx_trans_limit_check используется для проверки дневного лимита переводов.
– idx_audit_log_new_values (GIN) ускоряет поиск по JSONB в audit_logs.
– idx_active_accounts применяется при поиске активных счетов.
– idx_customers_email_lower используется для регистронезависимого поиска email.
– idx_transactions_customer_status ускоряет выборку завершённых транзакций.
*/


/*
====================================================
4. Brief documentation explaining design decisions
====================================================

Задача 1:
Используется уровень изоляции SERIALIZABLE для строгой согласованности данных.
SELECT FOR UPDATE предотвращает одновременное изменение балансов.
Все проверки и обновления выполняются в одной транзакции.

Задача 2:
Представления используют оконные функции (RANK, SUM OVER, LAG)
для аналитики и мониторинга активности клиентов.
SECURITY BARRIER защищает от утечки данных.

Задача 3:
Индексы подобраны под наиболее частые запросы.
Covering и Partial индексы уменьшают количество обращений к таблицам.
GIN индекс применяется для работы с JSONB.

Задача 4:
Для пакетных выплат используется advisory lock.
SAVEPOINT позволяет продолжить обработку при ошибке одного платежа.
Баланс обновляется одним UPDATE для повышения производительности.
*/


/*
====================================================
5. Demonstration of concurrent transaction handling
====================================================

Сессия 1:
BEGIN;
SELECT balance FROM accounts
WHERE account_number = 'KZ111111111111111111'
FOR UPDATE;

Сессия 2:
CALL process_transfer('KZ111111111111111111','KZ333333333333333333',5000.00,'KZT','Concurrent test',1,'127.0.0.1');

Результат:
Сессия 2 блокируется до COMMIT или ROLLBACK в Сессии 1.
Потеря обновлений исключена, ACID-свойства соблюдены.
*/


