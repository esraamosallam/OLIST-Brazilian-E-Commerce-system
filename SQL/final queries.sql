--Ranking

-- Calculate customer rankings by total amount spent

CREATE OR ALTER view vr
AS
SELECT * FROM (
SELECT 
    O.customer_id,
	C.customer_name,
	SUM(P.value) total_price,
	customer_city,
    RANK() OVER (PARTITION BY customer_city ORDER BY SUM([value]) DESC) AS customer_rank
FROM
    payments P, orders O, customers C
WHERE 
	P.order_id = O.order_id AND C.customer_id = O.customer_id 
GROUP BY
    O.customer_id , C.customer_name, P.value, customer_city

	)
AS new_table1
--WHERE 
	--customer_rank = 3

GO

SELECT * FROM vr

--- total payment per category
go
CREATE OR ALTER view vr2
AS
SELECT * FROM (
SELECT
    P.category_name,
    SUM(O.price) AS total_category_price,
    YEAR(D.approved_date) AS approved_year,
    DENSE_RANK() OVER (PARTITION BY YEAR(D.approved_date) ORDER BY SUM(O.price) DESC) AS category_dr
FROM
    order_items O
JOIN
    orders D ON O.order_id = D.order_id
JOIN
    products P ON O.product_id = P.product_id
WHERE
    P.category_name IS NOT NULL
GROUP BY
    P.category_name, YEAR(D.approved_date)


)
AS new_table2

GO

SELECT TOP 5 * FROM vr2


---comment
go
CREATE OR ALTER VIEW vr3 AS
WITH RankedProducts AS (
    SELECT
        P.category_name,
        P.product_id,
        SUM(O.price) AS total_sales
    FROM
        order_items O
    JOIN
        products P ON O.product_id = P.product_id
    GROUP BY
        P.category_name,
        P.product_id
)

SELECT
    category_name,
    product_id,
    total_sales,
    ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY total_sales DESC) AS category_sales_rank
FROM
    RankedProducts
WHERE 
    category_name IS NOT NULL;

GO

SELECT * FROM vr3



go
CREATE OR ALTER VIEW vr4 AS

select * , Ntile(3) over (order by O.freight_value DESC) as G
from order_items O
 
SELECT * FROM vr4

go


CREATE TABLE order_history (order_id NVARCHAR(20), event_description NVARCHAR(60), event_timestamp DATE)
go
CREATE OR ALTER TRIGGER TrackNewOrder
ON orders
AFTER INSERT
AS
BEGIN
    INSERT INTO order_history (order_id, event_description, event_timestamp)
    SELECT inserted.order_id, 'New order placed', GETDATE()
    FROM inserted;
END;


INSERT INTO orders( order_id, customer_id,Destimated_date ) VALUES ('133','00012a2ce6f8dcda20d059ce98491703','1/2/2000')


SELECT * FROM order_history

-- Create a trigger in SQL Server
go
CREATE OR ALTER TRIGGER UpdateLoyaltyPoints
ON orders
AFTER UPDATE
AS
BEGIN
    -- Check if the 'status' column has changed to 'delivered'
    IF UPDATE(status)
    BEGIN
        UPDATE C
        SET loyalty_points = C.loyalty_points + 10
        FROM customers AS C
        INNER JOIN inserted AS I ON C.customer_id = I.customer_id
        WHERE I.status = 'delivered' AND I.status <> deleted.status;
    END
END;

go
-- Create a trigger in SQL Server
CREATE OR ALTER TRIGGER PreventProductDeletion
ON products
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @active_order_count INT;
    
    -- Check if there are active orders for the product
    SELECT @active_order_count = COUNT(*)
    FROM orders
    WHERE product_id = (SELECT product_id FROM deleted) AND status <> 'Delivered';

    -- If there are active orders, prevent deletion
    IF @active_order_count > 0
    BEGIN
        THROW 51000, 'Cannot delete product with active orders.', 1;
    END;

    -- If no active orders, proceed with the deletion
    DELETE P
    FROM products P
    JOIN deleted D ON P.product_id = D.product_id;
END;


go
CREATE OR ALTER TRIGGER CalculateOrderTotal
ON order_items
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @order_id INT;
    DECLARE @total DECIMAL(10, 2);

    -- Get the order_id from the newly inserted row
    SELECT @order_id = order_id FROM INSERTED;

    -- Calculate the total order value
    SELECT @total = SUM(price) FROM order_items WHERE order_id = @order_id;

    -- Update the total_order_value in the orders table
    UPDATE orders
    SET total_order_value = @total
    WHERE order_id = @order_id;
END;

-- Add the total_sales column to the olist_sellers_dataset table
ALTER TABLE olist_sellers_dataset
ADD total_sales DECIMAL(10, 2) DEFAULT 0; -- Adjust the data type as needed
go 

CREATE OR ALTER TRIGGER UpdateSellerSales
ON order_items
AFTER INSERT
AS
BEGIN
    -- Update the seller's total sales
    UPDATE s
    SET total_sales = total_sales + i.price
    FROM sellers s
    JOIN INSERTED i ON s.seller_id = i.seller_id;
