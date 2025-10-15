Kanshin Arseniy 24BO81833
CREATE TABLE employees (
    employee_id INTEGER,
    first_name TEXT,
    last_name TEXT,
    age INTEGER CHECK(age between 18 and 65),
    salary NUMERIC CHECK(salary > 0)
);

INSERT INTO employees VALUES (1, 'Jonh', 'Smith', 30, 2500);
INSERT INTO employees VALUES (2, 'Anna', 'Brown', 45, 4000);

-- Invalid inserts (EXPECTED ERROR):
-- INSERT INTO employees VALUES (3, 'Mike', 'Young', 16, 2000);  -- age < 18 → violates CHECK (age)
-- INSERT INTO employees VALUES (4, 'Tom', 'Lee', 28, -1000);

CREATE TABLE products_catalog(
    product_id INTEGER,
    product_name TEXT,
    regular_price NUMERIC,
    discount_price NUMERIC,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0
        AND discount_price > 0
        AND discount_price < regular_price
        )
);

INSERT INTO products_catalog VALUES(1, 'Laptop', 1000, 800);
INSERT INTO products_catalog VALUES (2, 'Phone', 700, 600);

-- Invalid inserts (EXPECTED ERROR):
-- INSERT INTO products_catalog VALUES (3, 'Tablet', 500, 600); -- discount >= regular → violates valid_discount
-- INSERT INTO products_catalog VALUES (4, 'Mouse', 0, 0);
DROP TABLE bookings;
CREATE TABLE bookings(
    booking_id  INTEGER,
    check_in_date DATE,
    check_out_date DATE,
    num_guests INTEGER CHECK(num_guests BETWEEN 1 AND 10),
    CHECK(check_out_date > check_in_date)
);


INSERT INTO bookings VALUES (1, DATE '2025-10-10', DATE '2025-10-15', 2);
INSERT INTO bookings VALUES (2, DATE '2025-12-01', DATE '2025-12-05', 5);

-- Invalid inserts (EXPECTED ERROR):
-- INSERT INTO bookings VALUES (3, DATE '2025-10-15', DATE '2025-10-10', 2); -- out < in → violates CHECK (dates)
-- INSERT INTO bookings VALUES (4, DATE '2025-10-20', DATE '2025-10-22', 15); -- guests > 10 → violates CHECK (num_guests)

CREATE TABLE customers (
    customer_id        INTEGER NOT NULL,
    email              TEXT NOT NULL,
    phone              TEXT,
    registration_date  DATE NOT NULL
);

CREATE TABLE inventory (
    item_id      INTEGER NOT NULL,
    item_name    TEXT    NOT NULL,
    quantity     INTEGER NOT NULL CHECK (quantity >= 0),
    unit_price   NUMERIC NOT NULL CHECK (unit_price > 0),
    last_updated TIMESTAMP NOT NULL
);

INSERT INTO customers VALUES (1, 'a@example.com', NULL, DATE '2025-10-01');  -- phone NULL допустим
INSERT INTO customers VALUES (2, 'b@example.com', '+77001234567', DATE '2025-10-10');

INSERT INTO inventory VALUES (100, 'SSD 1TB', 10, 129.99, NOW());
INSERT INTO inventory VALUES (101, 'RAM 16GB', 25, 55.50, NOW());

--INSERT INTO customers VALUES (2, NULL, '87017776655', '2025-10-15');
--INSERT INTO inventory VALUES (2, 'Phone', 5, NULL, '2025-10-15 11:00:00');


CREATE TABLE users (
    user_id    INTEGER,
    username   TEXT UNIQUE,
    email      TEXT UNIQUE,
    created_at TIMESTAMP
);

CREATE TABLE course_enrollments(
    enrollment_id INTEGER,
    student_id INTEGER,
    course_code TEXT,
    semester TEXT,
    CONSTRAINT uq_student UNIQUE (student_id, course_code, semester)
);

ALTER TABLE users
    ADD CONSTRAINT unique_username UNIQUE(username);

ALTER TABLE users
    ADD CONSTRAINT unique_email UNIQUE(email);


INSERT INTO users VALUES (1, 'alice', 'alice@example.com', NOW());
INSERT INTO users VALUES (2, 'bob',   'bob@example.com',   NOW());

-- Invalid inserts (EXPECTED ERROR):
-- INSERT INTO users VALUES (3, 'alice', 'alice2@example.com', NOW());
-- INSERT INTO users VALUES (4, 'charlie', 'bob@example.com', NOW());

CREATE TABLE departments (
    dept_id   INTEGER PRIMARY KEY,
    dept_name TEXT NOT NULL,
    location  TEXT
);

