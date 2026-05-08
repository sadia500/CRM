# 🗄️ CRM — Database Management System

> A full-stack Customer Relationship Management system built with **Python Flask** + **MySQL** — featuring a modern dark-themed web dashboard, stored procedures, triggers, audit logging, and complete CRUD operations.

---

## 🚀 Live Preview

> Run locally → `http://127.0.0.1:5000`

---

## 📸 Features

| Module | Description |
|---|---|
| 📊 **Dashboard** | KPI cards, revenue chart, pipeline breakdown, top reps |
| 🏢 **Customers** | Full CRUD, 360° view, status management |
| ⚡ **Leads** | Lead tracking, source filtering, one-click conversion to deal |
| 💰 **Deals** | Stage management, pipeline value, deal history |
| ✅ **Tasks** | Priority management, overdue detection, team assignment |
| 👥 **Team** | Employee directory with performance metrics |
| 📈 **Reports** | Monthly revenue, rep performance, churn risk, product analytics |
| 🔒 **Audit Log** | Auto-recorded by MySQL triggers — every INSERT/UPDATE/DELETE |

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Python 3.8+, Flask 3.1 |
| **Database** | MySQL 8.0 |
| **Frontend** | HTML5, CSS3, Vanilla JS |
| **Fonts** | Outfit, JetBrains Mono (Google Fonts) |
| **DB Connector** | mysql-connector-python |
| **Environment** | python-dotenv |

---

## 🗃️ Database Architecture
10 normalized tables (3NF)
├── employees          — Staff & manager hierarchy (self-referencing FK)
├── customers          — Company accounts
├── contacts           — Individual contacts per company
├── products           — Product catalog
├── leads              — Sales opportunities
├── deals              — Closed/active deals
├── deal_products      — Many-to-many: deals ↔ products
├── interactions       — Call/email/meeting logs
├── tasks              — Team task management
└── audit_log          — Auto-populated by triggers

### Stored Procedures
| Procedure | Purpose |
|---|---|
| `sp_convert_lead_to_deal` | Atomic lead conversion with transaction rollback |
| `sp_sales_pipeline_report` | Per-rep performance metrics |
| `sp_customer_360` | Full customer snapshot |
| `sp_auto_followup_tasks` | Auto-create tasks for idle leads |
| `sp_monthly_revenue` | Monthly revenue by year |

### Triggers
| Trigger | Action |
|---|---|
| `trg_customers_audit_update` | Logs every customer update |
| `trg_deals_audit_insert` | Logs new deals |
| `trg_deals_audit_update` | Logs deal changes |
| `trg_deal_activate_customer` | Auto-activates customer on won deal |
| `trg_prevent_emp_delete_with_deals` | Blocks unsafe employee deletion |
| `trg_leads_audit_update` | Logs lead status changes |

### Views
| View | Purpose |
|---|---|
| `vw_sales_performance` | Sales rep performance summary |
| `vw_active_customers` | Active customers with revenue totals |

---

## ⚙️ Setup & Installation

### Prerequisites
- Python 3.8+
- MySQL 8.0
- pip

### Step 1 — Clone the repo
```bash
git clone https://github.com/YOUR_USERNAME/crm-dbms.git
cd crm-dbms
```

### Step 2 — Install dependencies
```bash
pip install -r requirements.txt
```

### Step 3 — Import the database
```bash
mysql -u root -p < crm_db.sql
```
Or use MySQL Workbench → Server → Data Import → select `crm_db.sql`

### Step 4 — Configure environment variables
Create a `.env` file in the project root:
DB_HOST=localhost
DB_PORT=3306
DB_NAME=crm_db
DB_USER=root
DB_PASSWORD=your_mysql_password_here
SECRET_KEY=your_secret_key_here
FLASK_DEBUG=False

### Step 5 — Run
```bash
python app.py
```

Open your browser → `http://127.0.0.1:5000`

### Step 6 — Login credentials (sample data)

| Employee | ID | Password | Role |
|---|---|---|---|
| Kamran Sheikh | 1 | admin123 | Admin |
| Sana Rizvi | 2 | manager123 | Manager |
| Bilal Mahmood | 3 | bilal123 | Sales Rep |
| Ayesha Farooq | 4 | ayesha123 | Sales Rep |
| Usman Qureshi | 5 | usman123 | Sales Rep |
| Fatima Butt | 6 | fatima123 | Support |
| Omer Naeem | 7 | omer123 | Manager |

---

## 📁 Project Structure
crm-dbms/
├── app.py                   # Flask application & all routes
├── crm_db.sql               # Complete MySQL schema + sample data
├── requirements.txt         # Python dependencies
├── .env                     # Your local credentials (never committed)
├── .env.example             # Template — safe to commit
├── .gitignore               # Git ignore rules
├── templates/
│   ├── base.html            # Shared layout, sidebar, styles
│   ├── index.html           # Dashboard
│   ├── customers.html       # Customer management
│   ├── customer_detail.html # Customer 360° view
│   ├── leads.html           # Lead management
│   ├── deals.html           # Deal management
│   ├── tasks.html           # Task management
│   ├── employees.html       # Team directory
│   ├── reports.html         # Analytics & reports
│   └── audit.html           # Audit log
└── README.md

---

## 📊 Sample Data Included

- 7 Employees (with manager hierarchy across 4 roles)
- 10 Customers (across 6 industries — real Pakistani companies)
- 10 Contacts
- 10 Products
- 10 Leads
- 8 Deals
- 12 Interactions
- 10 Tasks
- Auto-generated Audit Log entries via triggers

---

## 🔐 Security Notes

- All credentials stored in `.env` — never hardcoded
- `.env` is listed in `.gitignore` and never committed to GitHub
- Role-based access control — only Admin/Manager can delete records
- Session-based authentication on all routes
- Input validation on all API endpoints

---

## 🎓 Academic Context

**University:** Bahria University, Karachi Campus
**Department:** Computer Science
**Course:** Database Management Systems
**Semester:** 4th

---

## 📄 License

MIT License — free to use and modify.

---

> Built with ❤️ using Python, Flask & MySQL