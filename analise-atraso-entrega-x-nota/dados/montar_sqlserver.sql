/*
  Monta o banco "olist" no SQL Server (2017 ou mais novo, vale para o 2025).

  ANTES DE RODAR
  1. Rode  baixar_csvs.py  (cria a pasta "dados" com 8 arquivos .csv).
  2. A pasta "dados" precisa estar num lugar que o SERVIDOR SQL enxerga.
       - SQL Server instalado no Windows: ex.  C:\olist\dados\
       - SQL Server em Docker: copie para dentro do contêiner, ex.
           docker cp ./dados NOME_DO_CONTEINER:/var/opt/mssql/dados
         e use o caminho de dentro:  /var/opt/mssql/dados/
  3. Altere a linha "DECLARE @pasta" abaixo (termine o caminho com \ ou /).
  4. Execute o script inteiro (F5 / Execute).

  Se o BULK INSERT der erro de permissão, use o assistente do SSMS:
  clique direito no banco > Tarefas > Importar Arquivo Simples (Import Flat File).

  As tabelas ficam SEM chave primária de propósito: achar as chaves faz parte do Caso 1.
*/

IF DB_ID(N'olist') IS NULL
    CREATE DATABASE olist;
GO

USE olist;
GO

SET NOCOUNT ON;

DECLARE @pasta NVARCHAR(400) = N'C:\olist\dados\';   -- <<< ALTERE AQUI

DROP TABLE IF EXISTS dbo.orders, dbo.items, dbo.payments, dbo.reviews,
                     dbo.customers, dbo.products, dbo.sellers, dbo.categories;

CREATE TABLE dbo.orders (
    order_id                       VARCHAR(40)  NOT NULL,
    customer_id                    VARCHAR(40)  NOT NULL,
    order_status                   VARCHAR(20)  NULL,
    order_purchase_timestamp       DATETIME2(0) NULL,
    order_approved_at              DATETIME2(0) NULL,
    order_delivered_carrier_date   DATETIME2(0) NULL,
    order_delivered_customer_date  DATETIME2(0) NULL,
    order_estimated_delivery_date  DATETIME2(0) NULL
);

CREATE TABLE dbo.items (
    order_id             VARCHAR(40)   NOT NULL,
    order_item_id        INT           NULL,
    product_id           VARCHAR(40)   NULL,
    seller_id            VARCHAR(40)   NULL,
    shipping_limit_date  DATETIME2(0)  NULL,
    price                DECIMAL(10,2) NULL,
    freight_value        DECIMAL(10,2) NULL
);

CREATE TABLE dbo.payments (
    order_id              VARCHAR(40)   NOT NULL,
    payment_sequential    INT           NULL,
    payment_type          VARCHAR(20)   NULL,
    payment_installments  INT           NULL,
    payment_value         DECIMAL(10,2) NULL
);

CREATE TABLE dbo.reviews (
    review_id                VARCHAR(40)   NOT NULL,
    order_id                 VARCHAR(40)   NOT NULL,
    review_score             INT           NULL,
    review_comment_title     NVARCHAR(200) NULL,
    review_comment_message   NVARCHAR(MAX) NULL,
    review_creation_date     DATETIME2(0)  NULL,
    review_answer_timestamp  DATETIME2(0)  NULL
);

CREATE TABLE dbo.customers (
    customer_id               VARCHAR(40)   NOT NULL,
    customer_unique_id        VARCHAR(40)   NOT NULL,
    customer_zip_code_prefix  VARCHAR(10)   NULL,
    customer_city             NVARCHAR(100) NULL,
    customer_state            CHAR(2)       NULL
);

CREATE TABLE dbo.products (
    product_id                  VARCHAR(40)   NOT NULL,
    product_category_name       NVARCHAR(100) NULL,
    product_name_lenght         INT           NULL,   -- "lenght" é o nome original da base
    product_description_lenght  INT           NULL,
    product_photos_qty          INT           NULL,
    product_weight_g            INT           NULL,
    product_length_cm           INT           NULL,
    product_height_cm           INT           NULL,
    product_width_cm            INT           NULL
);

CREATE TABLE dbo.sellers (
    seller_id                VARCHAR(40)   NOT NULL,
    seller_zip_code_prefix   VARCHAR(10)   NULL,
    seller_city              NVARCHAR(100) NULL,
    seller_state             CHAR(2)       NULL
);

CREATE TABLE dbo.categories (
    product_category_name          NVARCHAR(100) NOT NULL,
    product_category_name_english  NVARCHAR(100) NULL
);

-- Carrega os 8 arquivos
DECLARE @tabelas TABLE (n INT IDENTITY(1,1), tabela SYSNAME);
INSERT @tabelas (tabela)
VALUES (N'orders'), (N'items'), (N'payments'), (N'reviews'),
       (N'customers'), (N'products'), (N'sellers'), (N'categories');

DECLARE @i INT = 1, @total INT = (SELECT COUNT(*) FROM @tabelas),
        @tab SYSNAME, @sql NVARCHAR(MAX);

WHILE @i <= @total
BEGIN
    SELECT @tab = tabela FROM @tabelas WHERE n = @i;
    SET @sql = N'BULK INSERT dbo.' + QUOTENAME(@tab)
             + N' FROM ''' + REPLACE(@pasta, N'''', N'''''') + @tab + N'.csv'''
             + N' WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'','
             + N' CODEPAGE = ''65001'', KEEPNULLS, TABLOCK);';
    EXEC sys.sp_executesql @sql;
    SET @i = @i + 1;
END;

-- Índices para as consultas ficarem rápidas
CREATE INDEX ix_orders_order      ON dbo.orders(order_id);
CREATE INDEX ix_orders_customer   ON dbo.orders(customer_id);
CREATE INDEX ix_items_order       ON dbo.items(order_id);
CREATE INDEX ix_items_product     ON dbo.items(product_id);
CREATE INDEX ix_items_seller      ON dbo.items(seller_id);
CREATE INDEX ix_payments_order    ON dbo.payments(order_id);
CREATE INDEX ix_reviews_order     ON dbo.reviews(order_id);
CREATE INDEX ix_customers_id      ON dbo.customers(customer_id);
CREATE INDEX ix_products_id       ON dbo.products(product_id);
CREATE INDEX ix_sellers_id        ON dbo.sellers(seller_id);

-- Conferência: a coluna "linhas" tem que ser igual a "esperado"
SELECT 'orders'     AS tabela, COUNT(*) AS linhas, 99441  AS esperado FROM dbo.orders
UNION ALL SELECT 'items',      COUNT(*), 112650 FROM dbo.items
UNION ALL SELECT 'payments',   COUNT(*), 103886 FROM dbo.payments
UNION ALL SELECT 'reviews',    COUNT(*), 100000 FROM dbo.reviews
UNION ALL SELECT 'customers',  COUNT(*), 99441  FROM dbo.customers
UNION ALL SELECT 'products',   COUNT(*), 32951  FROM dbo.products
UNION ALL SELECT 'sellers',    COUNT(*), 3095   FROM dbo.sellers
UNION ALL SELECT 'categories', COUNT(*), 71     FROM dbo.categories;
