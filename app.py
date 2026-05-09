from flask import Flask, render_template, request, jsonify, redirect, url_for, session
import mysql.connector
from mysql.connector import Error
from decimal import Decimal
from datetime import date, datetime
import json
import logging
import os
from dotenv import load_dotenv

logging.basicConfig(level=logging.ERROR)
load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "fallback_change_me")

app.jinja_env.globals['enumerate'] = enumerate

COMPANY_COLORS = ['#0052cc','#006644','#ff8b00','#5243aa','#00a3bf','#de350b','#0065ff','#36b37e']
def co_color(cid):
    return COMPANY_COLORS[(cid-1) % len(COMPANY_COLORS)]
app.jinja_env.globals['co_color'] = co_color

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 3306)),
    "database": os.getenv("DB_NAME", "crm_db"),
    "user":     os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
}

def get_db():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("SET SESSION sql_mode = ''")
        cur.close()
        return conn
    except Error as e:
        logging.exception("DB connection failed")
        return None

def serial(obj):
    if isinstance(obj, Decimal): return float(obj)
    if isinstance(obj, (date, datetime)): return obj.strftime("%Y-%m-%d")
    return str(obj)

def jrows(rows):
    return json.loads(json.dumps(rows, default=serial))

def query(sql, params=None):
    conn = get_db()
    if not conn: return []
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params or ())
        rows = cur.fetchall()
        cur.close(); conn.close()
        return rows
    except Exception as e:
        logging.exception("Query failed")
        return []

def execute(sql, params=None):
    conn = get_db()
    if not conn: return 0, None
    try:
        cur = conn.cursor()
        cur.execute(sql, params or ())
        conn.commit()
        lid, rc = cur.lastrowid, cur.rowcount
        cur.close(); conn.close()
        return rc, lid
    except Exception as e:
        logging.exception("Execute failed")
        return 0, None

def safe_val(sql, default=0):
    try:
        rows = query(sql)
        if rows:
            v = list(rows[0].values())[0]
            return v if v is not None else default
        return default
    except Exception as e:
        logging.exception("safe_val failed")
        return default

def call_proc(name, args=None):
    conn = get_db()
    if not conn: return []
    try:
        cur = conn.cursor(dictionary=True)
        cur.callproc(name, args or [])
        results = [r.fetchall() for r in cur.stored_results()]
        conn.commit(); cur.close(); conn.close()
        return results
    except Exception as e:
        logging.exception("call_proc failed")
        return []

@app.before_request
def require_login():
    allowed = ['login', 'logout', 'static']
    if request.endpoint not in allowed and 'user_id' not in session:
        return redirect(url_for('login'))

@app.route("/login", methods=["GET","POST"])
def login():
    error = None
    if request.method == "POST":
        emp_id = request.form.get("emp_id")
        password = request.form.get("password")
        emp = query("SELECT * FROM employees WHERE employee_id=%s AND is_active=1", (emp_id,))
        if emp and password == emp[0]['password_hash']:
            session['user_id'] = emp[0]['employee_id']
            session['user_name'] = f"{emp[0]['first_name']} {emp[0]['last_name']}"
            session['user_role'] = emp[0]['role']
            session['user_initials'] = f"{emp[0]['first_name'][0]}{emp[0]['last_name'][0]}"
            return redirect(url_for('index'))
        else:
            error = "Invalid credentials. Please try again."
    employees = query("SELECT employee_id, first_name, last_name, role FROM employees WHERE is_active=1 ORDER BY first_name")
    return render_template("login.html", employees=employees, error=error)

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route("/")
def index():
    stats = {
        "customers": int(safe_val("SELECT COUNT(*) FROM customers WHERE status='active'")),
        "leads":     int(safe_val("SELECT COUNT(*) FROM leads WHERE status IN ('new','contacted','qualified')")),
        "deals":     int(safe_val("SELECT COUNT(*) FROM deals WHERE stage='closed_won'")),
        "revenue":   float(safe_val("SELECT COALESCE(SUM(amount),0) FROM deals WHERE stage='closed_won'")),
        "tasks":     int(safe_val("SELECT COUNT(*) FROM tasks WHERE status IN ('pending','in_progress') AND due_date < CURDATE()")),
        "products":  int(safe_val("SELECT COUNT(*) FROM products WHERE is_active=1")),
    }
    recent_deals = jrows(query("""
        SELECT d.deal_id, c.company_name, d.amount, d.stage, d.closed_date,
               CONCAT(e.first_name,' ',e.last_name) AS rep
        FROM deals d JOIN customers c ON c.customer_id=d.customer_id
        LEFT JOIN employees e ON e.employee_id=d.closed_by
        ORDER BY d.created_at DESC LIMIT 6
    """))
    top_reps = jrows(query("""
        SELECT CONCAT(e.first_name,' ',e.last_name) AS name,
               COUNT(d.deal_id) AS deals,
               COALESCE(SUM(d.amount),0) AS revenue
        FROM employees e
        LEFT JOIN deals d ON d.closed_by=e.employee_id AND d.stage='closed_won'
        WHERE e.role IN ('sales_rep','manager') AND e.is_active=1
        GROUP BY e.employee_id ORDER BY revenue DESC LIMIT 5
    """))
    pipeline = jrows(query("""
        SELECT stage, COUNT(*) AS cnt, COALESCE(SUM(amount),0) AS val
        FROM deals GROUP BY stage
        ORDER BY FIELD(stage,'proposal','negotiation','closed_won','closed_lost')
    """))
    monthly = jrows(query("""
    SELECT MONTH(closed_date) AS m,
           CONCAT(LEFT(MONTHNAME(closed_date),3),' ',YEAR(closed_date)) AS mn,
           COALESCE(SUM(amount),0) AS revenue,
           COUNT(*) AS deals
    FROM deals
    WHERE stage='closed_won' AND closed_date IS NOT NULL
    GROUP BY YEAR(closed_date), MONTH(closed_date)
    ORDER BY YEAR(closed_date), MONTH(closed_date)
"""))
    return render_template("index.html", stats=stats, recent_deals=recent_deals,
                           top_reps=top_reps, pipeline=pipeline, monthly=monthly)

