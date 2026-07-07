{{
    config(
        materialized='incremental',
        schema='marts',
        unique_key='transaction_sk',
        incremental_strategy='merge',
        partition_by=['transaction_year', 'transaction_month'],
        cluster_by=['customer_id', 'transaction_date'],
        tags=['marts', 'fact', 'transactions'],
        grants={
            'select': ['analytics_reader', 'reporting_user', 'fraud_detection']
        }
    )
}}

with enriched_transactions as (
    select * from {{ ref('int_transaction_enriched') }}
    {% if is_incremental() %}
        where transaction_date > (select max(transaction_date) from {{ this }})
    {% endif %}
),

-- Use macro for transaction aggregates
transaction_aggregates as (
    select
        customer_id,
        count(transaction_id) as total_transactions,
        sum(amount_usd) as total_spend,
        avg(amount_usd) as avg_spend,
        {{ percentile('amount_usd', 0.5) }} as median_transaction_amount,
        {{ percentile('amount_usd', 0.75) }} as p75_transaction_amount,
        {{ percentile('amount_usd', 0.9) }} as p90_transaction_amount,
        count(case when amount_usd > 10000 then 1 end) as high_value_transactions
    from enriched_transactions
    group by 1
)

select
    et.transaction_sk,
    et.transaction_id,
    et.account_id,
    et.customer_id,
    et.customer_name,
    et.credit_score,
    et.credit_rating,
    et.customer_tier,
    et.account_type,
    et.pre_transaction_balance,
    et.post_transaction_balance,
    et.merchant_id,
    et.merchant_name,
    et.merchant_city,
    et.amount_usd,
    et.transaction_date,
    et.transaction_year,
    et.transaction_month,
    et.transaction_quarter,
    et.transaction_dayofweek,
    et.transaction_size,
    et.time_of_day,
    et.day_type,
    et.is_holiday,
    -- Rolling metrics from macro
    et.rolling_7day_avg,
    et.rolling_30day_avg,
    -- Percentiles from macro
    et.transaction_95th_percentile,
    et.transaction_99th_percentile,
    -- Risk metrics
    et.transaction_z_score,
    et.transaction_risk_flag,
    et.value_category,
    -- Customer-level aggregates using macro
    ta.total_transactions,
    ta.total_spend,
    ta.avg_spend,
    ta.median_transaction_amount,
    ta.p75_transaction_amount,
    ta.p90_transaction_amount,
    ta.high_value_transactions,
    -- Transaction velocity (using macro)
    round(
        ta.total_transactions / nullif(
            {{ date_diff('min(transaction_date)', 'max(transaction_date)', 'month') }},
            0
        ),
        2
    ) as transactions_per_month,
    -- Use macro for cumulative metrics
    sum(et.amount_usd) over (
        partition by et.customer_id 
        order by et.transaction_date 
        rows unbounded preceding
    ) as cumulative_customer_spend,
    -- Use macro for business date key
    {{ business_key(['et.transaction_year', 'et.transaction_month', 'et.customer_id']) }} as period_customer_key,
    -- Hash for deduplication
    {{ hash_column('et.transaction_id || et.amount_usd::text || et.transaction_date::text') }} as transaction_hash,
    -- Metadata
    current_timestamp() as dbt_updated_at,
    '{{ invocation_id }}' as dbt_invocation_id
from enriched_transactions et
left join transaction_aggregates ta on et.customer_id = ta.customer_id