INSERT INTO departments VALUES (10, 'Sales',    'Astana');
INSERT INTO departments VALUES (20, 'Finance',  'Almaty');
INSERT INTO departments VALUES (30, 'HR',       'Shymkent');

CREATE TABLE student_courses (
    student_id       INTEGER,
    course_id        INTEGER,
    enrollment_date  DATE,
    grade            TEXT,
    PRIMARY KEY (student_id, course_id)
);

INSERT INTO student_courses VALUES (1001, 1, DATE '2025-09-01', 'A');
INSERT INTO student_courses VALUES (1001, 2, DATE '2025-09-01', 'B');

-- Invalid (EXPECTED ERROR):
-- INSERT INTO student_courses VALUES (1001, 1, DATE '2025-09-15', 'A');

CREATE TABLE employees_dept (
    emp_id    INTEGER PRIMARY KEY,
    emp_name  TEXT NOT NULL,
    dept_id   INTEGER REFERENCES departments(dept_id),
    hire_date DATE
);

INSERT INTO employees_dept VALUES (1, 'Ivan Petrov', 10, DATE '2025-01-10');
INSERT INTO employees_dept VALUES (2, 'Sara Kim',    20, DATE '2025-02-15');

-- Invalid (EXPECTED ERROR):
-- INSERT INTO employees_dept VALUES (3, 'No Dept', 999, DATE '2025-03-01');

CREATE TABLE authors (
    author_id   INTEGER PRIMARY KEY,
    author_name TEXT NOT NULL,
    country     TEXT
);

CREATE TABLE publishers (
    publisher_id   INTEGER PRIMARY KEY,
    publisher_name TEXT NOT NULL,
    city           TEXT
);

CREATE TABLE books (
    book_id         INTEGER PRIMARY KEY,
    title           TEXT NOT NULL,
    author_id       INTEGER REFERENCES authors(author_id),
    publisher_id    INTEGER REFERENCES publishers(publisher_id),
    publication_year INTEGER,
    isbn            TEXT UNIQUE
);

INSERT INTO authors VALUES (1, 'Isaac Asimov', 'USA');
INSERT INTO authors VALUES (2, 'Arthur C. Clarke', 'UK');

INSERT INTO publishers VALUES (1, 'Penguin', 'London');
INSERT INTO publishers VALUES (2, 'HarperCollins', 'New York');

INSERT INTO books VALUES (100, 'Foundation',       1, 1, 1951, '978-0-123456-47-2');
INSERT INTO books VALUES (101, 'I, Robot',         1, 2, 1950, '978-0-123456-47-3');
INSERT INTO books VALUES (102, 'Rendezvous with Rama', 2, 1, 1973, '978-0-123456-47-4');

-- Invalid (EXPECTED ERROR):
-- INSERT INTO books VALUES (103, 'Ghost Book', 999, 1, 2000, '978-x-ghost');
-- INSERT INTO books VALUES (104, 'Dup ISBN', 1, 1, 1960, '978-0-123456-47-2');


CREATE TABLE categories (
    category_id   INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL
);

CREATE TABLE products_fk (
    product_id   INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category_id  INTEGER REFERENCES categories(category_id) ON DELETE RESTRICT

);

CREATE TABLE orders (
    order_id    INTEGER PRIMARY KEY,
    order_date  DATE NOT NULL
);

CREATE TABLE order_items (
    item_id    INTEGER PRIMARY KEY,
    order_id   INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products_fk(product_id),
    quantity   INTEGER CHECK (quantity > 0)
);


CREATE TABLE customers_ec (
    customer_id       INTEGER PRIMARY KEY,
    name              TEXT    NOT NULL,
    email             TEXT    NOT NULL UNIQUE,
    phone             TEXT,
    registration_date DATE    NOT NULL
);

CREATE TABLE products_ec (
    product_id     INTEGER PRIMARY KEY,
    name           TEXT    NOT NULL,
    description    TEXT,
    price          NUMERIC NOT NULL CHECK (price >= 0),
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE orders_ec (
    order_id     INTEGER PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES customers_ec(customer_id) ON DELETE RESTRICT,
    order_date   TIMESTAMP NOT NULL,
    total_amount NUMERIC   NOT NULL CHECK (total_amount >= 0),
    status       TEXT      NOT NULL CHECK (status IN ('pending','processing','shipped','delivered','cancelled'))

);

CREATE TABLE order_details (
    order_detail_id INTEGER PRIMARY KEY,
    order_id        INTEGER NOT NULL REFERENCES orders_ec(order_id) ON DELETE CASCADE,
    product_id      INTEGER NOT NULL REFERENCES products_ec(product_id) ON DELETE RESTRICT,
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC NOT NULL CHECK (unit_price >= 0)

);