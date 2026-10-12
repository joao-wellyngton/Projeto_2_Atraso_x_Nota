/*
  PROJETO 2: Entrega atrasada piora a nota? (SQL Server 2025, banco "olist")

  Regras que valem para o arquivo todo:
   - Atraso = DIA da entrega depois do DIA prometido (a hora não conta).
   - Cada pedido entra UMA vez, com a avaliação mais recente dele.
   - AVG(1.0 * nota): no SQL Server, AVG de número inteiro devolve inteiro (4.28 viraria 4).
   - Rode o bloco "PREPARAÇÃO" primeiro. As tabelas #temporárias somem quando você fecha a janela.
*/
USE olist;
GO

/* ===================== PREPARAÇÃO ===================== */

-- 1 avaliação por pedido (a mais recente)
DROP TABLE IF EXISTS #aval;
SELECT order_id, nota, aval_data
INTO   #aval
FROM (
    SELECT order_id,
           review_score         AS nota,
           review_creation_date AS aval_data,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY review_answer_timestamp DESC, review_id) AS rn
    FROM dbo.reviews
) r
WHERE rn = 1;

-- Pedidos entregues, com os dias de atraso calculados
DROP TABLE IF EXISTS #entregues;
SELECT o.order_id,
       o.customer_id,
       o.order_purchase_timestamp          AS compra,
       o.order_delivered_customer_date     AS entrega,
       a.nota,
       a.aval_data,
       DATEDIFF(day, CAST(o.order_estimated_delivery_date AS date),
                     CAST(o.order_delivered_customer_date AS date)) AS dias_atraso,
       DATEDIFF(day, CAST(o.order_purchase_timestamp AS date),
                     CAST(o.order_delivered_customer_date AS date)) AS dias_entrega,
       DATEDIFF(day, CAST(o.order_purchase_timestamp AS date),
                     CAST(o.order_estimated_delivery_date AS date)) AS dias_prometido
INTO   #entregues
FROM   dbo.orders o
JOIN   #aval a ON a.order_id = o.order_id
WHERE  o.order_status = 'delivered'
  AND  o.order_delivered_customer_date IS NOT NULL;

-- Quantos vendedores tem cada pedido
DROP TABLE IF EXISTS #vend;
SELECT order_id, COUNT(DISTINCT seller_id) AS n_vendedores
INTO   #vend
FROM   dbo.items
GROUP  BY order_id;

-- 1 linha por pedido: estado, categoria e vendedor do item mais caro
DROP TABLE IF EXISTS #principal;
SELECT e.order_id, e.dias_atraso, e.nota, e.compra,
       c.customer_state AS uf,
       x.seller_id,
       x.categoria
INTO   #principal
FROM   #entregues e
JOIN   dbo.customers c ON c.customer_id = e.customer_id
JOIN  (SELECT i.order_id, i.seller_id,
              ISNULL(t.product_category_name_english, 'sem_categoria') AS categoria,
              ROW_NUMBER() OVER (PARTITION BY i.order_id
                                 ORDER BY i.price DESC, i.order_item_id) AS rn
       FROM   dbo.items i
       LEFT JOIN dbo.products   p ON p.product_id = i.product_id
       LEFT JOIN dbo.categories t ON t.product_category_name = p.product_category_name) x
       ON x.order_id = e.order_id AND x.rn = 1;
GO

/* ===================== ANÁLISE ===================== */

-- C1. A definição de "atraso" muda o número? (hora conta ou não conta)
SELECT SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS atraso_se_hora_conta,
       SUM(CASE WHEN e.dias_atraso > 0 THEN 1 ELSE 0 END)                                               AS atraso_so_pelo_dia,
       COUNT(*)                                                                                          AS pedidos_entregues
FROM   #entregues e
JOIN   dbo.orders o ON o.order_id = e.order_id;

