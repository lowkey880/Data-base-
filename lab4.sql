
CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(100),
    budget NUMERIC(12,2),
    start_date DATE,
    end_date DATE,
    status VARCHAR(20)
);

CREATE TABLE assignments (
    assignment_id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(employee_id),
    project_id INTEGER REFERENCES projects(project_id),
    hours_worked NUMERIC(5,1),
    assignment_date DATE
);

INSERT INTO employees (first_name, last_name, department, salary, hire_date, manager_id, email) VALUES
('John', 'Smith', 'IT', 75000, '2020-01-15', NULL, 'john.smith@company.com'),
('Sarah', 'Johnson', 'IT', 65000, '2020-03-20', 1, 'sarah.j@company.com'),
('Michael', 'Brown', 'Sales', 55000, '2019-06-10', NULL, 'mbrown@company.com'),
('Emily', 'Davis', 'HR', 60000, '2021-02-01', NULL, 'emily.davis@company.com'),
('Robert', 'Wilson', 'IT', 70000, '2020-08-15', 1, NULL),
('Lisa', 'Anderson', 'Sales', 58000, '2021-05-20', 3, 'lisa.a@company.com');


INSERT INTO projects (project_name, budget, start_date, end_date, status) VALUES
('Website Redesign', 150000, '2024-01-01', '2024-06-30', 'Active'),
('CRM Implementation', 200000, '2024-02-15', '2024-12-31', 'Active'),
('Marketing Campaign', 80000, '2024-03-01', '2024-05-31', 'Completed'),
('Database Migration', 120000, '2024-01-10', NULL, 'Active');


INSERT INTO assignments (employee_id, project_id, hours_worked, assignment_date) VALUES
(1, 1, 120.5, '2024-01-15'),
(2, 1, 95.0, '2024-01-20'),
(1, 4, 80.0, '2024-02-01'),
(3, 3, 60.0, '2024-03-05'),
(5, 2, 110.0, '2024-02-20'),
(6, 3, 75.5, '2024-03-10');

SELECT first_name || ' ' || last_name AS full_name, department, salary
FROM employees;

SELECT Distinct employees.department
FROM employees;

SELECT projects.project_id, projects.budget,
       CASE
           WHEN projects.budget > 150000 THEN 'Large'
           WHEN projects.budget BETWEEN 100000 AND 150000 THEN 'Meduim'
           ELSE 'SMALL'
        END AS budget_category
FROM projects;

SELECT employees.first_name || ' ' || employees.last_name AS employee_name,
       COALESCE(email, 'No email provided') AS email
FROM employees;

SELECT employees.first_name, employees.last_name
FROM employees
WHERE hire_date > '2020-01-01';

SELECT employees.first_name, employees.last_name
FROM employees
WHERE salary BETWEEN 60000 AND 70000;

SELECT employees.first_name, employees.last_name
FROM employees
WHERE last_name LIKE 'S%' OR last_name LIKE '%J';

SELECT employees.first_name, employees.last_name
FROM employees
WHERE manager_id IS NOT NULL AND department = 'IT';

SELECT UPPER(employees.first_name || ' ' || employees.last_name) AS employee_name_uppercase,
       LENGTH(last_name) AS loflastname,
       SUBSTRING(email FROM 1 FOR 3) AS emailsubstr
FROM employees;

SELECT employees.first_name || ' ' || employees.last_name AS full_name,
       salary * 12 AS annual,
       ROUND(salary, 2) AS month,
       salary * 0.10 AS raise
FROM employees;

SELECT FORMAT('Project: %s - Budget: $%s - Status: %s', project_name, budget, status) AS project_info
FROM projects;

SELECT first_name || ' ' || last_name AS employee_name,
       EXTRACT(YEAR FROM AGE(hire_date)) AS years_with_company
FROM employees;

SELECT p.project_name, SUM(a.hours_worked) AS total_hours
FROM projects p
JOIN assignments a ON p.project_id = a.project_id
GROUP BY p.project_name;

SELECT projects.project_name, SUM(assignments.hours_worked) AS total_hours
FROM projects
JOIN assignments ON projects.project_id = assignments.project_id
GROUP BY project_name;

SELECT employees.department, COUNT(employees.employee_id)
FROM employees
GROUP BY department
HAVING COUNT(employee_id) > 1;

SELECT MAX(employees.salary) AS maxi, MIN(employees.salary) AS mini, SUM(employees.salary) AS total
FROM employees;

SELECT employees.employee_id, employees.first_name || ' ' || employees.last_name AS full_name, employees.salary
FROM employees
WHERE salary > 65000
UNION
SELECT employees.employee_id, employees.first_name || ' ' || employees.last_name AS full_name, employees.salary
FROM employees
WHERE hire_date > '2020-01-01';

SELECT employees.employee_id, employees.first_name || ' ' || employees.last_name AS full_name, employees.salary
FROM employees
WHERE department = 'IT'
INTERSECT
SELECT employees.employee_id, employees.first_name || ' ' || employees.last_name AS full_name, employees.salary
FROM employees
WHERE salary > 65000;

SELECT employees.first_name || ' ' || employees.last_name AS full_name
FROM employees
WHERE employee_id NOT IN (SELECT DISTINCT employee_id FROM assignments)

SELECT employees.employee_id,
       employees.first_name,
       employees.last_name
FROM employees
WHERE EXISTS (
    SELECT *
    FROM assignments
    WHERE assignments.employee_id = employees.employee_id
);

SELECT employees.employee_id,
       employees.first_name,
       employees.last_name
FROM employees
WHERE employees.employee_id IN (
    SELECT assignments.employee_id
    FROM assignments
    INNER JOIN projects
    ON assignments.project_id = projects.project_id
    WHERE projects.status = 'Active'
);

SELECT employees.employee_id,
       employees.first_name,
       employees.last_name,
       employees.salary
FROM employees
WHERE salary > ANY(
    SELECT salary
    FROM employees
    WHERE department = 'SALES'
    );


SELECT first_name || ' ' || last_name AS employee_name,
       department,
       AVG(a.hours_worked) AS average_hours_worked,
       RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS salary_rank
FROM employees e
JOIN assignments a ON e.employee_id = a.employee_id
GROUP BY e.employee_id, department;


SELECT p.project_name, SUM(a.hours_worked) AS total_hours, COUNT(DISTINCT a.employee_id) AS num_employees
FROM projects p
JOIN assignments a ON p.project_id = a.project_id
GROUP BY p.project_name
HAVING SUM(a.hours_worked) > 150;


SELECT department, COUNT(employee_id) AS total_employees,
       AVG(salary) AS average_salary,
       MAX(salary) AS highest_paid_employee
FROM employees
GROUP BY department;
