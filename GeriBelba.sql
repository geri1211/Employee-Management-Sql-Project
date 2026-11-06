-- Story 1
-- Displays the details of the highest paid employee.
SELECT e.first_name, 
	   e.last_name,
       e.salary,
       e.job_id,
       d.department_name,
       l.city,
       c.country_name
FROM employees e
INNER JOIN departments d 
ON e.department_id = d.department_id
INNER JOIN locations l 
ON d.location_id = l.location_id
INNER JOIN countries c 
ON l.country_id = c.country_id
WHERE e.salary = (SELECT MAX(salary)
				  FROM employees
                  );
                  
-- Story 2
-- Displays employees that appear as a consultant.
SELECT first_name, 
       last_name, 
       job_id, 
       salary, 
       manager_id
FROM employees
WHERE job_id IN (SELECT job_id
				 FROM consultants
                 )
ORDER BY last_name;

-- Story 3
-- LEFT OUTER JOIN ensures customers with no sales are included.
-- IFNULL and NULLIF prevent NULL values and division by zero.
-- Shows zero for customers without sales.
SELECT c.cust_id,
	   c.cust_fname,
       c.cust_lname,
       c.cust_city,
       IFNULL(MAX(s.sales_amt), 0) AS largest_sale,
       IFNULL(SUM(s.sales_amt), 0) AS total_sales,
       ROUND(IFNULL(MAX(s.sales_amt) / NULLIF(SUM(s.sales_amt), 0),0) * 100,2) AS largest_sale_percentage,
       IFNULL(ROUND(AVG(s.sales_amt), 2), 0) AS average_sale,
       COUNT(s.sales_id) AS sales_count
FROM customers c
LEFT OUTER JOIN sales s 
ON c.cust_id = s.sales_cust_id
GROUP BY c.cust_id , c.cust_fname , c.cust_lname , c.cust_city
ORDER BY c.cust_id;

-- Story 4
-- Displays managers who manage entire departments.
SELECT e.first_name,
	   e.last_name,
       d.department_name,
       l.street_address,
       l.city,
       l.state_province
FROM employees e
INNER JOIN departments d 
ON e.employee_id = d.manager_id
INNER JOIN locations l 
ON d.location_id = l.location_id
ORDER BY d.department_id;

-- Story 5
-- Displays employees who earn the same or more salary as their manager.
SELECT e.first_name AS employee_first_name,
	   e.last_name AS employee_last_name,
       e.job_id AS employee_job_id,
       e.salary AS employee_salary,
       m.first_name AS manager_first_name,
       m.last_name AS manager_last_name,
       m.job_id AS manager_job_id,
       m.salary AS manager_salary
FROM employees e
INNER JOIN employees m
ON e.manager_id = m.employee_id
WHERE e.salary > m.salary;

-- Story 6
-- Returns employees whose current job appears in their job history.
SELECT e.employee_id, 
	   e.first_name, 
       e.last_name, 
       e.job_id, 
       e.salary
FROM employees e
INNER JOIN job_history jh
ON e.employee_id = jh.employee_id
WHERE e.job_id = jh.job_id;

-- Story 7 
-- Excludes managers, then compares salary against the lowest-paid manager.
SELECT e.first_name, 
	   e.last_name, 
       e.job_id, 
       e.salary
FROM employees e
WHERE e.employee_id NOT IN (SELECT DISTINCT manager_id
						    FROM employees
                            WHERE manager_id IS NOT NULL)
AND e.salary > (SELECT MIN(salary)
			    FROM employees
                WHERE employee_id IN (SELECT DISTINCT manager_id
									  FROM employees
                                      WHERE manager_id IS NOT NULL)
				)
ORDER BY e.salary;

-- Story 8
-- LEFT OUTER JOIN chain ensures regions with zero employees are still shown.
SELECT r.region_name, 
	   COUNT(e.employee_id) AS employee_count
FROM regions r
LEFT OUTER JOIN countries c 
ON r.region_id = c.region_id
LEFT OUTER JOIN locations l 
ON l.country_id = c.country_id
LEFT OUTER JOIN departments d 
ON l.location_id = d.location_id
LEFT OUTER JOIN employees e 
ON d.department_id = e.department_id
GROUP BY r.region_name
ORDER BY r.region_name;

-- Story 9 
-- a) i
-- CTE to get the department(s) where Sales Representatives work.
-- Update a specific employee’s name and move them into a Sales Rep department.
START TRANSACTION;
SET SQL_SAFE_UPDATES = 0;
WITH sales_rep_dept AS (SELECT DISTINCT department_id
					    FROM employees
                        WHERE job_id LIKE 'SA_REP%'
                        )
UPDATE employees e
INNER JOIN sales_rep_dept d
SET e.first_name = 'Kimberly',
    e.department_id = d.department_id
