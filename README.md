# 🛒 E-Commerce Sales, Customer Retention & Delivery Performance Analytics
> **Production-Grade Relational SQL Analytics Pipeline & Business Intelligence**

---

## 📌 Executive Project Overview
This project analyzes **99k+ orders** from the Olist Brazilian E-Commerce dataset using **MySQL Workbench**. The primary objective is to transition raw, multi-table e-commerce data into actionable business intelligence by evaluating operational performance across three core business domains:
1. **Sales & Revenue Performance:** Tracking monthly GMV growth trajectories, product category concentration, and customer spending power.
2. **Customer Retention & RFM Segmentation:** Analyzing repeat purchasing habits, lifetime value (LTV) multipliers, and customer recency tiers.
3. **Delivery Logistics & SLA Performance:** Mapping regional fulfillment speed, late delivery bottlenecks, and customer review score correlation.

---

## 🏗️ Database Architecture & Engineering

### Two-Tier Staging Architecture
To adhere to enterprise data engineering standards, a **two-tier database architecture** was implemented:
- **Raw Layer (`olist_raw`):** Direct CSV imports acting as an untouched, immutable historical backup to ensure complete data provenance.
- **Staging Layer (`olist_analytics`):** Sanitized, strongly-typed schema enforcing strict analytical requirements:
  - **Timestamp Parsing:** Converted raw text dates to strict native MySQL `DATETIME` types via `STR_TO_DATE()` for accurate time-series arithmetic (`DATEDIFF`).
  - **Financial Precision:** Cast raw price and freight figures to `DECIMAL(10, 2)` to eliminate floating-point rounding errors native to `DOUBLE` or `FLOAT` data types.
  - **Postal Code Preservation:** Maintained Brazilian zip codes (`customer_zip_code_prefix`) as `VARCHAR` to prevent MySQL from stripping leading zeros.
  - **Null Safety:** Handled empty strings (`''`) during ingestion using `NULLIF()` to enforce proper SQL missing data handling.

```
                         +-----------------------------+
                         |      olist_raw (CSVs)       |
                         +-----------------------------+
                                        |
                          (Ingestion & Type Sanitization)
                                        |
                                        v
                         +-----------------------------+
                         |  olist_analytics (Staging)  |
                         +-----------------------------+
                                        |
         +------------------+-----------+-----------+------------------+
         |                  |                       |                  |
   +-----+-----+      +-----+-----+           +-----+-----+      +-----+-----+
   |  orders   |      | customers |           | order_items|     | payments  |
   +-----+-----+      +-----+-----+           +-----+-----+      +-----+-----+
         |                  |                       |                  |
         +------------------+-----------+-----------+------------------+
                                        |
                           (Production SQL Analytical Views)
                                        |
    +-------------------+-------------------+-------------------+-------------------+
    |                   |                   |                   |                   |
    v                   v                   v                   v                   v
vw_executive_kpi    vw_customer_rfm     vw_seller_scorecard   vw_logistics_health
```

---

## 📊 Analytical Pillars & Key Business Findings

### 📈 Pillar 1: Sales & Revenue Performance
- **Macro GMV Trajectory:** Monthly GMV expanded nearly **10x** from **$127.5K** (Jan 2017) to a peak of **$1.15M+** in November 2017 driven by Black Friday holiday shopping. GMV stabilized at **~$1.0M–$1.13M per month** through mid-2018.
- **Product Category Pareto Distribution:** Revenue is heavily concentrated in high-ticket categories including *bed_bath_table*, *health_beauty*, *sports_leisure*, and *computers_accessories*.
- **Regional Revenue Leadership:** São Paulo (SP) dominates platform volume, generating **40,501 orders** and **$5.77M GMV**, followed by Rio de Janeiro (RJ) and Minas Gerais (MG).

### 👥 Pillar 2: Customer Retention & Behavior
- **One-Time Buyer Dependency:** Over **96.4%** of Olist's customer base (90,556 out of 94,367 unique buyers) placed only a single order, highlighting a reliance on single-transaction acquisition rather than organic repeat retention.
- **LTV Spend Multiplier:** Repeat customer segments (**Champions**, **Loyal**, **At-Risk**) exhibit an average spend of **$300–$322**, double the average spend of single-order buyers (**$158–$164**). Securing a second purchase doubles customer lifetime value.
- **Win-Back Opportunity:** Identified **1,564 high-value repeat buyers** ($467.6K cumulative GMV) currently classified as **'At-Risk'** (>180 days dormant), presenting an immediate opportunity for targeted win-back campaigns.

### 💳 Pillar 3: Financial Performance & Payment Installments
- **Credit Card Dominance:** Credit cards account for **~75%** of all transactions, followed by Boleto Bancário (**~19%**).
- **Installment Liquidity Impact:** High-value purchases rely heavily on credit card installments. Orders paid in 10+ installments average **$410+ in AOV**, compared to **~$110** for single-installment orders.
- **Voucher Subsidies:** Mixed multi-payment transactions leverage promotional vouchers to cover an average of **57.15%** of the total transaction value.

