# Instacart Sales Data Warehouse 🛒📊

![Data Engineering](https://img.shields.io/badge/Data%20Engineering-Project-blue)
![Airflow](https://img.shields.io/badge/Airflow-2.x-green)
![dbt](https://img.shields.io/badge/dbt-1.x-orange)
![ClickHouse](https://img.shields.io/badge/ClickHouse-24.3-yellow)
![Superset](https://img.shields.io/badge/Superset-4.0-cyan)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)

This is a Data Engineering project that builds a complete Data Warehouse system to analyze Instacart sales data. The system utilizes the Medallion Architecture (Bronze - Silver - Gold) to process data from raw format to business reporting.

<!-- Add your architectural diagram or intro image here -->
![Data Architecture Placeholder]()

## 🚀 Tech Stack

- **Orchestration**: Apache Airflow
- **Data Transformation**: dbt (Data Build Tool)
- **Data Warehouse**: ClickHouse (Powerful for OLAP)
- **Database Backend & Source**: PostgreSQL (Simulating E-commerce & CRM source data)
- **Data Visualization**: Apache Superset
- **Infrastructure**: Docker & Docker Compose

## 🏗 Data Architecture (Medallion)

<!-- Add your Medallion Architecture diagram here -->
![Medallion Architecture Placeholder]()

1. **Bronze Layer (Raw Data)** 🥉
   - Stores raw data ingested from CSV (Instacart data) and PostgreSQL (E-commerce/CRM data).
   - ClickHouse tables use `MergeTree` with append-only data to retain history.
2. **Silver Layer (Conformed & Cleansed Data)** 🥈
   - Data is cleansed, data types are standardized, and null values are handled.
   - Tables are joined together to form preliminary dimension/fact tables.
3. **Gold Layer (Reporting / Aggregated Data)** 🥇
   - Data is aggregated according to specific business logic for dashboards on Superset.
   - Focuses on read query optimization (Read-heavy).

## 📂 Directory Structure

```text
Instacart_Sales_Data_Warehouse/
├── airflow/                    # Contains source code for Airflow (DAGs, plugins, logs)
│   └── dags/                   # Contains ETL/ELT pipelines (e.g., elt_pipeline.py)
├── dbt_instacart/              # dbt project (models for Bronze, Silver, Gold layers)
├── ingestion/                  # Python scripts handling data ingestion from source to Data Warehouse
├── postgres_init/              # PostgreSQL database initialization scripts
├── raw_data/                   # Contains original raw data (CSV files)
├── docker-compose.yaml         # Container configuration for Postgres, ClickHouse, Superset
├── docker-compose.airflow.yaml # Separate container configuration for Airflow
└── README.md                   # Project documentation
```

## 🛠 Installation & Setup Guide

### System Requirements:
- [Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/install/)
- Available ports: 5432, 5433 (Postgres), 8123, 9000 (ClickHouse), 8088 (Superset), 8080 (Airflow).

### Setup Steps:

1. **Clone repository:**
   ```bash
   git clone <your-repo-url>
   cd Instacart_Sales_Data_Warehouse
   ```

2. **Start Data Warehouse & BI (ClickHouse, Postgres, Superset):**
   ```bash
   docker-compose up -d
   ```

3. **Start Airflow:**
   *(Airflow is run on a separate compose file with Postgres 13)*
   ```bash
   docker-compose -f docker-compose.airflow.yaml up -d
   ```

4. **Access the services:**
   - **Airflow Web UI**: `http://localhost:8080` (Default User/Pass configured in .env or compose file)
   - **Superset**: `http://localhost:8088` (User: admin / Pass: admin)
   - **ClickHouse HTTP**: `http://localhost:8123`

<!-- Add your Superset dashboards screenshots here -->
![Superset Dashboards Placeholder]()

## 📊 Roadmap / Future Work

- [ ] Complete automated Ingestion scripts to move data into ClickHouse.
- [ ] Run historical data backfill for all years.
- [ ] Build 3 main Dashboards on Superset (Sales Overview, Customer Segmentation, Product Performance).
- [ ] Integrate CI/CD (GitHub Actions) to automatically test dbt models.

---
*Developed by [Your Name] - Data Engineer*
