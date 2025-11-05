CREATE TABLE employees (
  emp_id   INT PRIMARY KEY,
  emp_name VARCHAR(50),
  dept_id  INT,
  salary   DECIMAL(10,2)
);

CREATE TABLE departments (
  dept_id   INT PRIMARY KEY,
  dept_name VARCHAR(50),
  location  VARCHAR(50)
);

CREATE TABLE projects (
  project_id   INT PRIMARY KEY,
  project_name VARCHAR(50),
  dept_id      INT,
  budget       DECIMAL(10,2)
);

INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES
  (1, 'John Smith',     101, 50000),
  (2, 'Jane Doe',       102, 60000),
  (3, 'Mike Johnson',   101, 55000),
  (4, 'Sarah Williams', 103, 65000),
  (5, 'Tom Brown',      NULL, 45000);

INSERT INTO departments (dept_id, dept_name, location) VALUES
  (101, 'IT',        'Building A'),
  (102, 'HR',        'Building B'),
  (103, 'Finance',   'Building C'),
  (104, 'Marketing', 'Building D');

INSERT INTO projects (project_id, project_name, dept_id, budget) VALUES
  (1, 'Website Redesign', 101, 100000),
  (2, 'Employee Training',102,  50000),
  (3, 'Budget Analysis',  103,  75000),
  (4, 'Cloud Migration',  101, 150000),
  (5, 'AI Research',      NULL, 200000);


-- Answer: N=5 employees, M=4 departments -> 5*4 = 20 rows
SELECT employees.emp_name, departments.dept_name
FROM employees CROSS JOIN departments;

SELECT e.emp_name, d.dept_name
FROM employees e, departments d;

SELECT e.emp_name, d.dept_name
FROM employees e
INNER JOIN departments d ON TRUE;

SELECT e.emp_name, p.project_name
FROM employees e CROSS JOIN projects p
ORDER BY e.emp_name, p.project_name;

-- Answer: 4 rows
SELECT employees.emp_name, departments.dept_name, departments.location
FROM employees
INNER JOIN  departments ON employees.dept_id = departments.dept_id;

SELECT emp_name, dept_name, location
FROM employees
INNER JOIN departments USING (dept_id);

SELECT emp_name, dept_name, location
FROM employees
NATURAL INNER JOIN departments;


SELECT employees.emp_name, departments.dept_name, projects.project_name
FROM employees
INNER JOIN  departments ON employees.dept_id = departments.dept_id
INNER JOIN  projects ON departments.dept_id = projects.dept_id;


SELECT e.emp_name,
       e.dept_id AS emp_dept,
       d.dept_id AS dept_dept,
       d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id


SELECT emp_name, dept_id, dept_name
FROM employees
LEFT JOIN departments USING (dept_id)

SELECT e.emp_name, e.dept_id
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;

SELECT d.dept_name, COUNT(e.emp_id) AS employee_count
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY employee_count DESC;

SELECT employees.emp_name, departments.dept_name
FROM employees
RIGHT JOIN  departments ON employees.dept_id = departments.dept_id;

SELECT e.emp_name, d.dept_name
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
ORDER BY d.dept_name, e.emp_name;

SELECT *
FROM employees
RIGHT JOIN  departments ON employees.dept_id = departments.dept_id
WHERE emp_id IS NULL;

SELECT e.emp_name,
       e.dept_id AS emp_dept,
       d.dept_id AS dept_dept,
       d.dept_name
FROM employees e
FULL JOIN departments d ON e.dept_id = d.dept_id;


SELECT departments.dept_name, projects.project_name, projects.budget
FROM departments
FULL JOIN  projects ON departments.dept_id =  projects.dept_id;

SELECT
  CASE
    WHEN e.emp_id IS NULL THEN 'Department without employees'
    WHEN d.dept_id IS NULL THEN 'Employee without department'
    ELSE 'Matched'
  END AS record_status,
  e.emp_name,
  d.dept_name
FROM employees e
FULL JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL OR d.dept_id IS NULL;


SELECT employees.emp_name, departments.dept_name, employees.salary
FROM employees
LEFT JOIN departments ON employees.dept_id =  departments.dept_id AND location = 'Building A';