@app.route("/customers")
def customers():
    search = request.args.get("q","")
    status = request.args.get("status","")
    sql = """SELECT c.customer_id, c.company_name, c.industry, c.status,
                    c.website, c.annual_revenue,
                    CONCAT(e.first_name,' ',e.last_name) AS manager
             FROM customers c LEFT JOIN employees e ON e.employee_id=c.assigned_employee
             WHERE 1=1"""
    params = []
    if search: sql += " AND c.company_name LIKE %s"; params.append(f"%{search}%")
    if status: sql += " AND c.status=%s"; params.append(status)
    sql += " ORDER BY c.company_name"
    rows = jrows(query(sql, params))
    employees_list = jrows(query("SELECT employee_id, CONCAT(first_name,' ',last_name) AS name FROM employees WHERE is_active=1"))
    return render_template("customers.html", customers=rows, employees=employees_list, search=search, status_filter=status)

@app.route("/customers/<int:cid>")
def customer_detail(cid):
    info = jrows(query("""
        SELECT c.*, CONCAT(e.first_name,' ',e.last_name) AS manager
        FROM customers c LEFT JOIN employees e ON e.employee_id=c.assigned_employee
        WHERE c.customer_id=%s
    """, (cid,)))
    if not info: return redirect(url_for("customers"))
    contacts     = jrows(query("SELECT * FROM contacts WHERE customer_id=%s", (cid,)))
    leads        = jrows(query("SELECT * FROM leads WHERE customer_id=%s ORDER BY created_at DESC", (cid,)))
    deals        = jrows(query("SELECT * FROM deals WHERE customer_id=%s ORDER BY created_at DESC", (cid,)))
    interactions = jrows(query("SELECT i.*, CONCAT(e.first_name,' ',e.last_name) AS emp_name FROM interactions i LEFT JOIN employees e ON e.employee_id=i.employee_id WHERE i.customer_id=%s ORDER BY i.interaction_date DESC LIMIT 10", (cid,)))
    tasks        = jrows(query("SELECT t.*, CONCAT(e.first_name,' ',e.last_name) AS assignee FROM tasks t LEFT JOIN employees e ON e.employee_id=t.assigned_to WHERE t.customer_id=%s ORDER BY t.due_date DESC", (cid,)))
    employees_list = jrows(query("SELECT employee_id, CONCAT(first_name,' ',last_name) AS name FROM employees WHERE is_active=1"))
    return render_template("customer_detail.html", info=info[0], contacts=contacts,
                           leads=leads, deals=deals, interactions=interactions,
                           tasks=tasks, employees=employees_list)

