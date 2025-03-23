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

# Criar cliente do Glue
glue_client = boto3.client('glue')

# Criar o banco de dados se não existir
database_name = 'bovespa_db_dev'
try:
    glue_client.create_database(
        DatabaseInput={
            'Name': database_name,
            'Description': 'Banco de dados para armazenar dados do Bovespa'
        }
    )
    print(f"Banco de dados '{database_name}' criado com sucesso.")
except glue_client.exceptions.AlreadyExistsException:
    print(f"O banco de dados '{database_name}' já existe.")

# Leitura dos dados do S3 em formato Parquet
datasource = glueContext.create_dynamic_frame.from_options(
    "s3",
    {
        "paths": [f"s3://{args['bucket_name']}/raw/"],
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

# Extrair data atual para particionamento
current_date = datetime.now()
year = current_date.strftime("%Y")
month = current_date.strftime("%m")
day = current_date.strftime("%d")

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

# Converter para DynamicFrame para usar recursos do Glue
dynamic_frame_write = DynamicFrame.fromDF(df_final, glueContext, "dynamic_frame_write")

# Escrever os dados particionados e catalogar no Glue Catalog
sink = glueContext.getSink(
    connection_type="s3",
    path=f"s3://{args['bucket_name']}/refined/",
    enableUpdateCatalog=True,
    partitionKeys=["year", "month", "day"],
    transformation_ctx="write_refined"
)

# Configurar o catálogo
sink.setFormat("glueparquet")
sink.setCatalogInfo(
    catalogDatabase="bovespa_db_dev",
    catalogTableName="bovespa_composicao_ibov"
)

# Escrever os dados
sink.writeFrame(dynamic_frame_write)

job.commit() 