SELECT employees.emp_name, departments.dept_name, employees.salary
FROM employees
LEFT JOIN departments ON employees.dept_id = departments.dept_id
WHERE location = 'Building A';

SELECT employees.emp_name, departments.dept_name, employees.salary
FROM employees
INNER JOIN departments ON employees.dept_id =  departments.dept_id AND location = 'Building A';

SELECT employees.emp_name, departments.dept_name, employees.salary
FROM employees
INNER JOIN departments ON employees.dept_id = departments.dept_id
WHERE location = 'Building A';


SELECT
  d.dept_name,
  e.emp_name,
  e.salary,
  p.project_name,
  p.budget
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN projects  p ON d.dept_id = p.dept_id
ORDER BY d.dept_name, e.emp_name, p.project_name;


ALTER TABLE employees ADD COLUMN manager_id INT;

UPDATE employees SET manager_id = 3 WHERE emp_id IN (1,2,4,5);
UPDATE employees SET manager_id = NULL WHERE emp_id = 3;


SELECT e.emp_name AS employee,
       m.emp_name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;

SELECT d.dept_name, AVG(e.salary) AS avg_salary
FROM departments d
JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING AVG(e.salary) > 50000
ORDER BY avg_salary DESC;

SELECT 
    d.dept_name,
    d.location,
    COUNT(DISTINCT e.emp_id) AS employee_count,
    COUNT(DISTINCT p.project_id) AS project_count
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN projects p ON d.dept_id = p.dept_id
GROUP BY d.dept_id, d.dept_name, d.location
HAVING COUNT(DISTINCT e.emp_id) = 0 AND COUNT(DISTINCT p.project_id) = 0;

SELECT
  e.emp_name,
  e.salary,
  e.dept_id
FROM employees e
LEFT JOIN departments d ON d.dept_id = e.dept_id
WHERE d.dept_id IS NULL;

SELECT 
    project_name,
    budget,
    dept_id
FROM projects
WHERE dept_id IS NULL;

SELECT 
    'IT' AS dept_name,
    SUM(p.budget) AS total_budget,
    (SELECT SUM(budget) FROM projects WHERE dept_id = 10) AS current_budget,
    (SELECT budget FROM projects WHERE dept_id IS NULL) AS unassigned_project_budget
FROM projects p
WHERE p.dept_id = 10;

SELECT 
    e.emp_name,
    e.salary,
    (SELECT AVG(salary) FROM employees WHERE dept_id = 10) AS avg_it_salary,
    e.salary - (SELECT AVG(salary) FROM employees WHERE dept_id = 10) AS difference_from_average
FROM employees e
WHERE e.dept_id = 10
AND e.salary < (SELECT AVG(salary) FROM employees WHERE dept_id = 10);


SELECT 
    d.dept_name,
    COUNT(DISTINCT e.emp_id) AS employee_count,
    COUNT(DISTINCT p.project_id) AS project_count,
    COUNT(DISTINCT p.project_id) - COUNT(DISTINCT e.emp_id) AS difference
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN projects p ON d.dept_id = p.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING COUNT(DISTINCT p.project_id) > COUNT(DISTINCT e.emp_id)
AND COUNT(DISTINCT e.emp_id) > 0;

COALESCE

SELECT 
    d.dept_name,
    COALESCE(SUM(e.salary), 0) AS total_salaries,
    COALESCE(SUM(p.budget), 0) AS total_projects_budget,
    COALESCE(SUM(e.salary), 0) + COALESCE(SUM(p.budget), 0) AS grand_total
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN projects p ON d.dept_id = p.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING COALESCE(SUM(e.salary), 0) > 100000 
    OR COALESCE(SUM(p.budget), 0) > 100000
ORDER BY grand_total DESC;

SELECT 
    e.emp_name,
    ed.dept_name AS emp_dept_name,
    p.project_name,
    pd.dept_name AS project_dept_name
FROM employees e
INNER JOIN departments ed ON e.dept_id = ed.dept_id
INNER JOIN projects p ON p.dept_id IS NOT NULL
INNER JOIN departments pd ON p.dept_id = pd.dept_id
WHERE e.dept_id != p.dept_id
ORDER BY e.emp_name, p.project_name;