-- C2. Nota: atrasado x no prazo
SELECT CASE WHEN dias_atraso > 0 THEN 'atrasado' ELSE 'no_prazo' END               AS grupo,
       COUNT(*)                                                                     AS pedidos,
       ROUND(AVG(1.0 * nota), 2)                                                    AS nota_media,
       ROUND(100.0 * SUM(CASE WHEN nota <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1)      AS pct_nota_1_ou_2,
       ROUND(100.0 * SUM(CASE WHEN nota = 5  THEN 1 ELSE 0 END) / COUNT(*), 1)      AS pct_nota_5
FROM   #entregues
GROUP  BY CASE WHEN dias_atraso > 0 THEN 'atrasado' ELSE 'no_prazo' END;

-- C3. Quanto mais atraso, pior a nota? (faixas)
SELECT faixa,
       COUNT(*)                                                                AS pedidos,
       ROUND(AVG(1.0 * nota), 2)                                               AS nota_media,
       ROUND(100.0 * SUM(CASE WHEN nota <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_nota_1_ou_2
FROM (
    SELECT nota,
           CASE WHEN dias_atraso <= -8 THEN '1) 8+ dias adiantado'
                WHEN dias_atraso <= -1 THEN '2) 1-7 dias adiantado'
                WHEN dias_atraso  =  0 THEN '3) no dia prometido'
                WHEN dias_atraso <=  3 THEN '4) atraso de 1-3 dias'
                WHEN dias_atraso <=  7 THEN '5) atraso de 4-7 dias'
                WHEN dias_atraso <= 14 THEN '6) atraso de 8-14 dias'
                ELSE                        '7) atraso de 15+ dias' END AS faixa
    FROM #entregues) f
GROUP  BY faixa
ORDER  BY faixa;

-- C4. De onde vêm TODAS as notas 1 e 2? (o atraso explica tudo?)
SELECT grupo, COUNT(*) AS notas_1_ou_2,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_do_total
FROM (
    SELECT CASE WHEN o.order_status <> 'delivered' OR o.order_delivered_customer_date IS NULL
                     THEN 'a) pedido nao entregue'
                WHEN CAST(o.order_delivered_customer_date AS date) > CAST(o.order_estimated_delivery_date AS date)
                     THEN 'b) entregue com atraso'
                ELSE      'c) entregue no prazo' END AS grupo
    FROM   dbo.orders o
    JOIN   #aval a ON a.order_id = o.order_id
    WHERE  a.nota <= 2) g
GROUP  BY grupo
ORDER  BY grupo;

-- C5. Armadilha: avaliações escritas ANTES da entrega
SELECT CASE WHEN CAST(aval_data AS date) < CAST(entrega AS date)
            THEN 'avaliou_antes_de_receber' ELSE 'avaliou_depois' END   AS momento,
       COUNT(*)                                                          AS pedidos,
       ROUND(AVG(1.0 * nota), 2)                                         AS nota_media,
       ROUND(100.0 * SUM(CASE WHEN dias_atraso > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_atrasados
FROM   #entregues
GROUP  BY CASE WHEN CAST(aval_data AS date) < CAST(entrega AS date)
               THEN 'avaliou_antes_de_receber' ELSE 'avaliou_depois' END;

-- C5b. O efeito do atraso continua, se eu usar só quem avaliou DEPOIS de receber?
SELECT CASE WHEN dias_atraso > 0 THEN 'atrasado' ELSE 'no_prazo' END                 AS grupo,
       COUNT(*)                                                                       AS pedidos,
       ROUND(AVG(1.0 * nota), 2)                                                      AS nota_media,
       ROUND(100.0 * SUM(CASE WHEN nota <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1)        AS pct_nota_1_ou_2
FROM   #entregues
WHERE  CAST(aval_data AS date) >= CAST(entrega AS date)
GROUP  BY CASE WHEN dias_atraso > 0 THEN 'atrasado' ELSE 'no_prazo' END;

-- C6. Controle: o efeito aparece em prazos curtos, médios e longos?
SELECT prazo, grupo, COUNT(*) AS pedidos, ROUND(AVG(1.0 * nota), 2) AS nota_media
FROM (
    SELECT nota,
           CASE WHEN dias_prometido <= 15 THEN 'a) prometido ate 15 dias'
                WHEN dias_prometido <= 25 THEN 'b) prometido 16-25 dias'
                ELSE                           'c) prometido 26+ dias' END AS prazo,
           CASE WHEN dias_atraso > 0 THEN 'atrasado' ELSE 'no_prazo' END   AS grupo
    FROM #entregues) f
GROUP  BY prazo, grupo
ORDER  BY prazo, grupo;

-- C7. Onde o atraso é maior? Por estado (com pelo menos 300 pedidos)
SELECT TOP 8 uf,
       COUNT(*)                                                                  AS pedidos,
       ROUND(100.0 * SUM(CASE WHEN dias_atraso > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_atraso,
       ROUND(AVG(CASE WHEN dias_atraso >  0 THEN 1.0 * nota END), 2)             AS nota_atrasado,
       ROUND(AVG(CASE WHEN dias_atraso <= 0 THEN 1.0 * nota END), 2)             AS nota_no_prazo
FROM   #principal
GROUP  BY uf
HAVING COUNT(*) >= 300
ORDER  BY pct_atraso DESC;

-- C8. Pico de atraso: % de atraso por mês da compra
SELECT FORMAT(compra, 'yyyy-MM') AS mes,
       COUNT(*)                                                                  AS pedidos,
       ROUND(100.0 * SUM(CASE WHEN dias_atraso > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_atraso,
       ROUND(AVG(1.0 * nota), 2)                                                 AS nota_media
FROM   #entregues
WHERE  compra >= '2017-01-01' AND compra < '2018-09-01'
GROUP  BY FORMAT(compra, 'yyyy-MM')
ORDER  BY mes;

-- C9. Fev-mar/2018: o pico veio de onde? (estados)
SELECT TOP 5 uf, COUNT(*) AS pedidos,
       ROUND(100.0 * SUM(CASE WHEN dias_atraso > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_atraso
FROM   #principal
WHERE  compra >= '2018-02-01' AND compra < '2018-04-01'
GROUP  BY uf
HAVING COUNT(*) >= 300
ORDER  BY pct_atraso DESC;

-- C10. Categorias com pior nota ENTRE os pedidos que chegaram no prazo (problema não é a entrega)
SELECT TOP 6 categoria, COUNT(*) AS pedidos,
       ROUND(AVG(1.0 * nota), 2)                                               AS nota_no_prazo,
       ROUND(100.0 * SUM(CASE WHEN nota <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_nota_1_ou_2
FROM   #principal
WHERE  dias_atraso <= 0
GROUP  BY categoria
HAVING COUNT(*) >= 500
ORDER  BY nota_no_prazo;

-- C11. Pedidos com mais de um vendedor
SELECT CASE WHEN v.n_vendedores > 1 THEN 'varios_vendedores' ELSE 'um_vendedor' END AS tipo,
       COUNT(*)                                                                      AS pedidos,
       ROUND(AVG(1.0 * e.nota), 2)                                                   AS nota_media,
       ROUND(100.0 * SUM(CASE WHEN e.dias_atraso > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_atraso
FROM   #entregues e
JOIN   #vend v ON v.order_id = e.order_id
GROUP  BY CASE WHEN v.n_vendedores > 1 THEN 'varios_vendedores' ELSE 'um_vendedor' END;

-- C12. Mesmo chegando no prazo, demorar mais piora a nota?
SELECT faixa, COUNT(*) AS pedidos, ROUND(AVG(1.0 * nota), 2) AS nota_media
FROM (
    SELECT nota,
           CASE WHEN dias_entrega <=  7 THEN 'a) ate 7 dias'
                WHEN dias_entrega <= 14 THEN 'b) 8-14 dias'
                WHEN dias_entrega <= 21 THEN 'c) 15-21 dias'
                ELSE                         'd) 22+ dias' END AS faixa
    FROM #entregues
    WHERE dias_atraso <= 0) f
GROUP  BY faixa
ORDER  BY faixa;

-- C13. Vendedores com muito atraso (pelo menos 50 pedidos)
SELECT TOP 5 seller_id, COUNT(*) AS pedidos,
       ROUND(100.0 * SUM(CASE WHEN dias_atraso > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_atraso,
       ROUND(AVG(1.0 * nota), 2)                                                     AS nota_media
FROM   #principal
GROUP  BY seller_id
HAVING COUNT(*) >= 50
ORDER  BY pct_atraso DESC;

-- C14. Frete pesado derruba a nota? (só pedidos no prazo; frete como % do preço dos itens)
SELECT faixa_frete, COUNT(*) AS pedidos, ROUND(AVG(1.0 * nota), 2) AS nota_media
FROM (
    SELECT e.nota,
           CASE WHEN t.frete / t.preco < 0.10 THEN 'a) frete menor que 10%'
                WHEN t.frete / t.preco < 0.25 THEN 'b) 10% a 25%'
                WHEN t.frete / t.preco < 0.50 THEN 'c) 25% a 50%'
                ELSE                               'd) 50% ou mais' END AS faixa_frete
    FROM   #entregues e
    JOIN  (SELECT order_id, SUM(CAST(freight_value AS float)) AS frete, SUM(CAST(price AS float)) AS preco
           FROM dbo.items GROUP BY order_id HAVING SUM(price) > 0) t ON t.order_id = e.order_id
    WHERE  e.dias_atraso <= 0) f
GROUP  BY faixa_frete
ORDER  BY faixa_frete;

-- C15. Correlação de Pearson (o SQL Server não tem função pronta; vai a fórmula)
--      Resultado vai de -1 a 1. Perto de 0 = pouca relação linear.
SELECT (n * sxy - sx * sy) / SQRT((n * sxx - sx * sx) * (n * syy - sy * sy)) AS correlacao_atraso_nota
FROM (
    SELECT CAST(COUNT(*) AS float)            AS n,
           SUM(CAST(dias_atraso AS float))    AS sx,
           SUM(CAST(nota AS float))           AS sy,
           SUM(CAST(dias_atraso AS float) * nota)        AS sxy,
           SUM(CAST(dias_atraso AS float) * dias_atraso) AS sxx,
           SUM(CAST(nota AS float) * nota)               AS syy
    FROM #entregues) s;
