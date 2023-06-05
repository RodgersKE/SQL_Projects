---------------------------------
-- CASE STUDY #1: DANNY'S DINER
---------------------------------

/* 	
INTRODUCTION

Danny seriously loves Japanese food so in the beginning of 2021, he decides to embark upon a risky venture and opens up a 
cute little restaurant that sells his 3 favourite foods: sushi, curry and ramen.

Danny’s Diner is in need of your assistance to help the restaurant stay afloat - the restaurant has captured some very basic 
data from their few months of operation but have no idea how to use their data to help them run the business.

PROBLEM STATEMENT

Danny wants to use the data to answer a few simple questions about his customers, especially about their visiting patterns, 
how much money they’ve spent and also which menu items are their favourite. Having this deeper connection with his customers 
will help him deliver a better and more personalised experience for his loyal customers.

He plans on using these insights to help him decide whether he should expand the existing customer loyalty program - additionally 
he needs help to generate some basic datasets so his team can easily inspect the data without needing to use SQL.

Danny has provided you with a sample of his overall customer data due to privacy issues - but he hopes that these examples are 
enough for you to write fully functioning SQL queries to help him answer his questions!

Danny has shared with you 3 key datasets for this case study:

* sales
* menu
* members
	
*/
CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
   
 CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  
CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
SELECT * FROM members
SELECT * FROM menu
SELECT * FROM sales

-------------
-- Questions
-------------

-- Q1. What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(m.price) AS total_amount
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY customer_id
ORDER BY customer_id;

-- Q2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT order_date) AS days
FROM sales
GROUP BY customer_id

-- Q3. What was the first item from the menu purchased by each customer?

SELECT customer_id, order_date, product_name
FROM (
	SELECT 	customer_id, 
			order_date,
			product_id,
			ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS rn
	FROM sales 
) AS s
JOIN menu m ON s.product_id = m.product_id
WHERE s.rn = 1
ORDER BY customer_id,order_date;

-- Q4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT m.product_name, COUNT(s.product_id) AS num_purchases
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY num_purchases DESC
LIMIT 1;

-- Q5. Which item was the most popular for each customer?

SELECT customer_id, product_name
FROM (
		SELECT 	customer_id,
				product_name,
				num_purchases,
				RANK() OVER(PARTITION BY customer_id ORDER BY num_purchases DESC) AS rank
		FROM  	(
					SELECT s.customer_id, m.product_name, COUNT(s.product_id) AS num_purchases
					FROM sales s
					JOIN menu m
					ON s.product_id = m.product_id
					GROUP BY s.customer_id, m.product_name
				) AS qty
	) AS ranked
WHERE rank = 1
		
-- Q6. Which item was purchased first by the customer after they became a member?	
			
SELECT 	customer_id,
		product_name
FROM ( 
SELECT 	m.customer_id, 
		mu.product_name,
		s.order_date,
		ROW_NUMBER() OVER(PARTITION BY m.customer_id ORDER BY s.order_date) AS rn
FROM members m
JOIN sales s
USING(customer_id)
JOIN menu mu USING(product_id)
WHERE s.order_date > m.join_date
	) AS o
WHERE rn = 1

-- Q7. Which item was purchased just before the customer became a member?

SELECT 	customer_id, 
		product_name
FROM (
SELECT 	m.customer_id, 
		mu.product_name,
		s.order_date,
		DENSE_RANK() OVER(PARTITION BY m.customer_id ORDER BY s.order_date DESC) AS rn
FROM members m
JOIN sales s
USING(customer_id)
JOIN menu mu USING(product_id)
WHERE s.order_date < m.join_date
	) AS o
WHERE rn = 1
	
-- Q8. What is the total items and amount spent for each member before they became a member?

SELECT 	m.customer_id, 
		COUNT(s.product_id) AS total_items,
		SUM(mu.price) AS amount_spent
