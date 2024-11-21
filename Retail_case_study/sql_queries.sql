Use sql_project;

CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    gender VARCHAR(30),
    date_of_birth DATE,
    registration_date DATE,
    last_purchase_date DATE
);

CREATE TABLE Products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255),
    category VARCHAR(255),
    price FLOAT(3),
    stock_quantity INT,
    date_added DATE
);

CREATE TABLE Sales (
    sale_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    FOREIGN KEY (customer_id)
        REFERENCES Customers (customer_id),
    product_id INT,
    FOREIGN KEY (product_id)
        REFERENCES Products (product_id),
    quantity_sold INT,
    sale_date DATE,
    discount_applied INT,
    total_amount FLOAT(2)
);

CREATE TABLE Inventory_Movements (
    movement_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    FOREIGN KEY (product_id)
        REFERENCES Products (product_id),
    movement_type VARCHAR(5),
    quantity_moved INT,
    movement_date DATE
);

ALTER TABLE Sales
MODIFY COLUMN total_amount decimal(9,2);

ALTER TABLE Products
MODIFY COLUMN price decimal(9,2);

select * from customers;
select * from inventory_movements;
select * from products;
select * from sales;

-- Calculate the total sales amount per month, including the number of units sold and the total revenue generated.
 SELECT 
	YEAR(sale_date) as a,MONTH(sale_date) AS M, SUM(total_amount), SUM(quantity_sold)
FROM
    sales
GROUP BY YEAR(sale_date),MONTH(sale_date) with rollup;

-- This is a beautified version
with cte1 as
(
SELECT 
	YEAR(sale_date) as y,MONTH(sale_date) AS M, SUM(total_amount) c, SUM(quantity_sold) b
FROM
    sales
GROUP BY YEAR(sale_date),MONTH(sale_date) with rollup
)
select ifnull(y, 'All Year') Year, ifnull(M, 'All Month') Month, c as Total_Amount ,b as Total_Quantity from cte1;

-- Calculate the average discount applied to sales in each month and assess how discounting strategies impact total sales.

select YEAR(sale_date) as Year,MONTH(sale_date) AS Month, avg(discount_applied) Average_discount, SUM(total_amount) Total_Sales
from sales
GROUP BY YEAR(sale_date),MONTH(sale_date)
Order by Average_discount asc;

-- Which customers have spent the most on their purchases? Show their details.

SELECT 
    customers.* ,
    SUM(sales.total_amount) total
FROM
    sales
        LEFT JOIN
    customers ON sales.customer_id = customers.customer_id
GROUP BY sales.customer_id
ORDER BY total DESC
limit 5;

-- Find the details of customers born in the 1990s, including their total spending and specific order details.

SELECT 
    customers.*,
    COUNT(sales.sale_id) Total_Orders,
    SUM(sales.total_amount) Total_Spent,
    SUM(sales.quantity_sold) Total_Items_bought
FROM
    customers
        LEFT JOIN
    sales ON customers.customer_id = sales.customer_id
WHERE
    YEAR(customers.date_of_birth) >= 1990
        AND YEAR(customers.date_of_birth) < 2000
GROUP BY customers.customer_id;

-- Use SQL to create customer segments based on their total spending (e.g., Low Spenders, High Spenders).

with cte2 as (
select customer_id, sum(total_amount) a
from sales
group by customer_id
)
select customer_id, a, 
Case 
when a < (select avg(a) from cte2) then 'low'
else 'high' end spend
from cte2;

-- Write a query to find products that are running low in stock (below a threshold like 10 units) and recommend restocking amounts based on past sales performance.

SELECT 
    products.product_id,
    products.stock_quantity,
    SUM(quantity_sold) sold_quantity,
    SUM(quantity_sold) - products.stock_quantity AS restock_quatity
FROM
    products
        LEFT JOIN
    sales ON products.product_id = sales.product_id
WHERE
    stock_quantity <= 10
GROUP BY products.product_id;

-- Create a report showing the daily inventory movements (restock vs. sales) for each product over a given period.
select movement_date AS movement_day,product_id,sum(quantity_moved),if(movement_type = 'IN','restock','Sold') as Report from inventory_movements
WHERE movement_date BETWEEN '2023-12-01' AND '2024-06-01'
group by movement_date,product_id,movement_type
order by product_id;

-- Rank products in each category by their prices.

select product_name,category,price,rank() over(partition by category order by price) as 'ranking by price' from products;

-- What is the average order size in terms of quantity sold for each product?
select product_id,avg(quantity_sold) from sales group by product_id;

-- Which products have seen the most recent restocks
select * from inventory_movements
where movement_type = 'IN'
order by movement_date desc;

-- Dynamic Pricing Simulation
with cte2 as(
select s.*,p.price, quantity_sold*price as no_discount, 
case 
	when quantity_sold=1 then 0 
    when quantity_sold=2 then 1
    when quantity_sold=3 then 2
	when quantity_sold=4 then 3
	when quantity_sold=5 then 4
    end as Add_discount
    from sales s
left join products p on s.product_id = p.product_id)
select sum(total_amount) Quaterly_Revenue,sum(total_amount*(1-Add_discount/100)) Dynamic_Quaterly_Revenue,sum(quantity_sold) Quaterly_sales_volume from cte2 group by quarter(sale_date);

-- Customer Purchase Patterns
    select 
        c.customer_id as C_ID,
        concat(c.first_name, ' ', c.last_name) as FullName,
        date_format(s.sale_date, '%Y-%m') as PurchaseMonth,
        count(s.sale_id) as PurchaseCount,
        sum(s.total_amount) as SpentAmount,
        row_number() over 
        (
        partition by c.customer_id 
        order by 
        sum(s.total_amount) 
        ) as `rank`
    from 
        Customers c
    join 
        Sales s on c.customer_id = s.customer_id
    group by 
        C_ID, FullName, PurchaseMonth;

-- Predictive Analytics
with cte3 as (
    select 
        c.customer_id as C_ID,
        concat(c.first_name, ' ', c.last_name) as FullName,
        max(s.sale_date) as LastestPurchase,
        datediff(curdate(), max(s.sale_date)) as PurchaseLag
    from 
        Customers c
    left join 
        Sales s on c.customer_id = s.customer_id
    group by
        C_ID, FullName
)
SELECT 
    C_ID,
    FullName,
    LastestPurchase,
    PurchaseLag,
    case 
        when PurchaseLag > 180 then 'High'
        when PurchaseLag between 90 and 180 then 'Medium'
        else 'None'
    end as Churn_Risk
from 
    cte3
order by 
    PurchaseLag desc;