END;

UPDATE [dbo].[order_items]
SET price = 5000
FROM sellers 
where [order_id]= '00010242fe8c5a6d1ba2dd792cb16214'

select total_sales from [dbo].[sellers] where sellers.total_sales is not null


select count(total_sales) from sellers



-------------------------------------------------------------------------
create Or ALTER Function AVR(@category_name varchar(50))
returns Table 
AS 
Return(
select p.category_name , ROUND(sum(price),1) as Total_profit
from order_items oi, products p
where p.category_name =  @category_name
group by p.category_name )

select * from AVR('perfumaria')


CREATE or ALTER PROCEDURE Top_Customer @year int
as 
select Top 1 customer_name , COUNT(DISTINCT o.order_id) as Number_of_orders , 
COUNT(item_id) Number_of_item ,p.value
from customers c
inner join  orders o
on C.customer_id = o.customer_id  
inner join order_items oi 
on o.order_id = oi.order_id and year(oi.shipping_limit_date) = @year
inner join payments p
on o.order_id = p.order_id
group by customer_name,p.value
order by p.value desc

exec Top_Customer 2016;


create or alter procedure order_payment @city varchar(50)
as
select g.geolocation_city, p.type, COUNT(o.order_id) total_orders
from orders o, payments p, geolocation g
where o.order_id = p.order_id and g.geolocation_city = @city
group by p.type, g.geolocation_city

exec order_payment 'cajamar';
exec order_payment 'sao paulo';

select distinct(g.geolocation_city) from geolocation g

--proc for the most selling orders seller
CREATE or ALTER PROCEDURE top_seller @year int
as 
select top 1 s.seller_name, year(oi.shipping_limit_date) y, 
count(oi.order_id) count_of_orders
from order_items oi, sellers s
where oi.seller_id = s.seller_id and year(oi.shipping_limit_date) = @year
group by s.seller_name, year(oi.shipping_limit_date)
order by count_of_orders desc
go

exec top_seller 2017;

--proc top 10 products by year
go
CREATE or ALTER PROCEDURE top_product @year int
as 
select top 10 p.category_name, year(oi.shipping_limit_date) year, 
count(oi.item_id) count_of_orders
from order_items oi, products p
where oi.product_id = p.product_id and year(oi.shipping_limit_date) = @year
group by p.category_name, year(oi.shipping_limit_date)
order by count_of_orders desc

exec top_product 2017

go
--func to recognize if the product is best seller or not
go
create or alter view Vtotal_prices
as
select p.category_name, round(sum(oi.price),0) total_price
from order_items oi, products p
where oi.product_id = p.product_id and p.category_name is not null
group by p.category_name

--order by total_price desc

go

CREATE or alter Function best_product(@prod varchar(50))
returns @t table (product_status varchar(50))
as
		begin
			declare @price int, @a varchar(50), @b varchar(50), 
			@c varchar(50)
			select @price = v.total_price 
			from Vtotal_prices v
			where @prod = v.category_name

			if @price > 100000
				begin
					set @a = 'Best Seller'
					insert into @t values(@a)
				end

			else if @price > 10000 and @price < 100000
				begin
					set @b = 'Moderate seller'
					insert into @t values(@b)
				end

			else if @price < 10000
				begin
					set @c = 'Warnning it is low seller'
					insert into @t values(@c)
				end
			return
		end 
go

create or alter view Vbest_product
as
select * from best_product('eletrodomesticos')

select * from Vbest_product


select * from best_product('perfumaria')
select * from best_product('flores')

--top product review
go
CREATE or alter Function top_products_review(@year int)
returns Table
as
return
(
select top 10 p.category_name, year(oi.shipping_limit_date) year,
sum(r.score) total_score
from order_items oi, products p, reviews r
where oi.product_id = p.product_id and oi.order_id = r.order_id
and @year = year(oi.shipping_limit_date)
group by p.category_name, year(oi.shipping_limit_date)
order by total_score desc
)

go
select * from top_products_review(2017)

go
create Or ALTER Function AVR(@cat varchar(50))
returns Table 
AS 
Return(
select p.category_name , ROUND(sum(price),1) as Total_profit
from order_items oi, products p
where oi.product_id = p.product_id and p.category_name = @cat
group by p.category_name)

select * from AVR('flores')


go
CREATE or ALTER PROCEDURE Top_Customer @year int
as 
select Top 1 customer_name, COUNT(DISTINCT o.order_id) as Number_of_orders, 
COUNT(item_id) Number_of_item, round(p.value, 0)
from customers c 
inner join  orders o
on c.customer_id = o.customer_id  
inner join order_items oi
on o.order_id = oi.order_id and year(oi.shipping_limit_date) = @year
inner join payments p
on o.order_id = p.order_id
group by customer_name, p.value
order by p.value desc
go 

execute top_Customer 2018;