### 🚚 Pillar 4: Delivery Logistics & SLA Performance
- **Infrastructure Efficiency Gap:** São Paulo (SP) benefits from centralized fulfillment, averaging **8.7 days delivery time**, a low **5.89% late rate**, and the lowest shipping cost (**$15.27/item**).
- **Rio de Janeiro Bottleneck:** Despite geographic proximity to SP, Rio de Janeiro (RJ) experiences severe last-mile friction, suffering a **13.47% late delivery rate** (1,664 delayed orders) and an average delivery timeline of **15.2 days**.
- **Remote Northeast Disparity:** Customers in northern/northeast states (e.g., Alagoas, Maranhão, Ceará) face late delivery rates between **15.3% and 23.9%**, delivery transit times exceeding **21–24 days**, and freight costs over **$36–$38 per item**.

---

## 🛠️ Production SQL Views (`vw_*`)

The analytical pipeline culminates in 4 production-ready, business-aligned SQL views:

1. **`vw_executive_kpi_summary`:** Consolidates monthly GMV, order count, active customer count, average review ratings, fulfillment duration, and late delivery percentages.
2. **`vw_customer_rfm_segments`:** Calculates Recency, Frequency, and Monetary metrics for every customer to categorize them into 5 strategic segments (*Champions, Loyal, At-Risk, Recent One-Time, Lost/Churned*).
3. **`vw_seller_performance_scorecard`:** Ranks sellers into operational tiers based on GMV, item volume, SLA compliance, and customer satisfaction ratings (identifying that top 1.58% of sellers generate 31.58% of platform GMV).
4. **`vw_logistics_fulfillment_health`:** Aggregates regional logistics health metrics, delivery transit times, freight costs, and delay severities across all 27 Brazilian states using optimized CTE pre-aggregation.

---

## 🛠️ Tech Stack & SQL Mastery
- **Database Engine:** MySQL Workbench 8.0
- **SQL Engineering Techniques:** Multi-table `INNER`/`LEFT JOIN`s, `GROUP BY`, `HAVING`, `CASE` conditional logic, Common Table Expressions (CTEs), Subqueries, Date Arithmetic (`DATEDIFF`, `STR_TO_DATE`), Aggregations (`SUM`, `AVG`, `COUNT DISTINCT`), Window Functions (`RANK()`, `LAG()`), View Creation (`CREATE OR REPLACE VIEW`).
- **Data Architecture:** Schema design, type safety, monetary decimal precision, staged data ingestion validation.
- **Reporting & Business Intelligence:** Power BI & Excel *(Next Phase)*.

---

## 🖼️ Dashboard Preview

### 1. Executive Summary
Overview of total revenue (GMV), total orders, average order value (AOV), monthly revenue trends, and customer satisfaction scores.
![Executive Summary](screenshots/01_executive_summary.png)

### 2. Customer Analysis (RFM Segmentation)
Deep-dive into customer distribution by RFM segments (Champions, Loyal, At-Risk, Recent One-Time, Lost/Churned), monetary value distribution, and average recency.
![Customer Analysis](screenshots/02_customer_analysis.png)

### 3. Seller Performance
Categorization of sellers into performance tiers, total GMV contributions by tier, seller counts, and late delivery rate impacts by seller tier.
![Seller Performance](screenshots/03_seller_performance.png)

### 4. Logistics & Fulfillment
Regional analysis of shipping delays, freight cost per item across states, and overall late delivery percentage.
![Logistics & Fulfillment](screenshots/04_logistics_fulfillment.png)

---

## 💡 Key Business Insights

* **Customer Retention:** High-value repeat customers ("Champions" and "Loyal") represent a small fraction of total user volume, highlighting an opportunity for targeted re-engagement campaigns for "Recent One-Time" buyers.
* **Seller Contribution:** A small percentage of top-tier sellers generate the vast majority of Gross Merchandise Value (GMV).
* **Fulfillment Bottlenecks:** Certain regional states exhibit significantly higher average delay days when late, signaling regional logistics bottlenecks.

---

## 📁 Repository Structure

```text
├── Dashboard screenshots/        # Power BI dashboard page previews
│   ├── 01_executive_summary.png
│   ├── 02_customer_analysis.png
│   ├── 03_seller_performance.png
│   └── 04_logistics_fulfillment.png
├── SQL scripts/                  # SQL schema setup and analytical view scripts
├── SQL scripts results/          # CSV exports of query results from the 27 analytical questions
├── Executive Business Report.docx  # Project Business Report
├── Ecommerce_Executive_Dashboard.pbix  # Power BI source file
└── README.md                     # Project documentation