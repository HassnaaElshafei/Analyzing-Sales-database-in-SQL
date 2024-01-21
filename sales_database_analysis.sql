
-- How many customers do not have DOB information available?
SELECT COUNT(cust_id) AS count_of_nulls
FROM customers
WHERE dob IS NULL;

-- How many customers are there in each pincode and gender combination?
SELECT COUNT(*) AS count_of_combination, primary_pincode,gender
FROM customers
GROUP BY  primary_pincode, gender;

-- Print product name and mrp for products which have more than 50000 MRP?
SELECT product_name, mrp
FROM products
WHERE mrp > 50000;

-- How many delivery personal are there in each pincode?
SELECT  COUNT(delivery_person_id) AS delivery_persons, pincode
FROM delivery_person
GROUP BY pincode;

-- For each Pin code, print the count of orders, sum of total amount paid, average amount
-- paid, maximum amount paid, minimum amount paid for the transactions which were
-- paid by 'cash'. Take only 'buy' order types

SELECT delivery_pincode AS pincode, COUNT(order_id) AS orders, SUM(total_amount_paid) AS sum_amount_paid,
       AVG(total_amount_paid) AS avg_amount_paid, max(total_amount_paid) AS max_amount_paid,
       min(total_amount_paid) AS min_amount_paid
FROM orders
WHERE  payment_type = 'cash' AND order_type = 'buy'
GROUP BY delivery_pincode;


-- For each delivery_person_id, print the count of orders and total amount paid for
-- product_id = 12350 or 12348 and total units > 8. Sort the output by total amount paid in
-- descending order. Take only 'buy' order types

SELECT delivery_person_id, COUNT(order_id) AS orders, total_amount_paid
FROM orders
WHERE product_id IN (12350,12348) AND tot_units > 8 AND order_type ='buy'
GROUP BY delivery_person_id
ORDER BY total_amount_paid  DESC;


-- Print the Full names (first name plus last name) for customers that have email on
-- "gmail.com"?

SELECT  first_name || ' ' || last_name AS full_name, email
FROM customers
WHERE email like '%@gmail.com';


--Which pincode has average amount paid more than 150,000? Take only 'buy' order types
SELECT delivery_pincode AS pincode, AVG(total_amount_paid) AS avg_amount_paid
FROM orders
WHERE  order_type = 'buy'
GROUP BY delivery_pincode
HAVING avg_amount_paid > 150000;


--Create following columns from order_dim data - order_date /  Order day / Order month / Order year

ALTER TABLE orders
ADD COLUMN new_order_date DATE;

UPDATE orders
SET new_order_date = date(strftime('%Y-%m-%d', substr(order_date, 7, 4) || '-' || substr(order_date, 4, 2) || '-' || substr(order_date, 1, 2)));


ALTER TABLE orders
ADD COLUMN order_day INTEGER;

ALTER TABLE orders
ADD COLUMN order_month INTEGER;

ALTER TABLE orders
ADD COLUMN order_year INTEGER;

UPDATE orders
SET order_day = CAST(strftime('%d', new_order_date) AS INTEGER);

UPDATE orders
SET order_month = CAST(strftime('%m', new_order_date) AS INTEGER);

UPDATE orders
SET order_year = CAST(strftime('%Y', new_order_date) AS INTEGER);


--How many total orders were there in each month and how many of them were returned? Add a column for return rate too.
SELECT order_month, COUNT(order_id) AS total_orders,
    COUNT(CASE WHEN order_type = 'return' THEN order_id END) AS returned_orders ,
    (100*(COUNT(CASE WHEN order_type = 'return' THEN order_id END))/COUNT(CASE WHEN order_type = 'buy' THEN order_id END)) AS return_rate
FROM orders
GROUP BY order_month;