@app.route("/api/customers/add", methods=["POST"])
def add_customer():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    _, cid = execute("""INSERT INTO customers (company_name,industry,website,annual_revenue,status,assigned_employee)
        VALUES (%s,%s,%s,%s,%s,%s)""",
        (d["company_name"],d.get("industry"),d.get("website"),
         d.get("annual_revenue",0),d.get("status","prospect"),d.get("assigned_employee") or None))
    return jsonify({"ok": bool(cid), "id": cid})

@app.route("/api/customers/update", methods=["POST"])
def update_customer():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    execute("UPDATE customers SET status=%s, assigned_employee=%s WHERE customer_id=%s",
            (d["status"], d.get("assigned_employee") or None, d["customer_id"]))
    return jsonify({"ok": True})

@app.route("/api/customers/delete", methods=["POST"])
def delete_customer():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    if session.get('user_role') not in ('admin', 'manager'):
        return jsonify({"ok": False, "error": "Unauthorized"}), 403
    execute("DELETE FROM customers WHERE customer_id=%s", (d["customer_id"],))
    return jsonify({"ok": True})

@app.route("/api/contacts/add", methods=["POST"])
def add_contact():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    _, cid = execute("""INSERT INTO contacts (customer_id,first_name,last_name,email,phone,position,is_primary)
        VALUES (%s,%s,%s,%s,%s,%s,%s)""",
        (d["customer_id"],d["first_name"],d["last_name"],
         d.get("email"),d.get("phone"),d.get("position"),d.get("is_primary",False)))
    return jsonify({"ok": bool(cid)})

@app.route("/leads")
def leads():
    status = request.args.get("status","")
    source = request.args.get("source","")
    sql = """SELECT l.lead_id, c.company_name, l.source, l.status,
                    l.estimated_value, l.expected_close,
                    CONCAT(e.first_name,' ',e.last_name) AS rep
             FROM leads l JOIN customers c ON c.customer_id=l.customer_id
             LEFT JOIN employees e ON e.employee_id=l.assigned_to WHERE 1=1"""
    params = []
    if status: sql += " AND l.status=%s"; params.append(status)
    if source: sql += " AND l.source=%s"; params.append(source)
    sql += " ORDER BY l.created_at DESC"
    rows = jrows(query(sql, params))
    customers_list = jrows(query("SELECT customer_id, company_name FROM customers ORDER BY company_name"))
    employees_list = jrows(query("SELECT employee_id, CONCAT(first_name,' ',last_name) AS name FROM employees WHERE is_active=1"))
    stats = {
        "total":     int(safe_val("SELECT COUNT(*) FROM leads")),
        "new":       int(safe_val("SELECT COUNT(*) FROM leads WHERE status='new'")),
        "qualified": int(safe_val("SELECT COUNT(*) FROM leads WHERE status='qualified'")),
        "converted": int(safe_val("SELECT COUNT(*) FROM leads WHERE status='converted'")),
    }
    return render_template("leads.html", leads=rows, customers=customers_list,
                           employees=employees_list, stats=stats,
                           status_filter=status, source_filter=source)

@app.route("/api/leads/add", methods=["POST"])
def add_lead():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    _, lid = execute("""INSERT INTO leads (customer_id,assigned_to,source,status,estimated_value,expected_close,notes)
        VALUES (%s,%s,%s,'new',%s,%s,%s)""",
        (d["customer_id"],d.get("assigned_to") or None,d.get("source","other"),
         d.get("estimated_value",0),d.get("expected_close") or None,d.get("notes")))
    return jsonify({"ok": bool(lid), "id": lid})

@app.route("/api/leads/update-status", methods=["POST"])
def update_lead_status():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    execute("UPDATE leads SET status=%s WHERE lead_id=%s", (d["status"], d["lead_id"]))
    return jsonify({"ok": True})

@app.route("/api/leads/convert", methods=["POST"])
def convert_lead():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.callproc("sp_convert_lead_to_deal", [d["lead_id"], d["amount"], d["closed_by"], d.get("notes",""), 0])
        conn.commit(); cur.close(); conn.close()
        return jsonify({"ok": True})
    except Exception as e:
        logging.exception("Lead conversion failed")
        return jsonify({"ok": False, "error": str(e)})

