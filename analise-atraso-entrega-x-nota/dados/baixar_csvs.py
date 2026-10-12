"""Baixa os dados reais do Olist e salva CSVs limpos para o SQL Server.

Uso (no Terminal / PowerShell):
    python3 baixar_csvs.py            (Mac)
    python baixar_csvs.py             (Windows)

Cria a pasta "dados" com 8 arquivos (orders.csv, items.csv, ...), ~65 MB no total.
Só usa a biblioteca padrão do Python. Não precisa instalar nada.

Os arquivos saem em UTF-8 sem BOM, com aspas padronizadas e quebra de linha CRLF,
que é o formato que o BULK INSERT do SQL Server lê sem problema.
"""
import csv
import io
import os
import sys
import urllib.request

BASE = "https://raw.githubusercontent.com/dujiaying/olist/master/data/"

# nome da tabela -> arquivo de origem
TABELAS = {
    "orders": "olist_orders_dataset",
    "items": "olist_order_items_dataset",
    "payments": "olist_order_payments_dataset",
    "reviews": "olist_order_reviews_dataset",
    "customers": "olist_customers_dataset",
    "products": "olist_products_dataset",
    "sellers": "olist_sellers_dataset",
    "categories": "product_category_name_translation",
}


def main(pasta="dados"):
    os.makedirs(pasta, exist_ok=True)
    for nome, arquivo in TABELAS.items():
        print(f"baixando {arquivo} ...", flush=True)
        with urllib.request.urlopen(f"{BASE}{arquivo}.csv", timeout=120) as r:
            texto = r.read().decode("utf-8-sig")  # tira o BOM, se tiver
        linhas = list(csv.reader(io.StringIO(texto, newline="")))
        destino = os.path.join(pasta, f"{nome}.csv")
        with open(destino, "w", encoding="utf-8", newline="") as f:
            csv.writer(f, lineterminator="\r\n").writerows(linhas)
        print(f"  {destino}: {len(linhas) - 1} linhas de dados")
    print(f"pronto. Arquivos em: {os.path.abspath(pasta)}")


if __name__ == "__main__":
    main(*sys.argv[1:2])
