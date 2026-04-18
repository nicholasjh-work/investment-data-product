<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/nh-logo-dark.svg" width="80">
  <source media="(prefers-color-scheme: light)" srcset="assets/nh-logo-light.svg" width="80">
  <img alt="NH" src="assets/nh-logo-light.svg" width="80">
</picture>

# Investment Data Product

**[placeholder tagline]**

[![Data Contract](https://img.shields.io/badge/Data_Contract-Published-16a34a?style=for-the-badge)](DATA_CONTRACT.md)
[![Architecture](https://img.shields.io/badge/Architecture-View-1e40af?style=for-the-badge)](#architecture)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

![Azure SQL](https://img.shields.io/badge/Azure_SQL-0078D4?style=flat&logo=microsoftsqlserver&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)
![Databricks](https://img.shields.io/badge/Databricks-FF3621?style=flat&logo=databricks&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-FF694A?style=flat&logo=dbt&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Delta Lake](https://img.shields.io/badge/Delta_Lake-00ADD4?style=flat)
![Unity Catalog](https://img.shields.io/badge/Unity_Catalog-FF3621?style=flat)

</div>

---

### What This Does

[placeholder]

---

### Architecture

[placeholder]

---

### Design Principles

[placeholder]

---

### Operational Visibility

[placeholder]

---

### Blocking DQ Gates

[placeholder]

---

### SLA Status Logic

[placeholder]

---

### Repo Layout

```
.
├── sources/
│   ├── azure_sql/ddl/
│   └── postgresql/ddl/
├── ingestion/
├── dbt/
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   ├── tests/
│   ├── macros/
│   └── dbt_project.yml
├── contracts/
├── consumer/
│   └── powerbi/
├── docs/
├── assets/
├── DATA_CONTRACT.md
├── CHANGELOG.md
├── LICENSE
└── README.md
```

---

### Running

[placeholder]

---

### Tech Stack

| Component | Technology |
|---|---|
| ![Source](https://img.shields.io/badge/Source-0078D4?style=flat-square) | [placeholder] |
| ![Transform](https://img.shields.io/badge/Transform-FF694A?style=flat-square) | [placeholder] |
| ![Orchestration](https://img.shields.io/badge/Orchestration-FF3621?style=flat-square) | [placeholder] |
| ![Quality](https://img.shields.io/badge/Quality-dc2626?style=flat-square) | [placeholder] |
| ![Monitoring](https://img.shields.io/badge/Monitoring-00ADD4?style=flat-square) | [placeholder] |
| ![Consumer](https://img.shields.io/badge/Consumer-F2C811?style=flat-square) | [placeholder] |
| ![Governance](https://img.shields.io/badge/Governance-7c3aed?style=flat-square) | [placeholder] |

---

### Ownership

Data Product Owner: Nicholas Hidalgo. See [`DATA_CONTRACT.md`](DATA_CONTRACT.md) for SLA, schema, semantics, and exclusion policy. See [`CHANGELOG.md`](CHANGELOG.md) for versioned changes.

---

<div align="center">

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Nicholas_Hidalgo-0A66C2?style=for-the-badge&logo=linkedin)](https://linkedin.com/in/nicholashidalgo)&nbsp;
[![Website](https://img.shields.io/badge/Website-nicholashidalgo.com-000000?style=for-the-badge)](https://nicholashidalgo.com)&nbsp;
[![Email](https://img.shields.io/badge/Email-analytics@nicholashidalgo.com-EA4335?style=for-the-badge&logo=gmail)](mailto:analytics@nicholashidalgo.com)

</div>
