# Projeto 2: Entrega atrasada piora a nota?

**Base:** Olist (96.470 pedidos entregues, com avaliação). **Consultas:** `projeto2_atraso_x_nota.sql` (C1 a C15).

## Resposta curta

Sim, e muito. Pedido atrasado tem nota média **2,26**. Pedido no prazo tem **4,28**. Mas o atraso **não explica tudo**: só **27%** das notas 1 e 2 vêm de pedidos atrasados. **57%** vêm de pedidos entregues no prazo.

## O que testei

| Hipótese | O que os dados mostram | Resultado |
|---|---|---|
| Atraso piora a nota | 2,26 (atrasado) x 4,28 (no prazo). 63% dos atrasados dão nota 1 ou 2, contra 9,5% dos no prazo. | Confirmada |
| Quanto mais atraso, pior | Atraso de 1-3 dias: 3,28. De 4-7 dias: 2,09. De 8+ dias: cerca de 1,7. | Confirmada. A queda forte começa em 4 dias |
| É efeito de estado ou de prazo prometido, não do atraso | Dentro de cada prazo prometido, atrasado fica 1,5 a 2 pontos abaixo (ex.: prazo até 15 dias: 2,90 x 4,39). Dentro de SP: 2,53 x 4,31. | Descartada |
| O atraso explica as notas ruins | Das 15.010 notas 1 e 2: 4.108 atrasados, 2.318 pedidos que nem chegaram, 8.584 entregues no prazo. | Descartada |
| Frete caro derruba a nota | Frete menor que 10% do preço: 4,34. Frete de 50% ou mais: 4,24. | Efeito pequeno |

## Achados

- **Onde atrasa:** AL 21%, MA 17%, SE 15%, PI 14%, CE 14%, BA 12%, RJ 12%. SP só 4,5%. RJ pesa porque tem 12 mil pedidos.
- **Quando atrasou:** fev/2018 (14%) e mar/2018 (19%), contra 1% a 7% na maioria dos outros meses (nov/2017 também foi alto: 12%). Em fev-mar/2018, RJ chegou a 34% de atraso. Em abr/2018 voltou a 4,5%.
- **Vendedores:** dos 418 com 50+ pedidos, 18 atrasam 15% ou mais. O pior atrasa cerca de 30%.
- **Mesmo no prazo, esperar pesa:** entrega em até 7 dias: 4,40. Em 22 dias ou mais: 3,88.
- **Problemas que não são atraso:** pedidos com 2+ vendedores têm nota 2,84 (só 1% de atraso, 1.275 pedidos). Móveis de escritório têm nota 3,75 mesmo no prazo.
- **Correlação** entre dias de atraso e nota: -0,27. Entre dias de espera e nota: -0,33.

## Recomendação

1. **Evitar atraso de 4 dias ou mais.** É aí que a nota despenca. Prioridade: RJ, Nordeste e os 18 vendedores com 15%+ de atraso.
2. **Prometer prazo que dá para cumprir.** Chegar adiantado melhora pouco (4,31 contra 4,01 no dia). Atrasar custa mais de 2 pontos.
3. **Investigar à parte** os pedidos com 2+ vendedores e a categoria móveis de escritório. O problema deles não é o prazo.
4. **Teto do ganho:** se todo atraso virasse entrega no prazo e nada mais mudasse, a nota média geral iria de 4,14 para 4,28. É um teto, não uma previsão.

## O que ainda não dá para afirmar

- **Por que** atrasou. Transportadora, vendedor, greve? Os dados não dizem. O pico de fev-mar/2018 fica sem explicação.
- Que o atraso **causa** a nota baixa. Os testes (dose, prazo prometido, estado) apontam que sim, mas não provam.
- Nada sobre o que não está na base: qualidade do produto e expectativa do cliente.

## Armadilhas que apareceram (aprenda com elas)

1. **Definição de atraso muda o número.** Contando a hora: 7.826 pedidos. Contando só o dia: 6.534. Escolha uma regra e escreva qual.
2. **555 pedidos têm mais de uma avaliação.** Peguei a mais recente. Sem isso, um pedido contaria duas vezes.
3. **5.110 pessoas avaliaram antes de receber** (nota média 1,92; 96% já estavam atrasados). Tirando essas, a diferença cai de 2,02 para **0,77 ponto** (3,51 contra 4,28). O efeito continua, mas o "2,26" exagera: parte é gente reclamando que o pedido não chegou.
4. **No SQL Server, `AVG` de número inteiro devolve inteiro.** Use `AVG(1.0 * nota)`.
5. **Correlação não é causa.** Vendedor ruim pode atrasar *e* vender produto ruim.


## Arquivos

- `projeto2_atraso_x_nota.sql`: as consultas, numeradas C1, C2, ...
- `docs/apresentacao.pdf`: slides curtos do caso.
- `docs/relatorio.pdf`: relatório de 3 páginas.
- `dados/`: scripts para baixar os dados e montar o banco.

## Como reproduzir

1. `python3 dados/baixar_csvs.py` baixa os dados reais do Olist e cria 8 CSVs na pasta `dados`.
2. Rode `dados/montar_sqlserver.sql` no SQL Server e ajuste o caminho na linha `DECLARE @pasta`.
3. Rode as consultas de `projeto2_atraso_x_nota.sql` na ordem.

## Aviso

Os números foram recalculados de forma independente em pandas. As consultas em T-SQL tiveram a sintaxe validada, mas não foram executadas num SQL Server real na preparação. Rode e confira os resultados.

Autor: João Wellyngton
