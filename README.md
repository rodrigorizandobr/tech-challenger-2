# Pipeline de Dados B3 Bovespa

Este projeto implementa um pipeline de dados para extrair, processar e analisar dados do pregão da B3 (Bolsa de Valores Brasileira) utilizando serviços AWS.

## Arquitetura

O pipeline é composto pelos seguintes componentes:

1. **Ingestão de Dados**
   - Script Python para scraping dos dados da B3
   - Armazenamento dos dados brutos no S3 em formato Parquet

2. **Processamento**
   - AWS Lambda para trigger do job Glue
   - AWS Glue para transformação dos dados
   - Armazenamento dos dados refinados no S3

3. **Análise**
   - AWS Glue Catalog para catalogação dos dados
   - Amazon Athena para consultas SQL

## Estrutura do Projeto

```
terraform/
├── modules/
│   ├── s3/          # Módulo para buckets S3
│   ├── lambda/      # Módulo para função Lambda
│   ├── glue/        # Módulo para job Glue e catálogo
│   └── iam/         # Módulo para roles e políticas IAM
├── environments/
│   └── dev/         # Configurações do ambiente de desenvolvimento
└── main.tf          # Arquivo principal do Terraform
```

## Pré-requisitos

- AWS CLI configurado
- Terraform >= 1.0.0
- Python >= 3.9

## Deploy

1. Configure suas credenciais AWS:
```bash
aws configure
```

2. Inicialize o Terraform:
```bash
cd terraform/environments/dev
terraform init
```

3. Revise o plano de execução:
```bash
terraform plan
```

4. Aplique as mudanças:
```bash
terraform apply
```

## Transformações de Dados

O job Glue realiza as seguintes transformações:

1. Agrupamento e sumarização por ação
2. Renomeação de colunas para melhor entendimento
3. Cálculos com datas para análise temporal
4. Particionamento por data e código da ação

## Consultas no Athena

Os dados podem ser consultados via Athena usando SQL padrão. Exemplo:

```sql
SELECT 
  codigo_acao,
  AVG(preco_medio) as preco_medio_geral,
  SUM(volume_negociado) as volume_total
FROM "b3_bovespa_dev"."dados_refinados"
WHERE data_processamento = CURRENT_DATE
GROUP BY codigo_acao
ORDER BY volume_total DESC
LIMIT 10;
```
