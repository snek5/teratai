{{
    config(
        materialized='view',
        tags=['intermediate', 'customer_360']
    )
}}

with customers as (
    select 
        customer_id,
        first_name,
        last_name,
        email,
        {{ mask_pii('email') }} as email_masked,
        city as customer_city,
        credit_score,
        credit_rating,
        customer_tier,
        created_at,
        {{ age_years('created_at') }} as customer_age_years
    from {{ ref('stg_customers') }}
),

accounts as (
    select 
        customer_id,
        count(account_id) as total_accounts,
        sum(balance_usd) as total_balance_usd,
        avg(balance_usd) as avg_account_balance,
        max(balance_usd) as max_account_balance,
        min(balance_usd) as min_account_balance,
        collect_list(account_type) as account_types,
        -- Customer lifetime value calculation using macro
        {{ calculate_clv('customer_id') }}
    from {{ ref('stg_accounts') }}
    group by 1
),

loans as (
    select 
        customer_id,
        count(loan_id) as total_loans,
        sum(loan_amount) as total_loan_amount,
        avg(interest_rate) as avg_interest_rate,
        max(loan_amount) as max_loan_amount,
        sum({{ safe_decimal('loan_amount', 15, 2) }}) as total_loan_balance
    from {{ ref('stg_loans') }}
    where loan_status != 'Completed'
    group by 1
),

cards as (
    select 
        customer_id,
        count(card_id) as total_cards,
        count(case when card_type = 'Credit' then 1 end) as credit_cards,
        count(case when card_type = 'Debit' then 1 end) as debit_cards,
        count(case when is_expired = true then 1 end) as expired_cards,
        count(case when months_until_expiry <= 3 and is_expired = false then 1 end) as cards_expiring_soon
    from {{ ref('int_customer_card_info') }}
    where card_id is not null
    group by 1
),

-- Calculate customer scoring using macros
customer_scoring as (
    select
        customer_id,
        -- Credit score percentile using macro
        {{ percentile('credit_score', 0.9) }} over () as credit_score_90th_percentile,
        -- Rank customers by balance
        rank() over (order by total_balance_usd desc) as balance_rank,
        -- NTILE for customer segmentation
        ntile(5) over (order by total_balance_usd desc) as wealth_quintile
    from accounts
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email_masked,
    c.customer_city,
    c.credit_score,
    c.credit_rating,
    c.customer_tier,
    c.customer_age_years,
    c.created_at,
    -- Account metrics
    coalesce(a.total_accounts, 0) as total_accounts,
    coalesce(a.total_balance_usd, 0) as total_balance_usd,
    coalesce(a.avg_account_balance, 0) as avg_account_balance,
    a.account_types,
    -- Loan metrics
    coalesce(l.total_loans, 0) as total_loans,
    coalesce(l.total_loan_amount, 0) as total_loan_amount,
    coalesce(l.avg_interest_rate, 0) as avg_interest_rate,
    -- Card metrics
    coalesce(crd.total_cards, 0) as total_cards,
    coalesce(crd.credit_cards, 0) as credit_cards,
    coalesce(crd.debit_cards, 0) as debit_cards,
    coalesce(crd.expired_cards, 0) as expired_cards,
    coalesce(crd.cards_expiring_soon, 0) as cards_expiring_soon,
    -- Derived metrics
    coalesce(a.total_balance_usd, 0) - coalesce(l.total_loan_amount, 0) as net_worth,
    -- Use macro for net worth ratio
    round(
        coalesce(a.total_balance_usd, 0) / nullif(coalesce(l.total_loan_amount, 0), 0),
        2
    ) as debt_to_asset_ratio,
    -- Scoring metrics
    cs.credit_score_90th_percentile,
    cs.balance_rank,
    cs.wealth_quintile,
    -- Generate surrogate key using macro
    {{ generate_surrogate_key(['c.customer_id', 'c.created_at']) }} as customer_sk,
    -- Business key using macro
    {{ business_key(['c.first_name', 'c.last_name', 'c.email']) }} as customer_business_key,
    -- Financial health status using macro logic
    case 
        when coalesce(a.total_balance_usd, 0) > coalesce(l.total_loan_amount, 0) * 1.5 then 'Excellent'
        when coalesce(a.total_balance_usd, 0) > coalesce(l.total_loan_amount, 0) then 'Good'
        when coalesce(a.total_balance_usd, 0) > coalesce(l.total_loan_amount, 0) * 0.5 then 'Fair'
        else 'Needs Attention'
    end as financial_health_status
from customers c
left join accounts a on c.customer_id = a.customer_id
left join loans l on c.customer_id = l.customer_id
left join cards crd on c.customer_id = crd.customer_id
left join customer_scoring cs on c.customer_id = cs.customer_id