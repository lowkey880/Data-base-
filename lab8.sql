
CREATE TABLE departments (
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location VARCHAR(50)
);

CREATE TABLE employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(100),
    dept_id INT,
    salary DECIMAL(10,2),
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

CREATE TABLE projects (
    proj_id INT PRIMARY KEY,
    proj_name VARCHAR(100),
    budget DECIMAL(12,2),
    dept_id INT,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

INSERT INTO departments VALUES
(101, 'IT', 'Building A'),
(102, 'HR', 'Building B'),
(103, 'Operations', 'Building C');

INSERT INTO employees VALUES
(1, 'John Smith', 101, 50000),
(2, 'Jane Doe', 101, 55000),
(3, 'Mike Johnson', 102, 48000),
(4, 'Sarah Williams', 102, 52000),
(5, 'Tom Brown', 103, 60000);

INSERT INTO projects VALUES
(201, 'Website Redesign', 75000, 101),
(202, 'Database Migration', 120000, 101),
(203, 'HR System Upgrade', 50000, 102);



-- Part 2: Basic Indexes

-- Q2.1: How many indexes exist on employees after creating emp_salary_idx?
-- A2.1: Two — the default primary key index and emp_salary_idx.

CREATE INDEX emp_salary_idx ON employees(salary);

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'employees';

-- Q2.2: Why is it beneficial to index foreign key columns?
-- A2.2: It speeds up JOINs, WHERE filtering, and referential integrity checks.

CREATE INDEX emp_dept_idx ON employees(dept_id);

SELECT * FROM employees WHERE dept_id = 101;

-- Q2.3: Which indexes were created automatically?
-- A2.3: Primary key indexes and unique constraint indexes.

SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;



-- Part 3: Multicolumn Indexes

-- Q3.1: Is (dept_id, salary) useful for queries only by salary?
-- A3.1: No. B-tree multicolumn indexes follow "leftmost prefix" and require dept_id.

CREATE INDEX emp_dept_salary_idx ON employees(dept_id, salary);

SELECT emp_name, salary
FROM employees
WHERE dept_id = 101 AND salary > 52000;

-- Q3.2: Does the order of columns matter?
-- A3.2: Yes. Index order defines which filters can use the index efficiently.

CREATE INDEX emp_salary_dept_idx ON employees(salary, dept_id);

SELECT * FROM employees
WHERE dept_id = 102 AND salary > 50000;

SELECT * FROM employees
WHERE salary > 50000 AND dept_id = 102;



-- Part 4: Unique Indexes

ALTER TABLE employees ADD COLUMN email VARCHAR(100);

UPDATE employees SET email = 'john.smith@company.com'  WHERE emp_id = 1;
UPDATE employees SET email = 'jane.doe@company.com'    WHERE emp_id = 2;
UPDATE employees SET email = 'mike.johnson@company.com' WHERE emp_id = 3;
UPDATE employees SET email = 'sarah.williams@company.com' WHERE emp_id = 4;
UPDATE employees SET email = 'tom.brown@company.com'   WHERE emp_id = 5;

CREATE UNIQUE INDEX emp_email_unique_idx ON employees(email);

-- Q4.1: What error appears when inserting duplicate email?
-- A4.1: "duplicate key value violates unique constraint".

-- (run separately to see the error)
-- INSERT INTO employees VALUES (6, 'New', 101, 55000, 'john.smith@company.com');

ALTER TABLE employees ADD COLUMN phone VARCHAR(20) UNIQUE;

-- Q4.2: Did PostgreSQL automatically create an index for phone?
-- A4.2: Yes. PostgreSQL creates a UNIQUE B-tree index automatically.

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'employees' AND indexname LIKE '%phone%';



-- Part 5: Indexes and Sorting

-- Q5.1: How does emp_salary_desc_idx help ORDER BY salary DESC?
-- A5.1: It lets PostgreSQL read rows in sorted order via Index Scan, avoiding sorting.

CREATE INDEX emp_salary_desc_idx ON employees(salary DESC);

SELECT emp_name, salary
FROM employees
ORDER BY salary DESC;

CREATE INDEX proj_budget_nulls_first_idx
ON projects(budget NULLS FIRST);

SELECT proj_name, budget
FROM projects
ORDER BY budget NULLS FIRST;



-- Part 6: Expression / Function-Based Indexes

-- Q6.1: Without this index, how would PostgreSQL search?
-- A6.1: It would do a full table scan applying LOWER() to every row.

CREATE INDEX emp_name_lower_idx ON employees(LOWER(emp_name));

SELECT * FROM employees
WHERE LOWER(emp_name) = 'john smith';

ALTER TABLE employees ADD COLUMN hire_date DATE;

UPDATE employees SET hire_date = '2020-01-15' WHERE emp_id = 1;
UPDATE employees SET hire_date = '2019-06-20' WHERE emp_id = 2;
UPDATE employees SET hire_date = '2021-03-10' WHERE emp_id = 3;
UPDATE employees SET hire_date = '2020-11-05' WHERE emp_id = 4;
UPDATE employees SET hire_date = '2018-08-25' WHERE emp_id = 5;

CREATE INDEX emp_hire_year_idx
ON employees(EXTRACT(YEAR FROM hire_date));

SELECT emp_name, hire_date
FROM employees
WHERE EXTRACT(YEAR FROM hire_date) = 2020;



-- Part 7: Managing Indexes

ALTER INDEX emp_salary_idx RENAME TO employees_salary_index;

SELECT indexname
FROM pg_indexes
WHERE tablename = 'employees';

-- Q7.2: Why drop an index?
-- A7.2: If it’s unused, duplicated, or slows down INSERT/UPDATE/DELETE.

DROP INDEX emp_salary_dept_idx;

REINDEX INDEX employees_salary_index;



-- Part 8: Practical Scenarios

CREATE INDEX emp_salary_filter_idx
ON employees(salary)
WHERE salary > 50000;

SELECT e.emp_name, e.salary, d.dept_name
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > 50000
ORDER BY e.salary DESC;

CREATE INDEX proj_high_budget_idx
ON projects(budget)
WHERE budget > 80000;

SELECT proj_name, budget
FROM projects
WHERE budget > 80000;

-- Q8.3: What does Index Scan vs Seq Scan mean?
-- A8.3: Index Scan = using index; Seq Scan = scanning entire table.

EXPLAIN SELECT * FROM employees WHERE salary > 52000;



-- Part 9: Index Types Comparison

CREATE INDEX dept_name_hash_idx
ON departments USING HASH (dept_name);

SELECT * FROM departments WHERE dept_name = 'IT';

CREATE INDEX proj_name_btree_idx ON projects(proj_name);

CREATE INDEX proj_name_hash_idx
ON projects USING HASH (proj_name);

SELECT * FROM projects
WHERE proj_name = 'Website Redesign';

SELECT * FROM projects
WHERE proj_name > 'Database';

-- Q9.1: When use HASH instead of B-tree?
-- A9.1: For equality-only searches on high-cardinality columns.



-- Part 10: Cleanup & Documentation

SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Q10.1: Which index is the largest? Why?
-- A10.1: Usually the one on the largest table with highest-cardinality column.

DROP INDEX IF EXISTS proj_name_hash_idx;

CREATE OR REPLACE VIEW index_documentation AS
SELECT
    tablename,
    indexname,
    indexdef,
    'Improves salary-based queries' AS purpose
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE '%salary%';

SELECT * FROM index_documentation;



--Summary Questions

-- Q1: Default index type in PostgreSQL?
-- A1: B-tree.

-- Q2: When should you create an index?
-- A2: Frequent WHERE filters, JOINs, ORDER BY/GROUP BY usage.

-- Q3: When NOT to create an index?
-- A3: Small table, low-cardinality column, or rarely-used column with many updates.

-- Q4: What happens to indexes after INSERT/UPDATE/DELETE?
-- A4: PostgreSQL updates index entries — so writes become slower.

-- Q5: How to check if a query uses an index?
-- A5: Use EXPLAIN or EXPLAIN ANALYZE (look for Index Scan).