-- How many units have been sold by each brand? Also get total returned units for each brand.
SELECT  brand, SUM(CASE WHEN order_type='buy' THEN tot_units ELSE 0 END) AS total_units_sold ,
        SUM(CASE WHEN order_type='return' THEN tot_units ELSE 0 END) AS total_units_returned
FROM products
INNER JOIN orders
USING (product_id)
GROUP BY brand;


-- How many distinct customers and delivery boys are there in each state?
SELECT pin.state, COUNT(DISTINCT c.cust_id) AS cust_count, COUNT(DISTINCT dp.delivery_person_id) AS delivery_person_count
FROM pincode AS pin
INNER JOIN delivery_person AS dp on pin.pincode = dp.pincode
INNER JOIN customers AS c  on pin.pincode = c.primary_pincode
GROUP BY pin.state;


-- For every customer, print how many total units were ordered, how many units were
-- ordered from their primary_pincode and how many were ordered not from the primary_pincode.
-- Also calulate the percentage of total units which were ordered from
-- primary_pincode. Sort by the percentage column in descending order.

SELECT c.cust_id,SUM(tot_units) AS total_units_ordered,
       SUM(CASE WHEN c.primary_pincode = o.delivery_pincode THEN tot_units ELSE 0 END) AS primary_pincode_orders,
       SUM(CASE WHEN c.primary_pincode <> o.delivery_pincode THEN tot_units ELSE 0 END) AS other_pincode_orders,
       (SUM(CASE WHEN c.primary_pincode = o.delivery_pincode THEN tot_units ELSE 0 END)*100 ) / SUM(tot_units) AS prim_pin_percentage

FROM customers  c
INNER JOIN orders o on c.cust_id = o.cust_id
GROUP BY c.cust_id
ORDER BY  prim_pin_percentage DESC;


--For each product name, print the sum of number of units, total amount paid, total
--displayed selling price, total mrp of these units, and finally the net discount from selling price.

SELECT  p.product_name,SUM(o.tot_units) AS total_units, SUM(o.total_amount_paid) AS total_amount_paid,
        SUM(o.displayed_selling_price_per_unit) AS total_dis_selling_price,
        SUM(p.mrp) AS sum_mrp,
        (100 - 100 * SUM(o.total_amount_paid) / SUM(o.displayed_selling_price_per_unit)) AS net_disc_selling_price,
        (100- 100*SUM(o.total_amount_paid)/SUM(p.mrp)) AS net_disc_mrp
FROM products p
INNER JOIN orders o on p.product_id = o.product_id
GROUP BY  p.product_name;




--For every order_id (exclude returns), get the product name and calculate the discount
--percentage from selling price. Sort by highest discount and print only those rows where
--discount percentage was above 10.10%.

SELECT order_id, product_name, discount_percentage
FROM  (SELECT o.order_id, p.product_name,
        (100.0 - 100.0 * o.total_amount_paid / o.displayed_selling_price_per_unit) AS discount_percentage
    FROM orders o
    INNER JOIN products p ON o.product_id = p.product_id
    WHERE o.order_type = 'buy') AS DiscountCalculation
WHERE discount_percentage > 10
ORDER BY discount_percentage DESC;


-- Using the per unit procurement cost in product_dim, find which product category has
-- made the most profit in both absolute amount and percentage

SELECT category, (total_amt_sold - total_procurement_cost) AS absolute_profit,
       (100 * total_amt_sold / total_procurement_cost - 100) AS percentage_profit