@app.route("/deals")
def deals():
    stage = request.args.get("stage","")
    sql = """SELECT d.deal_id, c.company_name, d.amount, d.stage, d.closed_date,
                    CONCAT(e.first_name,' ',e.last_name) AS rep, d.notes
             FROM deals d JOIN customers c ON c.customer_id=d.customer_id
             LEFT JOIN employees e ON e.employee_id=d.closed_by WHERE 1=1"""
    params = []
    if stage: sql += " AND d.stage=%s"; params.append(stage)
    sql += " ORDER BY d.created_at DESC"
    rows = jrows(query(sql, params))
    pipeline = jrows(query("SELECT stage, COUNT(*) AS cnt, COALESCE(SUM(amount),0) AS val FROM deals GROUP BY stage"))
    customers_list = jrows(query("SELECT customer_id, company_name FROM customers ORDER BY company_name"))
    employees_list = jrows(query("SELECT employee_id, CONCAT(first_name,' ',last_name) AS name FROM employees WHERE is_active=1"))
    return render_template("deals.html", deals=rows, pipeline=pipeline, stage_filter=stage,
                           customers=customers_list, employees=employees_list)

@app.route("/api/deals/update-stage", methods=["POST"])
def update_deal_stage():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    execute("""UPDATE deals SET stage=%s,
               closed_date=IF(%s IN ('closed_won','closed_lost'),CURDATE(),closed_date)
               WHERE deal_id=%s""", (d["stage"], d["stage"], d["deal_id"]))
    return jsonify({"ok": True})

@app.route("/api/deals/add", methods=["POST"])
def add_deal():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    _, did = execute("""INSERT INTO deals (customer_id,closed_by,amount,stage,notes)
        VALUES (%s,%s,%s,%s,%s)""",
        (d["customer_id"],d.get("closed_by") or None,
         d["amount"],d.get("stage","proposal"),d.get("notes")))
    return jsonify({"ok": bool(did), "id": did})

@app.route("/tasks")
def tasks():
    rows = jrows(query("""
        SELECT t.task_id, t.title, t.priority, t.status, t.due_date,
               CONCAT(e.first_name,' ',e.last_name) AS assignee, c.company_name,
               CASE WHEN t.due_date < CURDATE() AND t.status IN ('pending','in_progress') THEN 1 ELSE 0 END AS overdue
        FROM tasks t
        LEFT JOIN employees e ON e.employee_id=t.assigned_to
        LEFT JOIN customers c ON c.customer_id=t.customer_id
        ORDER BY overdue DESC, FIELD(t.priority,'urgent','high','medium','low'), t.due_date
    """))
    employees_list = jrows(query("SELECT employee_id, CONCAT(first_name,' ',last_name) AS name FROM employees WHERE is_active=1"))
    customers_list = jrows(query("SELECT customer_id, company_name FROM customers ORDER BY company_name"))
    task_stats = {
        "pending":     int(safe_val("SELECT COUNT(*) FROM tasks WHERE status='pending'")),
        "in_progress": int(safe_val("SELECT COUNT(*) FROM tasks WHERE status='in_progress'")),
        "completed":   int(safe_val("SELECT COUNT(*) FROM tasks WHERE status='completed'")),
        "overdue":     int(safe_val("SELECT COUNT(*) FROM tasks WHERE status IN ('pending','in_progress') AND due_date < CURDATE()")),
    }
    return render_template("tasks.html", tasks=rows, employees=employees_list,
                           customers=customers_list, task_stats=task_stats)

@app.route("/api/tasks/add", methods=["POST"])
def add_task():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    _, tid = execute("""INSERT INTO tasks (assigned_to,customer_id,title,description,priority,status,due_date)
        VALUES (%s,%s,%s,%s,%s,'pending',%s)""",
        (d.get("assigned_to") or None, d.get("customer_id") or None,
         d["title"], d.get("description"), d.get("priority","medium"), d.get("due_date") or None))
    return jsonify({"ok": bool(tid), "id": tid})

@app.route("/api/tasks/complete", methods=["POST"])
def complete_task():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    execute("UPDATE tasks SET status='completed' WHERE task_id=%s", (d["task_id"],))
    return jsonify({"ok": True})

@app.route("/api/tasks/delete", methods=["POST"])
def delete_task():
    d = request.json
    if not d:
        return jsonify({"ok": False, "error": "Invalid or missing request body"}), 400
    if session.get('user_role') not in ('admin', 'manager'):
        return jsonify({"ok": False, "error": "Unauthorized"}), 403
    execute("DELETE FROM tasks WHERE task_id=%s", (d["task_id"],))
    return jsonify({"ok": True})

