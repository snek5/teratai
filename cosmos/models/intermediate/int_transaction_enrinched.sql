{{
    config(
        materialized='incremental',
        unique_key='transaction_sk',
        incremental_strategy='merge',
        partition_by=['transaction_year', 'transaction_month'],
        cluster_by=['customer_id', 'transaction_date'],
        tags=['intermediate', 'enriched_transactions']
    )
}}

with transactions as (
    select 
        transaction_id,
        account_id,
        merchant_id,
        amount_usd,
        transaction_date,
        transaction_year,
        transaction_month,
        transaction_quarter,
        transaction_dayofweek,
        transaction_size,
        time_of_day,
        day_type,
        is_holiday
    from {{ ref('stg_transactions') }}
    {% if is_incremental() %}
        {{ incremental_date_filter('transaction_date') }}
    {% endif %}
),

accounts as (
    select 
        account_id,
        customer_id,
        account_type,
        balance_usd as account_balance
    from {{ ref('stg_accounts') }}
),

customers as (
    select 
        customer_id,
        first_name,
        last_name,
        credit_score,
        credit_rating,
        customer_tier
    from {{ ref('stg_customers') }}
),

merchants as (
    select 
        merchant_id,
        merchant_name,
        city as merchant_city
    from {{ ref('stg_merchants') }}
),

-- Use macro for transaction analytics
transaction_analytics as (
    select
        t.transaction_id,
        t.account_id,
        t.merchant_id,
        t.amount_usd,
        t.transaction_date,
        -- Use rolling window macro for customer-level patterns
        {{ rolling_window('t.amount_usd', 'a.customer_id', 't.transaction_date', 7) }} as rolling_7day_avg,
        {{ rolling_window('t.amount_usd', 'a.customer_id', 't.transaction_date', 30) }} as rolling_30day_avg,
        -- Use macro for percentiles
        {{ percentile('t.amount_usd', 0.95) }} over () as transaction_95th_percentile,
        {{ percentile('t.amount_usd', 0.99) }} over () as transaction_99th_percentile,
        -- Calculate z-score for anomaly detection
        (t.amount_usd - avg(t.amount_usd) over (partition by a.customer_id)) / 
        nullif(stddev(t.amount_usd) over (partition by a.customer_id), 0) as transaction_z_score
    from transactions t
    left join accounts a on t.account_id = a.account_id
)

select
    {{ generate_surrogate_key(['t.transaction_id', 'a.customer_id']) }} as transaction_sk,
    t.transaction_id,
    t.account_id,
    a.customer_id,
    a.account_type,
    a.account_balance as pre_transaction_balance,
    a.account_balance - t.amount_usd as post_transaction_balance,
    t.merchant_id,
    m.merchant_name,
    m.merchant_city,
    c.first_name || ' ' || c.last_name as customer_name,
    c.credit_score,
    c.credit_rating,
    c.customer_tier,
    t.amount_usd,
    t.transaction_date,
    t.transaction_year,
    t.transaction_month,
    t.transaction_quarter,
    t.transaction_dayofweek,
    t.transaction_size,
    t.time_of_day,
    t.day_type,
    t.is_holiday,
    -- Rolling averages from macro
    ta.rolling_7day_avg,
    ta.rolling_30day_avg,
    -- Percentiles from macro
    ta.transaction_95th_percentile,
    ta.transaction_99th_percentile,
    -- Anomaly detection
    ta.transaction_z_score,
    case 
        when abs(ta.transaction_z_score) > 3 then 'Anomaly'
        when abs(ta.transaction_z_score) > 2 then 'Suspicious'
        else 'Normal'
    end as transaction_risk_flag,
    -- Cumulative spend using macro logic
    sum(t.amount_usd) over (
        partition by a.customer_id 
        order by t.transaction_date 
        rows unbounded preceding
    ) as cumulative_spend,
    -- Transaction frequency (hours since last transaction)
    datediff(
        'hour',
        lag(t.transaction_date) over (
            partition by a.customer_id 
            order by t.transaction_date
        ),
        t.transaction_date
    ) as hours_since_last_transaction,
    -- Flag for high-value transaction (using macro with percentile)
    case 
        when t.amount_usd > ta.transaction_95th_percentile then 'High Value'
        when t.amount_usd > ta.transaction_75th_percentile then 'Above Average'
        else 'Normal'
    end as value_category
from transactions t
left join accounts a on t.account_id = a.account_id
left join customers c on a.customer_id = c.customer_id
left join merchants m on t.merchant_id = m.merchant_id
left join transaction_analytics ta on t.transaction_id = ta.transaction_id