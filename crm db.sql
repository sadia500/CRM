-- ============================================================
--  CRM DATABASE — Full MySQL Script
--  Tables · Indexes · Sample Data · Stored Procedures · Triggers
-- ============================================================

CREATE DATABASE IF NOT EXISTS crm_db;
USE crm_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS audit_log, tasks, interactions, deal_products, deals, leads, contacts, customers, products, employees;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
--  1. TABLES
-- ============================================================

CREATE TABLE employees (
    employee_id   INT AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    phone         VARCHAR(20),
    role          ENUM('admin','manager','sales_rep','support') NOT NULL DEFAULT 'sales_rep',
    manager_id    INT DEFAULT NULL,
    hire_date     DATE         NOT NULL,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE customers (
    customer_id       INT AUTO_INCREMENT PRIMARY KEY,
    company_name      VARCHAR(150) NOT NULL,
    industry          VARCHAR(80),
    website           VARCHAR(200),
    annual_revenue    DECIMAL(15,2) DEFAULT 0.00,
    status            ENUM('prospect','active','inactive','churned') NOT NULL DEFAULT 'prospect',
    assigned_employee INT DEFAULT NULL,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_cust_emp FOREIGN KEY (assigned_employee) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE contacts (
    contact_id    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id   INT         NOT NULL,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    email         VARCHAR(100),
    phone         VARCHAR(20),
    position      VARCHAR(100),
    is_primary    BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cont_cust FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

CREATE TABLE products (
    product_id     INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(150) NOT NULL,
    category       VARCHAR(80),
    description    TEXT,
    price          DECIMAL(10,2) NOT NULL,
    stock_quantity INT           NOT NULL DEFAULT 0,
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE leads (
    lead_id          INT AUTO_INCREMENT PRIMARY KEY,
    customer_id      INT         NOT NULL,
    assigned_to      INT         DEFAULT NULL,
    source           ENUM('website','referral','cold_call','email','social_media','event','other') DEFAULT 'other',
    status           ENUM('new','contacted','qualified','unqualified','converted') NOT NULL DEFAULT 'new',
    estimated_value  DECIMAL(15,2) DEFAULT 0.00,
    expected_close   DATE,
    notes            TEXT,
    created_at       TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_lead_cust FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_lead_emp  FOREIGN KEY (assigned_to)  REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE deals (
    deal_id      INT AUTO_INCREMENT PRIMARY KEY,
    lead_id      INT           DEFAULT NULL,
    customer_id  INT           NOT NULL,
    closed_by    INT           DEFAULT NULL,
    amount       DECIMAL(15,2) NOT NULL,
    stage        ENUM('proposal','negotiation','closed_won','closed_lost') NOT NULL DEFAULT 'proposal',
    closed_date  DATE,
    notes        TEXT,
    created_at   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_deal_lead FOREIGN KEY (lead_id)     REFERENCES leads(lead_id)         ON DELETE SET NULL,
    CONSTRAINT fk_deal_cust FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_deal_emp  FOREIGN KEY (closed_by)   REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE deal_products (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    deal_id      INT           NOT NULL,
    product_id   INT           NOT NULL,
    quantity     INT           NOT NULL DEFAULT 1,
    unit_price   DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_dp_deal    FOREIGN KEY (deal_id)    REFERENCES deals(deal_id)       ON DELETE CASCADE,
    CONSTRAINT fk_dp_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    UNIQUE KEY uq_deal_product (deal_id, product_id)
);

CREATE TABLE interactions (
    interaction_id   INT AUTO_INCREMENT PRIMARY KEY,
    customer_id      INT NOT NULL,
    contact_id       INT DEFAULT NULL,
    employee_id      INT DEFAULT NULL,
    type             ENUM('call','email','meeting','demo','support','other') NOT NULL DEFAULT 'other',
    subject          VARCHAR(200),
    notes            TEXT,
    interaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_int_cust FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_int_cont FOREIGN KEY (contact_id)  REFERENCES contacts(contact_id)  ON DELETE SET NULL,
    CONSTRAINT fk_int_emp  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE tasks (
    task_id     INT AUTO_INCREMENT PRIMARY KEY,
    assigned_to INT         DEFAULT NULL,
    customer_id INT         DEFAULT NULL,
    deal_id     INT         DEFAULT NULL,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    priority    ENUM('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
    status      ENUM('pending','in_progress','completed','cancelled') NOT NULL DEFAULT 'pending',
    due_date    DATE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_task_emp  FOREIGN KEY (assigned_to) REFERENCES employees(employee_id) ON DELETE SET NULL,
    CONSTRAINT fk_task_cust FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE SET NULL,
    CONSTRAINT fk_task_deal FOREIGN KEY (deal_id)     REFERENCES deals(deal_id)         ON DELETE SET NULL
);

CREATE TABLE audit_log (
    log_id      INT AUTO_INCREMENT PRIMARY KEY,
    table_name  VARCHAR(50)  NOT NULL,
    action      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id   INT          NOT NULL,
    changed_by  INT          DEFAULT NULL,
    changed_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    old_values  JSON,
    new_values  JSON,
    CONSTRAINT fk_audit_emp FOREIGN KEY (changed_by) REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- ============================================================
--  2. INDEXES
-- ============================================================

CREATE INDEX idx_customers_status   ON customers(status);
CREATE INDEX idx_customers_industry ON customers(industry);
CREATE INDEX idx_leads_status       ON leads(status);
CREATE INDEX idx_leads_source       ON leads(source);
CREATE INDEX idx_deals_stage        ON deals(stage);
CREATE INDEX idx_deals_closed_date  ON deals(closed_date);
CREATE INDEX idx_interactions_date  ON interactions(interaction_date);
CREATE INDEX idx_tasks_due_date     ON tasks(due_date);
CREATE INDEX idx_tasks_status       ON tasks(status);
CREATE INDEX idx_audit_table        ON audit_log(table_name, record_id);

-- ============================================================
--  3. SAMPLE DATA
-- ============================================================


-- ============================================================
--  4. STORED PROCEDURES
-- ============================================================

DELIMITER $$

-- 4a. Convert a lead to a deal
CREATE PROCEDURE sp_convert_lead_to_deal(
    IN  p_lead_id      INT,
    IN  p_amount       DECIMAL(15,2),
    IN  p_closed_by    INT,
    IN  p_notes        TEXT,
    OUT p_deal_id      INT
)
BEGIN
    DECLARE v_customer_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT customer_id INTO v_customer_id FROM leads WHERE lead_id = p_lead_id;

    INSERT INTO deals (lead_id, customer_id, closed_by, amount, stage, closed_date, notes)
    VALUES (p_lead_id, v_customer_id, p_closed_by, p_amount, 'closed_won', CURDATE(), p_notes);

    SET p_deal_id = LAST_INSERT_ID();

    UPDATE leads SET status = 'converted', updated_at = NOW() WHERE lead_id = p_lead_id;
    UPDATE customers SET status = 'active',   updated_at = NOW() WHERE customer_id = v_customer_id;

    COMMIT;
END$$

-- 4b. Sales pipeline report per employee
CREATE PROCEDURE sp_sales_pipeline_report(
    IN p_employee_id INT
)
BEGIN
    SELECT
        e.first_name,
        e.last_name,
        COUNT(l.lead_id)                                          AS total_leads,
        SUM(l.status = 'converted')                               AS converted_leads,
        ROUND(SUM(l.status = 'converted') / COUNT(l.lead_id) * 100, 1) AS conversion_rate_pct,
        SUM(d.amount)                                             AS total_revenue,
        AVG(d.amount)                                             AS avg_deal_value,
        SUM(d.stage = 'proposal')                                 AS deals_in_proposal,
        SUM(d.stage = 'negotiation')                              AS deals_in_negotiation
    FROM employees e
    LEFT JOIN leads l ON l.assigned_to = e.employee_id
    LEFT JOIN deals d ON d.closed_by  = e.employee_id AND d.stage = 'closed_won'
    WHERE (p_employee_id IS NULL OR e.employee_id = p_employee_id)
    GROUP BY e.employee_id, e.first_name, e.last_name
    ORDER BY total_revenue DESC;
END$$

-- 4c. Customer 360 — full snapshot of a customer
CREATE PROCEDURE sp_customer_360(
    IN p_customer_id INT
)
BEGIN
    SELECT c.*, e.first_name AS rep_first, e.last_name AS rep_last
    FROM customers c
    LEFT JOIN employees e ON e.employee_id = c.assigned_employee
    WHERE c.customer_id = p_customer_id;

    SELECT * FROM contacts       WHERE customer_id = p_customer_id;
    SELECT * FROM leads          WHERE customer_id = p_customer_id ORDER BY created_at DESC;
    SELECT * FROM deals          WHERE customer_id = p_customer_id ORDER BY created_at DESC;
    SELECT * FROM interactions   WHERE customer_id = p_customer_id ORDER BY interaction_date DESC LIMIT 10;
    SELECT * FROM tasks          WHERE customer_id = p_customer_id ORDER BY due_date DESC;
END$$

-- 4d. Auto-create follow-up tasks for open leads older than N days
CREATE PROCEDURE sp_auto_followup_tasks(
    IN p_days_old INT
)
BEGIN
    INSERT INTO tasks (assigned_to, customer_id, title, priority, status, due_date)
    SELECT
        l.assigned_to,
        l.customer_id,
        CONCAT('Follow-up required: ', c.company_name),
        'high',
        'pending',
        DATE_ADD(CURDATE(), INTERVAL 2 DAY)
    FROM leads l
    JOIN customers c ON c.customer_id = l.customer_id
    WHERE l.status IN ('new', 'contacted', 'qualified')
      AND l.updated_at < DATE_SUB(NOW(), INTERVAL p_days_old DAY)
      AND NOT EXISTS (
          SELECT 1 FROM tasks t
          WHERE t.customer_id = l.customer_id
            AND t.status IN ('pending','in_progress')
            AND t.due_date >= CURDATE()
      );

    SELECT ROW_COUNT() AS follow_up_tasks_created;
END$$

-- 4e. Monthly revenue summary
CREATE PROCEDURE sp_monthly_revenue(
    IN p_year INT
)
BEGIN
    SELECT
        MONTH(closed_date)              AS month_num,
        MONTHNAME(closed_date)          AS month_name,
        COUNT(*)                        AS deals_closed,
        SUM(amount)                     AS total_revenue,
        AVG(amount)                     AS avg_deal_value,
        MAX(amount)                     AS largest_deal
    FROM deals
    WHERE stage = 'closed_won'
      AND YEAR(closed_date) = p_year
    GROUP BY MONTH(closed_date), MONTHNAME(closed_date)
    ORDER BY month_num;
END$$

DELIMITER ;

-- ============================================================
--  5. TRIGGERS
-- ============================================================

DELIMITER $$

-- 5a. Audit log: customers UPDATE
CREATE TRIGGER trg_customers_audit_update
AFTER UPDATE ON customers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, old_values, new_values)
    VALUES (
        'customers', 'UPDATE', OLD.customer_id,
        JSON_OBJECT('company_name', OLD.company_name, 'status', OLD.status,
                    'assigned_employee', OLD.assigned_employee, 'annual_revenue', OLD.annual_revenue),
        JSON_OBJECT('company_name', NEW.company_name, 'status', NEW.status,
                    'assigned_employee', NEW.assigned_employee, 'annual_revenue', NEW.annual_revenue)
    );
END$$

-- 5b. Audit log: deals INSERT
CREATE TRIGGER trg_deals_audit_insert
AFTER INSERT ON deals
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, new_values)
    VALUES (
        'deals', 'INSERT', NEW.deal_id,
        JSON_OBJECT('customer_id', NEW.customer_id, 'amount', NEW.amount,
                    'stage', NEW.stage, 'closed_by', NEW.closed_by)
    );
END$$

-- 5c. Audit log: deals UPDATE
CREATE TRIGGER trg_deals_audit_update
AFTER UPDATE ON deals
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, old_values, new_values)
    VALUES (
        'deals', 'UPDATE', OLD.deal_id,
        JSON_OBJECT('amount', OLD.amount, 'stage', OLD.stage, 'closed_date', OLD.closed_date),
        JSON_OBJECT('amount', NEW.amount, 'stage', NEW.stage, 'closed_date', NEW.closed_date)
    );
END$$

-- 5d. Auto-set customer status to 'active' when a deal is closed_won
CREATE TRIGGER trg_deal_activate_customer
AFTER INSERT ON deals
FOR EACH ROW
BEGIN
    IF NEW.stage = 'closed_won' THEN
        UPDATE customers
        SET status = 'active', updated_at = NOW()
        WHERE customer_id = NEW.customer_id AND status != 'active';
    END IF;
END$$

-- 5e. Prevent deleting an employee who has active open deals
CREATE TRIGGER trg_prevent_emp_delete_with_deals
BEFORE DELETE ON employees
FOR EACH ROW
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM deals
    WHERE closed_by = OLD.employee_id AND stage IN ('proposal','negotiation');

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete employee with active open deals. Reassign deals first.';
    END IF;
END$$

-- 5f. Auto-log lead status changes
CREATE TRIGGER trg_leads_audit_update
AFTER UPDATE ON leads
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO audit_log (table_name, action, record_id, old_values, new_values)
        VALUES (
            'leads', 'UPDATE', OLD.lead_id,
            JSON_OBJECT('status', OLD.status, 'estimated_value', OLD.estimated_value),
            JSON_OBJECT('status', NEW.status, 'estimated_value', NEW.estimated_value)
        );
    END IF;
END$$

DELIMITER ;

-- ============================================================
--  6. USEFUL QUERIES (for reports & viva)
-- ============================================================

-- Q1: All active customers with their assigned rep
SELECT c.company_name, c.industry, c.status,
       CONCAT(e.first_name,' ',e.last_name) AS account_manager
FROM customers c
LEFT JOIN employees e ON e.employee_id = c.assigned_employee
WHERE c.status = 'active'
ORDER BY c.company_name;

-- Q2: Total revenue per sales rep
SELECT CONCAT(e.first_name,' ',e.last_name) AS sales_rep,
       COUNT(d.deal_id)                      AS deals_won,
       SUM(d.amount)                         AS total_revenue
FROM deals d
JOIN employees e ON e.employee_id = d.closed_by
WHERE d.stage = 'closed_won'
GROUP BY d.closed_by
ORDER BY total_revenue DESC;

-- Q3: Lead conversion rate by source
SELECT source,
       COUNT(*)                                              AS total_leads,
       SUM(status = 'converted')                             AS converted,
       ROUND(SUM(status = 'converted') / COUNT(*) * 100, 1) AS conversion_pct
FROM leads
GROUP BY source
ORDER BY conversion_pct DESC;

-- Q4: Top deals with products purchased
SELECT d.deal_id, c.company_name, d.amount, d.stage,
       GROUP_CONCAT(p.name ORDER BY p.name SEPARATOR ' | ') AS products_purchased
FROM deals d
JOIN customers c ON c.customer_id = d.customer_id
JOIN deal_products dp ON dp.deal_id = d.deal_id
JOIN products p ON p.product_id = dp.product_id
GROUP BY d.deal_id, c.company_name, d.amount, d.stage
ORDER BY d.amount DESC;

-- Q5: Customers with no interaction in the last 60 days (churn risk)
SELECT c.company_name, c.status,
       MAX(i.interaction_date) AS last_contact,
       DATEDIFF(NOW(), MAX(i.interaction_date)) AS days_since_contact
FROM customers c
LEFT JOIN interactions i ON i.customer_id = c.customer_id
WHERE c.status = 'active'
GROUP BY c.customer_id, c.company_name, c.status
HAVING days_since_contact > 60 OR last_contact IS NULL
ORDER BY days_since_contact DESC;

-- Q6: Pipeline value by stage
SELECT stage,
       COUNT(*)    AS num_deals,
       SUM(amount) AS pipeline_value
FROM deals
WHERE stage NOT IN ('closed_won','closed_lost')
GROUP BY stage;

-- Q7: Best-selling products by revenue
SELECT p.name, p.category,
       SUM(dp.quantity)              AS units_sold,
       SUM(dp.quantity * dp.unit_price) AS total_revenue
FROM deal_products dp
JOIN products p ON p.product_id = dp.product_id
JOIN deals d ON d.deal_id = dp.deal_id
WHERE d.stage = 'closed_won'
GROUP BY p.product_id, p.name, p.category
ORDER BY total_revenue DESC;

-- Q8: Employee activity summary (calls, emails, meetings)
SELECT CONCAT(e.first_name,' ',e.last_name) AS employee,
       SUM(i.type = 'call')    AS calls,
       SUM(i.type = 'email')   AS emails,
       SUM(i.type = 'meeting') AS meetings,
       SUM(i.type = 'demo')    AS demos,
       COUNT(i.interaction_id) AS total_interactions
FROM employees e
LEFT JOIN interactions i ON i.employee_id = e.employee_id
GROUP BY e.employee_id
ORDER BY total_interactions DESC;

-- Q9: Tasks overdue and still pending
SELECT t.title, t.priority, t.due_date,
       CONCAT(e.first_name,' ',e.last_name) AS assigned_to,
       c.company_name,
       DATEDIFF(CURDATE(), t.due_date)      AS days_overdue
FROM tasks t
LEFT JOIN employees e ON e.employee_id = t.assigned_to
LEFT JOIN customers c ON c.customer_id = t.customer_id
WHERE t.status IN ('pending','in_progress')
  AND t.due_date < CURDATE()
ORDER BY days_overdue DESC;

-- Q10: Full audit trail for a specific customer (customer_id = 1)
SELECT al.changed_at, al.table_name, al.action,
       CONCAT(e.first_name,' ',e.last_name) AS changed_by,
       al.old_values, al.new_values
FROM audit_log al
LEFT JOIN employees e ON e.employee_id = al.changed_by
WHERE al.record_id = 1 AND al.table_name = 'customers'
ORDER BY al.changed_at DESC;


-- ============================================================
--  3. SAMPLE DATA — Pakistani Companies (Real-World Data)
-- ============================================================

-- Employees
INSERT INTO employees (employee_id, first_name, last_name, email, phone, role, manager_id, hire_date) VALUES
(1, 'Kamran',  'Sheikh',   'kamran.sheikh@crm.pk',  '+92-300-1234567', 'admin',     NULL, '2020-01-10'),
(2, 'Sana',    'Rizvi',    'sana.rizvi@crm.pk',     '+92-321-2345678', 'manager',   1,    '2020-04-15'),
(3, 'Bilal',   'Mahmood',  'bilal.mahmood@crm.pk',  '+92-333-3456789', 'sales_rep', 2,    '2021-03-01'),
(4, 'Ayesha',  'Farooq',   'ayesha.farooq@crm.pk',  '+92-345-4567890', 'sales_rep', 2,    '2021-07-15'),
(5, 'Usman',   'Qureshi',  'usman.qureshi@crm.pk',  '+92-312-5678901', 'sales_rep', 2,    '2022-01-10'),
(6, 'Fatima',  'Butt',     'fatima.butt@crm.pk',    '+92-315-6789012', 'support',   1,    '2022-05-20'),
(7, 'Omer',    'Naeem',    'omer.naeem@crm.pk',     '+92-300-7890123', 'manager',   1,    '2021-02-01');

-- Customers
INSERT INTO customers (customer_id, company_name, industry, website, annual_revenue, status, assigned_employee) VALUES
(1,  'Systems Limited',         'Technology',       'systemsltd.com',        850000000, 'active',   3),
(2,  'Engro Corporation',       'Conglomerate',     'engro.com',            1200000000, 'active',   4),
(3,  'Habib Bank Limited',      'Finance',          'hbl.com',              3200000000, 'active',   3),
(4,  'Daraz Pakistan',          'E-Commerce',       'daraz.pk',              450000000, 'active',   5),
(5,  'K-Electric',              'Energy',           'ke.com.pk',            1800000000, 'active',   4),
(6,  'Shaukat Khanum Hospital', 'Healthcare',       'shaukatkhanum.org.pk',  320000000, 'prospect', 5),
(7,  'Pak Suzuki Motors',       'Automotive',       'paksuzuki.com.pk',      980000000, 'active',   3),
(8,  'Ufone Telecom',           'Telecommunications','ufone.com',            760000000, 'inactive', 4),
(9,  'Ali Baba Textile Mills',  'Textile',          'alibabatextile.pk',     280000000, 'prospect', 5),
(10, 'TCS Pakistan',            'Logistics',        'tcs.com.pk',            190000000, 'active',   3);

-- Contacts
INSERT INTO contacts (customer_id, first_name, last_name, email, phone, position, is_primary) VALUES
(1, 'Asif',     'Peer',      'asif.peer@systemsltd.com',     '+92-300-1111111', 'CEO',               TRUE),
(1, 'Mehwish',  'Ali',       'mehwish.ali@systemsltd.com',   '+92-321-2222222', 'IT Director',       FALSE),
(2, 'Ghias',    'Khan',      'ghias.khan@engro.com',         '+92-333-3333333', 'President & CEO',   TRUE),
(3, 'Muhammad', 'Aurangzeb', 'm.aurangzeb@hbl.com',          '+92-300-4444444', 'President & CEO',   TRUE),
(4, 'Ehsan',    'Saya',      'ehsan.saya@daraz.pk',          '+92-321-5555555', 'CEO',               TRUE),
(5, 'Moonis',   'Alvi',      'moonis.alvi@ke.com.pk',        '+92-333-6666666', 'CEO',               TRUE),
(6, 'Faisal',   'Sultan',    'faisal@shaukatkhanum.org.pk',  '+92-345-7777777', 'CEO',               TRUE),
(7, 'Hirofumi', 'Nagano',    'h.nagano@paksuzuki.com.pk',    '+92-300-8888888', 'Managing Director', TRUE),
(9, 'Khalid',   'Mahmood',   'khalid@alibabatextile.pk',     '+92-312-9999999', 'Owner',             TRUE),
(10,'Muhammad', 'Jamal',     'm.jamal@tcs.com.pk',           '+92-315-0000000', 'COO',               TRUE);

-- Products
INSERT INTO products (product_id, name, category, description, price, stock_quantity) VALUES
(1,  'CRM Enterprise License',  'Software',       'Annual per-seat enterprise CRM license',     95000.00, 9999),
(2,  'Analytics Module',        'Software',       'Real-time reporting and BI dashboard',        65000.00, 9999),
(3,  'API Integration Pack',    'Software',       'REST API and third-party connectors',         45000.00, 9999),
(4,  'Onboarding Package',      'Service',        '30-day dedicated onboarding support',        200000.00,  500),
(5,  'Priority Support SLA',    'Service',        '24/7 priority support annual contract',      280000.00,  500),
(6,  'Data Migration Service',  'Service',        'Full historical data migration',             320000.00,  200),
(7,  'Training Workshop',       'Training',       'On-site team training per day',             145000.00,  300),
(8,  'Mobile App Add-on',       'Software',       'iOS and Android companion application',       35000.00, 9999),
(9,  'Custom Report Builder',   'Software',       'Drag-and-drop custom report designer',        75000.00, 9999),
(10, 'Cloud Storage 1TB',       'Infrastructure', 'Additional cloud storage annually',           40000.00, 1000);

-- Leads
INSERT INTO leads (lead_id, customer_id, assigned_to, source, status, estimated_value, expected_close, notes) VALUES
(1,  1, 3, 'referral',    'converted',  3800000, '2024-02-15', 'Systems Limited enterprise deal — 50 seats'),
(2,  2, 4, 'cold_call',   'converted',  5200000, '2024-03-20', 'Engro Corporation full suite — 80 seats'),
(3,  3, 3, 'event',       'converted',  8900000, '2024-04-10', 'HBL banking compliance CRM — 120 seats'),
(4,  4, 5, 'website',     'converted',  2100000, '2024-05-05', 'Daraz e-commerce integration — 30 seats'),
(5,  5, 4, 'referral',    'converted',  6400000, '2024-06-15', 'K-Electric energy sector CRM — 70 seats'),
(6,  7, 3, 'cold_call',   'converted',  3200000, '2024-07-01', 'Pak Suzuki dealer network CRM — 40 seats'),
(7,  6, 5, 'event',       'qualified',  1800000, '2024-09-30', 'Shaukat Khanum healthcare CRM — proposal sent'),
(8,  9, 5, 'website',     'contacted',   950000, '2024-10-15', 'Ali Baba Textile basic package interest'),
(9,  10,3, 'email',       'qualified',  1200000, '2024-11-30', 'TCS Pakistan logistics module — negotiating'),
(10, 8, 4, 'social_media','unqualified', 500000, '2024-08-01', 'Ufone — budget constraints flagged');

-- Deals
INSERT INTO deals (deal_id, lead_id, customer_id, closed_by, amount, stage, closed_date, notes) VALUES
(1, 1, 1, 3, 3650000, 'closed_won',  '2024-02-12', '50 seats CRM Enterprise + Analytics Module'),
(2, 2, 2, 4, 5100000, 'closed_won',  '2024-03-18', 'Engro — 80 seats full suite + SLA'),
(3, 3, 3, 3, 8750000, 'closed_won',  '2024-04-08', 'HBL — 120 seats enterprise + SLA + Migration'),
(4, 4, 4, 5, 2050000, 'closed_won',  '2024-05-02', 'Daraz — 30 seats + API Pack + Mobile App'),
(5, 5, 5, 4, 6200000, 'closed_won',  '2024-06-12', 'K-Electric — 70 seats + Data Migration'),
(6, 6, 7, 3, 3100000, 'closed_won',  '2024-06-28', 'Pak Suzuki — 40 seats + Onboarding Package'),
(7, 7, 6, 5, 1800000, 'proposal',    NULL,          'Shaukat Khanum — awaiting board approval'),
(8, 9,10, 3,  950000, 'negotiation', NULL,          'TCS Pakistan — finalizing logistics module price');

-- Deal Products
INSERT INTO deal_products (deal_id, product_id, quantity, unit_price) VALUES
(1, 1, 50, 90000.00), (1, 2,  1, 65000.00), (1, 4,  1, 200000.00),
(2, 1, 80, 88000.00), (2, 2,  1, 65000.00), (2, 3,  1,  45000.00), (2, 5, 1, 280000.00),
(3, 1,120, 85000.00), (3, 5,  1,280000.00), (3, 6,  1, 320000.00),
(4, 1, 30, 90000.00), (4, 3,  1, 45000.00), (4, 8, 30,  35000.00),
(5, 1, 70, 88000.00), (5, 5,  1,280000.00), (5, 6,  1, 320000.00),
(6, 1, 40, 90000.00), (6, 4,  1,200000.00), (6, 7,  2, 145000.00);

-- Interactions
INSERT INTO interactions (customer_id, contact_id, employee_id, type, subject, notes, interaction_date) VALUES
(1, 1, 3, 'call',    'Discovery call — Systems Limited',        'Discussed CRM for 500+ employees',         '2024-01-15 10:00:00'),
(1, 2, 3, 'demo',    'Product demo — enterprise suite',         'IT team very impressed with dashboard',     '2024-01-25 14:00:00'),
(2, 3, 4, 'meeting', 'Executive presentation at Engro HQ',      'CFO approved full deployment budget',      '2024-02-20 11:00:00'),
(3, 4, 3, 'meeting', 'HBL compliance & security review',        'Data security policies reviewed',          '2024-03-05 15:00:00'),
(4, 5, 5, 'demo',    'Daraz e-commerce integration demo',       'Showed API capabilities live',             '2024-04-10 10:00:00'),
(5, 6, 4, 'call',    'K-Electric requirements gathering',       'Energy sector specific needs discussed',   '2024-05-08 09:00:00'),
(7, 8, 3, 'demo',    'Pak Suzuki dealer network demo',          'Dealer portal features showcased',         '2024-06-01 14:00:00'),
(6, 7, 5, 'meeting', 'Shaukat Khanum initial meeting',          'Healthcare CRM requirements gathered',     '2024-07-15 11:00:00'),
(10,10, 3, 'email',  'TCS Pakistan proposal sent',              'Customized logistics CRM proposal emailed','2024-08-20 09:00:00'),
(9, 9, 5, 'call',    'Ali Baba Textile follow-up call',         'Interested in basic CRM package',         '2024-09-10 10:00:00'),
(1, 1, 3, 'meeting', 'Systems Limited Q3 review',               'Discussed expansion to 80 seats in 2025', '2024-09-20 11:00:00'),
(3, 4, 3, 'call',    'HBL post-implementation check',          'All 120 users onboarded successfully',     '2024-10-01 10:00:00');

-- Tasks
INSERT INTO tasks (task_id, assigned_to, customer_id, deal_id, title, priority, status, due_date) VALUES
(1,  3, 1, 1, 'Send onboarding schedule to Systems Limited',     'high',   'completed',   '2024-02-20'),
(2,  4, 2, 2, 'Coordinate Engro deployment for 80 users',        'urgent', 'completed',   '2024-03-25'),
(3,  3, 3, 3, 'HBL data migration kickoff meeting',              'urgent', 'completed',   '2024-04-15'),
(4,  5, 4, 4, 'Daraz API go-live testing and verification',      'high',   'completed',   '2024-05-10'),
(5,  4, 5, 5, 'K-Electric training workshop — Karachi office',   'high',   'completed',   '2024-06-20'),
(6,  3, 7, 6, 'Pak Suzuki dealer portal configuration',          'medium', 'completed',   '2024-07-05'),
(7,  5, 6, 7, 'Follow up on Shaukat Khanum board approval',      'high',   'in_progress', '2024-09-25'),
(8,  3,10, 8, 'TCS — finalize pricing for logistics module',     'high',   'in_progress', '2024-10-10'),
(9,  5, 9,NULL,'Schedule demo for Ali Baba Textile CEO',         'medium', 'pending',     '2024-10-20'),
(10, 6, 1, 1, 'Systems Limited Q4 support review call',          'medium', 'pending',     '2024-11-01');

-- ============================================================
--  VERIFY DATA
-- ============================================================
SELECT 'Employees'    AS Table_Name, COUNT(*) AS Records FROM employees
UNION ALL SELECT 'Customers',   COUNT(*) FROM customers
UNION ALL SELECT 'Contacts',    COUNT(*) FROM contacts
UNION ALL SELECT 'Products',    COUNT(*) FROM products
UNION ALL SELECT 'Leads',       COUNT(*) FROM leads
UNION ALL SELECT 'Deals',       COUNT(*) FROM deals
UNION ALL SELECT 'Deal Products',COUNT(*) FROM deal_products
UNION ALL SELECT 'Interactions',COUNT(*) FROM interactions
UNION ALL SELECT 'Tasks',       COUNT(*) FROM tasks;

-- ============================================================
--  QUICK REPORTS (Test your stored procedures)
-- ============================================================
-- CALL sp_sales_pipeline_report(NULL);
-- CALL sp_monthly_revenue(2024);
-- CALL sp_customer_360(3);
-- SELECT * FROM vw_sales_performance;
-- SELECT * FROM vw_active_customers;