@app.route("/reports")
def reports():
    pipeline_rep = jrows(query("""
        SELECT CONCAT(e.first_name,' ',e.last_name) AS rep,
               COUNT(l.lead_id) AS leads,
               SUM(l.status='converted') AS converted,
               COALESCE(SUM(d.amount),0) AS revenue,
               ROUND(SUM(l.status='converted')/NULLIF(COUNT(l.lead_id),0)*100,1) AS conv_rate
        FROM employees e
        LEFT JOIN leads l ON l.assigned_to=e.employee_id
        LEFT JOIN deals d ON d.closed_by=e.employee_id AND d.stage='closed_won'
        WHERE e.role IN ('sales_rep','manager') AND e.is_active=1
        GROUP BY e.employee_id ORDER BY revenue DESC
    """))
    monthly = jrows(query("""
        SELECT MONTH(closed_date) AS m, CONCAT(LEFT(MONTHNAME(closed_date),3),' ',YEAR(closed_date)) AS mn,
               COUNT(*) AS deals, COALESCE(SUM(amount),0) AS revenue
        FROM deals WHERE stage='closed_won' AND closed_date IS NOT NULL
        GROUP BY YEAR(closed_date), MONTH(closed_date), MONTHNAME(closed_date)
        ORDER BY YEAR(closed_date), MONTH(closed_date)
    """))
    products = jrows(query("""
        SELECT p.name, p.category, SUM(dp.quantity) AS units,
               SUM(dp.quantity*dp.unit_price) AS revenue
        FROM deal_products dp JOIN products p ON p.product_id=dp.product_id
        JOIN deals d ON d.deal_id=dp.deal_id AND d.stage='closed_won'
        GROUP BY p.product_id ORDER BY revenue DESC
    """))
    sources = jrows(query("""
        SELECT source, COUNT(*) AS total, SUM(status='converted') AS converted,
               ROUND(SUM(status='converted')/COUNT(*)*100,1) AS rate
        FROM leads GROUP BY source ORDER BY rate DESC
    """))
    churn = jrows(query("""
        SELECT c.company_name, MAX(i.interaction_date) AS last_contact,
               DATEDIFF(NOW(),MAX(i.interaction_date)) AS days_idle
        FROM customers c LEFT JOIN interactions i ON i.customer_id=c.customer_id
        WHERE c.status='active'
        GROUP BY c.customer_id HAVING days_idle > 30 OR last_contact IS NULL
        ORDER BY days_idle DESC LIMIT 8
    """))
    return render_template("reports.html", pipeline_rep=pipeline_rep, monthly=monthly,
                           products=products, sources=sources, churn=churn)

@app.route("/audit")
def audit():
    table_filter = request.args.get("table","")
    sql = """SELECT al.log_id, al.changed_at, al.table_name, al.action, al.record_id,
                    CONCAT(e.first_name,' ',e.last_name) AS changed_by
             FROM audit_log al LEFT JOIN employees e ON e.employee_id=al.changed_by
             WHERE 1=1"""
    params = []
    if table_filter: sql += " AND al.table_name=%s"; params.append(table_filter)
    sql += " ORDER BY al.changed_at DESC LIMIT 60"
    rows = jrows(query(sql, params))
    audit_stats = {
        "inserts": int(safe_val("SELECT COUNT(*) FROM audit_log WHERE action='INSERT'")),
        "updates": int(safe_val("SELECT COUNT(*) FROM audit_log WHERE action='UPDATE'")),
        "deletes": int(safe_val("SELECT COUNT(*) FROM audit_log WHERE action='DELETE'")),
        "total":   int(safe_val("SELECT COUNT(*) FROM audit_log")),
    }
    return render_template("audit.html", logs=rows, audit_stats=audit_stats, table_filter=table_filter)

@app.route("/employees")
def employees():
    rows = jrows(query("""
        SELECT e.employee_id, e.first_name, e.last_name, e.email, e.phone,
               e.role, e.hire_date, e.is_active, e.manager_id,
               CONCAT(m.first_name,' ',m.last_name) AS manager_name,
               (SELECT COUNT(*) FROM deals d WHERE d.closed_by=e.employee_id AND d.stage='closed_won') AS deals_won,
               (SELECT COALESCE(SUM(d2.amount),0) FROM deals d2 WHERE d2.closed_by=e.employee_id AND d2.stage='closed_won') AS revenue
        FROM employees e LEFT JOIN employees m ON m.employee_id=e.manager_id
        ORDER BY e.role, e.first_name
    """))
    return render_template("employees.html", employees=rows)

if __name__ == "__main__":
    app.run(debug=os.getenv("FLASK_DEBUG", "False") == "True", port=5000)