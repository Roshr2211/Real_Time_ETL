-- Customers table with email
CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(150),           -- added email column
  created_at TIMESTAMP DEFAULT now()
);

-- Orders table remains the same
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  customer_id INT REFERENCES customers(id),
  total DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT now()
);

-- Insert data with emails
INSERT INTO customers (name, email) 
VALUES 
  ('Alice', 'alice@example.com'), 
  ('Bob', 'bob@example.com');

INSERT INTO orders (customer_id, total) 
VALUES 
  (1, 199.99), 
  (2, 59.49);