FROM (SELECT  p.category,
        SUM(CASE WHEN p.category = 'mouse' AND o.order_type='buy'
                THEN o.tot_units * o.displayed_selling_price_per_unit
                WHEN p.category = 'laptop' AND o.order_type='buy'
                THEN o.tot_units * o.displayed_selling_price_per_unit
                WHEN p.category = 'pendrive' AND o.order_type='buy'
                THEN o.tot_units * o.displayed_selling_price_per_unit
                ELSE 0 END) AS total_amt_sold ,
        SUM(CASE WHEN p.category = 'mouse' AND o.order_type='buy'
                 THEN o.tot_units * p.procurement_cost_per_unit
                 WHEN p.category = 'laptop' AND o.order_type='buy'
                 THEN o.tot_units * p.procurement_cost_per_unit
                 WHEN p.category = 'pendrive' AND o.order_type='buy'
                 THEN o.tot_units * p.procurement_cost_per_unit
                 ELSE 0 END) AS total_procurement_cost
FROM products p
INNER JOIN main.orders o on p.product_id = o.product_id
GROUP BY p.category) AS profit ;


-- For every delivery person(use their name), print the total number of order ids (exclude
-- returns) by month in separate columns

SELECT dp.delivery_person_id, dp.name AS delivery_person_name,
    COUNT(CASE WHEN o.order_month = 1 AND o.order_type = 'buy' THEN o.order_id END) AS january,
    COUNT(CASE WHEN o.order_month = 2 AND o.order_type = 'buy' THEN o.order_id END) AS february,
    COUNT(CASE WHEN o.order_month = 3 AND o.order_type = 'buy' THEN o.order_id END) AS march,
    COUNT(CASE WHEN o.order_month = 4 AND o.order_type = 'buy' THEN o.order_id END) AS april,
    COUNT(CASE WHEN o.order_month = 5 AND o.order_type = 'buy' THEN o.order_id END) AS may,
    COUNT(CASE WHEN o.order_month = 6 AND o.order_type = 'buy' THEN o.order_id END) AS june,
    COUNT(CASE WHEN o.order_month = 7 AND o.order_type = 'buy' THEN o.order_id END) AS july,
    COUNT(CASE WHEN o.order_month = 8 AND o.order_type = 'buy' THEN o.order_id END) AS august,
    COUNT(CASE WHEN o.order_month = 9 AND o.order_type = 'buy' THEN o.order_id END) AS septemper,
    COUNT(CASE WHEN o.order_month = 10 AND o.order_type = 'buy' THEN o.order_id END) AS october


FROM delivery_person dp
LEFT JOIN orders o ON dp.delivery_person_id = o.delivery_person_id
WHERE o.order_type = 'buy'
GROUP BY dp.delivery_person_id, dp.name
ORDER BY dp.delivery_person_id;



-- For each gender - male and female - find the absolute and percentage profit by product name

SELECT gender, (original_amount - real_amount_paid) AS absolute_profit,
       (100 * original_amount / real_amount_paid - 100) AS percentage_profit
FROM (SELECT c.gender,
       SUM(CASE WHEN c.gender = 'female' AND o.order_type = 'buy'
                THEN o.tot_units * o.displayed_selling_price_per_unit
                WHEN c.gender = 'male' AND o.order_type = 'buy'
                THEN o.tot_units * o.displayed_selling_price_per_unit
                ELSE 0 END) AS original_amount,
       SUM(CASE WHEN c.gender = 'female' AND o.order_type = 'buy'
                THEN o.total_amount_paid
                WHEN c.gender = 'male' AND o.order_type = 'buy'
                THEN o.total_amount_paid
                ELSE 0 END) AS real_amount_paid
FROM customers c
INNER JOIN main.orders o on c.cust_id = o.cust_id
GROUP BY c.gender) AS customer_profit;


-- Generally the more numbers of units you buy, the more discount seller will give you. For
-- 'Dell AX420' is there a relationship between number of units ordered and average
-- discount from selling price? Take only 'buy' order types

SELECT   o.tot_units ,
        AVG(100.0 - 100.0 * o.total_amount_paid / o.displayed_selling_price_per_unit) AS avg_discount_from_selling_price
FROM products p
INNER JOIN main.orders o on p.product_id = o.product_id
WHERE p.product_name = 'Dell AX420' AND o.order_type = 'buy'
GROUP BY o.tot_units
ORDER BY o.tot_units;
