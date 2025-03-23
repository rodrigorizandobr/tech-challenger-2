import sys
import boto3
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from awsglue.dynamicframe import DynamicFrame
from datetime import datetime

# Inicialização do contexto Glue
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'bucket_name'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Criar cliente do Glue e S3
glue_client = boto3.client('glue')
s3_client = boto3.client('s3')

# Configurações
database_name = 'bovespa_db_dev'
table_name = 'bovespa_composicao_ibov'
bucket_name = args['bucket_name']

# Extrair data atual para particionamento
current_date = datetime.now()
year = current_date.strftime("%Y")
month = current_date.strftime("%m")
day = current_date.strftime("%d")

# Verificar se já existem dados para essa partição (ano/mês/dia)
partition_prefix = f"refined/year={year}/month={month}/day={day}/"
print(f"Verificando partição existente: s3://{bucket_name}/{partition_prefix}")

# Listar objetos na partição específica
try:
    response = s3_client.list_objects_v2(
        Bucket=bucket_name,
        Prefix=partition_prefix,
        MaxKeys=1
    )
    
    # Se já existem objetos nesta partição, não processa novamente
    if 'Contents' in response and len(response['Contents']) > 0:
        print(f"Partição {partition_prefix} já existe com {len(response['Contents'])} objetos.")
        print("Dados já foram refinados para esta data. Ignorando processamento para evitar duplicação.")
        job.commit()
        sys.exit(0)
    else:
        print(f"Partição {partition_prefix} não existe. Prosseguindo com o refinamento.")
except Exception as e:
    print(f"Erro ao verificar partição: {e}")
    print("Continuando com o processamento por precaução.")

# Leitura dos dados do S3 em formato Parquet
datasource = glueContext.create_dynamic_frame.from_options(
    "s3",
    {
        "paths": [f"s3://{bucket_name}/raw/"],
        "recurse": True,
        "groupFiles": "inPartition",
        "groupSize": "1048576"
    },
    format="parquet"
)

# Conversão para DataFrame para operações mais complexas
df = datasource.toDF()

# Imprimindo o schema para debug
print("Schema do DataFrame:")
df.printSchema()
print("\nNúmero de linhas:", df.count())
print("\nAmostra dos dados:")
df.show(5, truncate=False)

# Primeiro, vamos verificar os nomes das colunas existentes
print("\nColunas disponíveis:")
for col_name in df.columns:
    print(f"- {col_name}")

try:
    # Adicionar colunas de particionamento
    df_partitioned = df.select("*") \
                      .withColumn("year", lit(year)) \
                      .withColumn("month", lit(month)) \
                      .withColumn("day", lit(day))
    
    # Tentativa com os nomes de colunas originais do arquivo gerado pelo Lambda
    df_final = df_partitioned.select(
        df_partitioned["ticker"],
        df_partitioned["data_pregao"],
        df_partitioned["preco_abertura"],
        df_partitioned["preco_maximo"],
        df_partitioned["preco_minimo"],
        df_partitioned["preco_fechamento"],
        df_partitioned["preco_medio_abertura"],
        df_partitioned["volume_total"],
        df_partitioned["numero_negociacoes"],
        "year",
        "month", 
        "day"
    )
except Exception as e:
    print(f"Erro ao processar colunas: {e}")
    # Fallback para colunas IBOV
    try:
        df_final = df_partitioned.select(
            df_partitioned["Código"].alias("ticker"),
            df_partitioned["Ação"].alias("acao"),
            df_partitioned["Tipo"].alias("tipo"),
            df_partitioned["`Qtde. Teórica`"].alias("quantidade_teorica"),
            df_partitioned["`Part. (%)`"].alias("participacao"),
            "year",
            "month",
            "day"
        )
    except Exception as e2:
        print(f"Falha no fallback também: {e2}")
        # Último recurso: usar as colunas exatamente como estão
        column_names = df.columns
        print(f"Usando colunas exatamente como estão: {column_names}")
        df_final = df_partitioned

# Verificar se temos dados para processar
if df_final.count() == 0:
    print("Nenhum dado novo para processar. Finalizando job.")
    job.commit()
    sys.exit(0)

# Converter para DynamicFrame para usar recursos do Glue
dynamic_frame_write = DynamicFrame.fromDF(df_final, glueContext, "dynamic_frame_write")

# Configuração para criar tabela no Data Catalog e manter esquema em execuções subsequentes
sink = glueContext.getSink(
    connection_type="s3",
    path=f"s3://{bucket_name}/refined/",
    enableUpdateCatalog=True,
    updateBehavior="UPDATE_IN_DATABASE",
    partitionKeys=["year", "month", "day"],
    transformation_ctx="write_refined"
)

# Configurar o formato e informações do catálogo
sink.setFormat("glueparquet")
sink.setCatalogInfo(
    catalogDatabase=database_name,
    catalogTableName=table_name
)

# Escrever os dados
sink.writeFrame(dynamic_frame_write)
print(f"Dados refinados salvos com sucesso na partição: {partition_prefix}")

job.commit() 