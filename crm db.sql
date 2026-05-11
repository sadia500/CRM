CREATE DATABASE IF NOT EXISTS crm_db;
USE crm_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS audit_log, tasks, interactions, deal_products, deals, leads, contacts, customers, products, employees;
SET FOREIGN_KEY_CHECKS = 1;
DROP PROCEDURE IF EXISTS sp_convert_lead_to_deal;

-- =============================================
-- 1. TABLES
-- =============================================

CREATE TABLE employees (
    employee_id     INT AUTO_INCREMENT PRIMARY KEY,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    phone           VARCHAR(20),
    role            ENUM('admin','manager','sales_rep','support') NOT NULL DEFAULT 'sales_rep',
    manager_id      INT DEFAULT NULL,
    hire_date       DATE NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    password_hash   VARCHAR(255) NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE customers (
    customer_id       INT AUTO_INCREMENT PRIMARY KEY,
    company_name      VARCHAR(150) NOT NULL,
    industry          VARCHAR(80),
    website           VARCHAR(200),
    annual_revenue    DECIMAL(15,2) DEFAULT 0.00,
    status            ENUM('prospect','active','inactive','churned') NOT NULL DEFAULT 'prospect',
    assigned_employee INT DEFAULT NULL,
    password_hash     VARCHAR(255) NOT NULL DEFAULT 'admin123',
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (assigned_employee) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE contacts (
    contact_id  INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    first_name  VARCHAR(50) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    email       VARCHAR(100),
    phone       VARCHAR(20),
    position    VARCHAR(100),
    is_primary  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

CREATE TABLE products (
    product_id     INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(150) NOT NULL,
    category       VARCHAR(80),
    description    TEXT,
    price          DECIMAL(10,2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE leads (
    lead_id         INT AUTO_INCREMENT PRIMARY KEY,
    customer_id     INT NOT NULL,
    assigned_to     INT DEFAULT NULL,
    source          ENUM('website','referral','cold_call','email','social_media','event','other') DEFAULT 'other',
    status          ENUM('new','contacted','qualified','unqualified','converted') NOT NULL DEFAULT 'new',
    estimated_value DECIMAL(15,2) DEFAULT 0.00,
    expected_close  DATE,
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE deals (
    deal_id     INT AUTO_INCREMENT PRIMARY KEY,
    lead_id     INT DEFAULT NULL,
    customer_id INT NOT NULL,
    closed_by   INT DEFAULT NULL,
    amount      DECIMAL(15,2) NOT NULL,
    stage       ENUM('proposal','negotiation','closed_won','closed_lost') NOT NULL DEFAULT 'proposal',
    closed_date DATE,
    notes       TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lead_id)     REFERENCES leads(lead_id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (closed_by)   REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE deal_products (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    deal_id    INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (deal_id)    REFERENCES deals(deal_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    UNIQUE (deal_id, product_id)
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
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (contact_id)  REFERENCES contacts(contact_id) ON DELETE SET NULL,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE tasks (
    task_id     INT AUTO_INCREMENT PRIMARY KEY,
    assigned_to INT DEFAULT NULL,
    customer_id INT DEFAULT NULL,
    deal_id     INT DEFAULT NULL,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    priority    ENUM('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
    status      ENUM('pending','in_progress','completed','cancelled') NOT NULL DEFAULT 'pending',
    due_date    DATE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (assigned_to) REFERENCES employees(employee_id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE SET NULL,
    FOREIGN KEY (deal_id)     REFERENCES deals(deal_id) ON DELETE SET NULL
);

CREATE TABLE audit_log (
    log_id      INT AUTO_INCREMENT PRIMARY KEY,
    table_name  VARCHAR(50) NOT NULL,
    action      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id   INT NOT NULL,
    changed_by  INT DEFAULT NULL,
    changed_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    old_values  JSON,
    new_values  JSON,
    FOREIGN KEY (changed_by) REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- =============================================
-- 2. INDEXES
-- =============================================

CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_leads_status     ON leads(status);
CREATE INDEX idx_deals_stage      ON deals(stage);
CREATE INDEX idx_tasks_due_date   ON tasks(due_date);

-- =============================================
-- 3. SAMPLE DATA
-- =============================================

INSERT INTO employees (employee_id, first_name, last_name, email, phone, role, manager_id, hire_date, password_hash) VALUES
(1, 'Kamran', 'Sheikh', 'kamran.sheikh@crm.pk', '+92-300-1234567', 'admin', NULL, '2020-01-10', 'admin123'),
(2, 'Sana', 'Rizvi', 'sana.rizvi@crm.pk', '+92-321-2345678', 'manager', 1, '2020-04-15', 'manager123'),
(3, 'Bilal', 'Mahmood', 'bilal.mahmood@crm.pk', '+92-333-3456789', 'sales_rep', 2, '2021-03-01', 'bilal123'),
(4, 'Ayesha', 'Farooq', 'ayesha.farooq@crm.pk', '+92-345-4567890', 'sales_rep', 2, '2021-07-15', 'ayesha123'),
(5, 'Usman', 'Qureshi', 'usman.qureshi@crm.pk', '+92-312-5678901', 'sales_rep', 2, '2022-01-10', 'usman123'),
(6, 'Fatima', 'Butt', 'fatima.butt@crm.pk', '+92-315-6789012', 'support', 1, '2022-05-20', 'fatima123'),
(7, 'Omer', 'Naeem', 'omer.naeem@crm.pk', '+92-300-7890123', 'manager', 1, '2021-02-01', 'omer123');

INSERT INTO customers (customer_id, company_name, industry, website, annual_revenue, status, assigned_employee) VALUES
(1, 'Systems Limited', 'Technology', 'systemsltd.com', 850000000, 'active', 3),
(2, 'Engro Corporation', 'Conglomerate', 'engro.com', 1200000000, 'active', 4),
(3, 'Habib Bank Limited', 'Finance', 'hbl.com', 3200000000, 'active', 3),
(4, 'Daraz Pakistan', 'E-Commerce', 'daraz.pk', 450000000, 'active', 5),
(5, 'K-Electric', 'Energy', 'ke.com.pk', 1800000000, 'active', 4),
(6, 'Shaukat Khanum Hospital', 'Healthcare', 'shaukatkhanum.org.pk', 320000000, 'prospect', 5),
(7, 'Pak Suzuki Motors', 'Automotive', 'paksuzuki.com.pk', 980000000, 'active', 3),
(8, 'Ufone Telecom', 'Telecommunications', 'ufone.com', 760000000, 'inactive', 4),
(9, 'Ali Baba Textile Mills', 'Textile', 'alibabatextile.pk', 280000000, 'prospect', 5),
(10, 'TCS Pakistan', 'Logistics', 'tcs.com.pk', 190000000, 'active', 3);

INSERT INTO contacts (customer_id, first_name, last_name, email, phone, position, is_primary) VALUES
(1, 'Asif', 'Peer', 'asif.peer@systemsltd.com', '+92-300-1111111', 'CEO', TRUE),
(1, 'Mehwish', 'Ali', 'mehwish.ali@systemsltd.com', '+92-321-2222222', 'IT Director', FALSE),
(2, 'Ghias', 'Khan', 'ghias.khan@engro.com', '+92-333-3333333', 'President & CEO', TRUE),
(3, 'Muhammad', 'Aurangzeb', 'm.aurangzeb@hbl.com', '+92-300-4444444', 'President & CEO', TRUE),
(4, 'Ehsan', 'Saya', 'ehsan.saya@daraz.pk', '+92-321-5555555', 'CEO', TRUE),
(5, 'Moonis', 'Alvi', 'moonis.alvi@ke.com.pk', '+92-333-6666666', 'CEO', TRUE),
(6, 'Faisal', 'Sultan', 'faisal@shaukatkhanum.org.pk', '+92-345-7777777', 'CEO', TRUE),
(7, 'Hirofumi', 'Nagano', 'h.nagano@paksuzuki.com.pk', '+92-300-8888888', 'Managing Director', TRUE),
(9, 'Khalid', 'Mahmood', 'khalid@alibabatextile.pk', '+92-312-9999999', 'Owner', TRUE),
(10, 'Muhammad', 'Jamal', 'm.jamal@tcs.com.pk', '+92-315-0000000', 'COO', TRUE);

INSERT INTO products (product_id, name, category, description, price, stock_quantity) VALUES
(1, 'CRM Enterprise License', 'Software', 'Annual per-seat enterprise CRM license', 95000.00, 9999),
(2, 'Analytics Module', 'Software', 'Real-time reporting and BI dashboard', 65000.00, 9999),
(3, 'API Integration Pack', 'Software', 'REST API and third-party connectors', 45000.00, 9999),
(4, 'Onboarding Package', 'Service', '30-day dedicated onboarding support', 200000.00, 500),
(5, 'Priority Support SLA', 'Service', '24/7 priority support annual contract', 280000.00, 500),
(6, 'Data Migration Service', 'Service', 'Full historical data migration', 320000.00, 200),
(7, 'Training Workshop', 'Training', 'On-site team training per day', 145000.00, 300),
(8, 'Mobile App Add-on', 'Software', 'iOS and Android companion application', 35000.00, 9999);

INSERT INTO leads (lead_id, customer_id, assigned_to, source, status, estimated_value, expected_close, notes) VALUES
(1, 1, 3, 'referral', 'converted', 3800000, '2024-02-15', 'Systems Limited enterprise deal'),
(2, 2, 4, 'cold_call', 'converted', 5200000, '2024-03-20', 'Engro full suite'),
(3, 3, 3, 'event', 'converted', 8900000, '2024-04-10', 'HBL banking CRM'),
(4, 4, 5, 'website', 'converted', 2100000, '2024-05-05', 'Daraz integration'),
(5, 5, 4, 'referral', 'converted', 6400000, '2024-06-15', 'K-Electric CRM'),
(6, 7, 3, 'cold_call', 'converted', 3200000, '2024-07-01', 'Pak Suzuki CRM'),
(7, 6, 5, 'event', 'qualified', 1800000, '2024-09-30', 'Shaukat Khanum proposal'),
(8, 9, 5, 'website', 'contacted', 950000, '2024-10-15', 'Ali Baba Textile'),
(9, 10, 3, 'email', 'qualified', 1200000, '2024-11-30', 'TCS logistics'),
(10, 8, 4, 'social_media', 'unqualified', 500000, '2024-08-01', 'Ufone budget issue');

INSERT INTO deals (deal_id, lead_id, customer_id, closed_by, amount, stage, closed_date, notes) VALUES
(1, 1, 1, 3, 3650000, 'closed_won', '2024-02-12', '50 seats + Analytics'),
(2, 2, 2, 4, 5100000, 'closed_won', '2024-03-18', '80 seats full suite'),
(3, 3, 3, 3, 8750000, 'closed_won', '2024-04-08', '120 seats + SLA'),
(4, 4, 4, 5, 2050000, 'closed_won', '2024-05-02', '30 seats + API'),
(5, 5, 5, 4, 6200000, 'closed_won', '2024-06-12', '70 seats + Migration'),
(6, 6, 7, 3, 3100000, 'closed_won', '2024-06-28', '40 seats + Onboarding'),
(7, 7, 6, 5, 1800000, 'proposal', NULL, 'Awaiting approval'),
(8, 9, 10, 3, 950000, 'negotiation', NULL, 'Finalizing price');

INSERT INTO deal_products (deal_id, product_id, quantity, unit_price) VALUES
(1,1,50,90000),(1,2,1,65000),(1,4,1,200000),
(2,1,80,88000),(2,2,1,65000),(2,5,1,280000),
(3,1,120,85000),(3,5,1,280000),(3,6,1,320000),
(4,1,30,90000),(4,3,1,45000),(4,8,30,35000),
(5,1,70,88000),(5,5,1,280000),(5,6,1,320000),
(6,1,40,90000),(6,4,1,200000);

INSERT INTO interactions (customer_id, contact_id, employee_id, type, subject, notes, interaction_date) VALUES
(1,1,3,'call','Discovery call','Discussed requirements','2024-01-15 10:00:00'),
(1,2,3,'demo','Product demo','IT team impressed','2024-01-25 14:00:00'),
(2,3,4,'meeting','Executive presentation','Budget approved','2024-02-20 11:00:00');

INSERT INTO tasks (task_id, assigned_to, customer_id, deal_id, title, priority, status, due_date) VALUES
(1,3,1,1,'Send onboarding schedule','high','completed','2024-02-20'),
(7,5,6,7,'Follow up on board approval','high','in_progress','2024-09-25'),
(9,5,9,NULL,'Schedule demo for CEO','medium','pending','2024-10-20');

-- =============================================
-- 4. STORED PROCEDURES
-- =============================================

DELIMITER $$

CREATE PROCEDURE sp_convert_lead_to_deal(
    IN p_lead_id INT,
    IN p_amount DECIMAL(15,2),
    IN p_closed_by INT,
    IN p_notes TEXT,
    OUT p_deal_id INT
)
BEGIN
    DECLARE v_customer_id INT;
    DECLARE v_current_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    SELECT status INTO v_current_status FROM leads WHERE lead_id = p_lead_id;

    IF v_current_status = 'converted' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lead is already converted.';
    END IF;

    SELECT customer_id INTO v_customer_id FROM leads WHERE lead_id = p_lead_id;

    INSERT INTO deals (lead_id, customer_id, closed_by, amount, stage, closed_date, notes)
    VALUES (p_lead_id, v_customer_id, p_closed_by, p_amount, 'closed_won', CURDATE(), p_notes);

    SET p_deal_id = LAST_INSERT_ID();

    UPDATE leads SET status = 'converted', updated_at = NOW() WHERE lead_id = p_lead_id;
    UPDATE customers SET status = 'active', updated_at = NOW() WHERE customer_id = v_customer_id;

    COMMIT;
END$$

DELIMITER ;

-- =============================================
-- 5. VERIFICATION
-- =============================================

SELECT 'Employees' AS Table_Name, COUNT(*) AS Records FROM employees
UNION ALL SELECT 'Customers', COUNT(*) FROM customers
UNION ALL SELECT 'Contacts', COUNT(*) FROM contacts
UNION ALL SELECT 'Products', COUNT(*) FROM products
UNION ALL SELECT 'Leads', COUNT(*) FROM leads
UNION ALL SELECT 'Deals', COUNT(*) FROM deals;

SELECT 'Database Setup Completed Successfully!' AS Message;