FROM members m
JOIN sales s
USING(customer_id)
JOIN menu mu USING(product_id)
WHERE s.order_date < m.join_date
GROUP BY m.customer_id
ORDER by m.customer_id

-- Q9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

-- create points column in menu table
ALTER TABLE menu
ADD COLUMN points INTEGER;

-- populate points column based on points allocation criteria
UPDATE menu
SET points = 
	CASE 
		WHEN product_name = 'sushi' THEN price * 20
		WHEN product_name IN ('curry','ramen') THEN price * 10
		ELSE 0
	END;

-- find total number of points per customer. The assumption is only members get points.
SELECT s.customer_id, SUM(mu.points) AS total_points
FROM members m
JOIN sales s USING(customer_id)
JOIN menu mu USING(product_id)
WHERE s.order_date >= m.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

/* Q10. In the first week after a customer joins the program (including their join date) 
they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January? */

WITH cte AS (
	SELECT 	s.customer_id, 
			mu.product_name,
			mu.points + 2 AS points,
			DATE_TRUNC('month' ,s.order_date)::DATE AS order_date
	FROM members m
	JOIN sales s USING(customer_id)
	JOIN menu mu USING(product_id)
	WHERE s.order_date >= m.join_date 
		AND DATE_TRUNC('month' ,s.order_date)::DATE = '2021-01-01'
)
SELECT customer_id, SUM(points) AS total_points
FROM cte
GROUP BY customer_id
ORDER BY customer_id;

/* Q11. Join All Things
The following questions are related creating basic data tables that Danny and his team can use 
to quickly derive insights without needing to join the underlying tables using SQL.

Recreate the following table output using the available data:

customer_id	order_date	product_name	price	member
A			2021-01-01	curry			15		N
A			2021-01-01	sushi			10		N
A			2021-01-07	curry			15		Y
A			2021-01-10	ramen			12		Y
A			2021-01-11	ramen			12		Y
A			2021-01-11	ramen			12		Y
B			2021-01-01	curry			15		N
B			2021-01-02	curry			15		N
B			2021-01-04	sushi			10		N
B			2021-01-11	sushi			10		Y
B			2021-01-16	ramen			12		Y
B			2021-02-01	ramen			12		Y
C			2021-01-01	ramen			12		N
C			2021-01-01	ramen			12		N
C			2021-01-07	ramen			12		N
*/

CREATE TEMPORARY TABLE diner_temp AS
	SELECT 	s.customer_id, 
		s.order_date,
		mu.product_name,
		mu.price,
		CASE 
			WHEN s.customer_id = 'A' AND s.order_date < '2021-01-07' THEN 'N'
			WHEN s.customer_id = 'A' AND s.order_date >= '2021-01-07' THEN 'Y'
			WHEN s.customer_id = 'B' AND s.order_date < '2021-01-09' THEN 'N'
			WHEN s.customer_id = 'B' AND s.order_date >= '2021-01-09' THEN 'Y'
			WHEN s.customer_id = 'C' THEN 'N'
			ELSE NULL
		END AS member
	FROM members m
	RIGHT JOIN sales s USING(customer_id)
	JOIN menu mu USING(product_id)
	ORDER BY s.customer_id, s.order_date;

/* Q12. Rank All Things
Danny also requires further information about the ranking of customer products, but he purposely 
does not need the ranking for non-member purchases so he expects null ranking values for the records when 
customers are not yet part of the loyalty program.*/

SELECT * FROM diner_temp

WITH cte AS (
SELECT 	*,
		CASE 
			WHEN member = 'Y' THEN DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date)
			ELSE NULL
		END AS ranking
FROM diner_temp
)
SELECT customer_id, order_date, product_name, price, member,
		CASE 
			WHEN ranking IS NOT NULL THEN RANK() OVER(PARTITION BY customer_id ORDER BY ranking)
			ELSE NULL
		END AS rank
FROM cte
ORDER BY customer_id, order_date;