WHERE e.first_name = 'Kimberely'
AND e.last_name = 'Grant';
SET SQL_SAFE_UPDATES = 1;

-- a) ii 
-- Sets salary of Weiss and Fripp to match the salary of consultant Taylor.
SET SQL_SAFE_UPDATES = 0;
UPDATE employees 
SET salary = (SELECT salary
              FROM consultants
              WHERE last_name = 'Taylor')
WHERE last_name = 'Weiss'
OR last_name = 'Fripp';
SET SQL_SAFE_UPDATES = 1;

-- a) iii
-- Map old region names to new ones using a CTE.
SET SQL_SAFE_UPDATES = 0;
WITH region_map AS (SELECT 'Americas' AS old_name, 'North America' AS new_name 
                   UNION ALL 
                   SELECT 'Middle East and Africa', 'Middle East')
UPDATE regions r
INNER JOIN region_map rm
ON r.region_name = rm.old_name 
SET r.region_name = rm.new_name;
SET SQL_SAFE_UPDATES = 1;

-- b)
-- Delete consultants who also exist as employees (matched by email).
SET SQL_SAFE_UPDATES = 0;
DELETE c
FROM consultants c
INNER JOIN employees e
ON c.email = e.email;
SET SQL_SAFE_UPDATES = 1;

-- c)
-- Inserts two new regions using the next available region_id.
INSERT INTO regions (region_id, region_name) 
SELECT MAX(region_id) + 1, 'South America' 
FROM regions; INSERT INTO regions (region_id, region_name) 
SELECT MAX(region_id) + 1, 'Africa' 
FROM regions;
COMMIT;

-- Bonus Story 1
-- Correlated subquery ensures the largest sale is selected per sales rep.
SELECT s.sales_rep_id,
	   e.first_name,
       e.last_name,
       s.sales_amt AS largest_sale_amt,
       s.sales_cust_id,
       c.cust_lname
FROM sales s
INNER JOIN customers c 
ON s.sales_cust_id = c.cust_id
INNER JOIN employees e 
ON s.sales_rep_id = e.employee_id
WHERE s.sales_amt = (SELECT MAX(s2.sales_amt)
					 FROM sales s2
                     WHERE s2.sales_rep_id = s.sales_rep_id)
ORDER BY s.sales_rep_id;

-- Bonus Story 2
-- First CTE calculates total pay per sales employee.
-- Second CTE calculates the average total pay.
-- Final query returns only employees earning above average.
WITH sales_pay AS (SELECT e.employee_id,
				          e.first_name,
                          e.last_name,
                          ROUND(e.salary + e.commission_pct * SUM(s.sales_amt), 2) AS total_pay
				   FROM employees e
				   INNER JOIN sales s
				   ON e.employee_id = s.sales_rep_id
				   WHERE e.commission_pct IS NOT NULL
			       GROUP BY e.employee_id, e.first_name, e.last_name, e.salary, e.commission_pct
                   ),
avg_pay AS (SELECT AVG(total_pay) AS avg_total_pay
		    FROM sales_pay
            )
SELECT sp.first_name,
       sp.last_name,
       sp.total_pay
FROM sales_pay sp
CROSS JOIN avg_pay ap
WHERE sp.total_pay > ap.avg_total_pay
ORDER BY sp.total_pay;

-- Bonus Story 3
-- Calculates each sales manager’s total compensation by adding their salary to the commission earned from the total sales of their sales representatives.
SELECT m.employee_id, 
       m.last_name,
       ROUND(m.salary  + m.commission_pct * SUM(s.sales_amt), 2) AS total_compansation
FROM employees m
INNER JOIN employees e 
ON e.manager_id = m.employee_id
INNER JOIN sales s 
ON s.sales_rep_id = e.employee_id
WHERE m.commission_pct IS NOT NULL
GROUP BY m.employee_id, m.last_name, m.salary, m.commission_pct
ORDER BY m.employee_id;

-- Bonus Story 4
-- Correlated subquery returns the largest sale per customer.
SELECT sr.last_name AS sales_rep_last_name,
	   m.last_name AS manager_last_name,
       c.cust_fname AS customer_first_name,
       c.cust_lname AS customer_last_name,
       c.cust_city,
       c.cust_country,
       s.sales_amt AS largest_sale
FROM sales s
INNER JOIN customers c 
ON s.sales_cust_id = c.cust_id
INNER JOIN employees sr 
ON s.sales_rep_id = sr.employee_id
INNER JOIN employees m 
ON sr.manager_id = m.employee_id
WHERE s.sales_amt = (SELECT MAX(s2.sales_amt)
					 FROM sales s2
                     WHERE s2.sales_cust_id = c.cust_id)
ORDER BY sr.last_name;