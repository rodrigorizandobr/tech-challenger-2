import os
import time
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from datetime import datetime
import boto3
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
from dotenv import load_dotenv

# Carregar variáveis de ambiente
load_dotenv()

def setup_chrome_driver():
    """
    Configura o Chrome Driver com as opções necessárias
    """
    chrome_options = Options()
    chrome_options.add_argument("--headless")  # Executar em modo headless
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    
    # Configurar diretório de download
    download_dir = os.path.join(os.getcwd(), "downloads")
    os.makedirs(download_dir, exist_ok=True)
    
    chrome_options.add_experimental_option("prefs", {
        "download.default_directory": download_dir,
        "download.prompt_for_download": False,
        "download.directory_upgrade": True,
        "safebrowsing.enabled": True
    })
    
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=chrome_options)
    return driver, download_dir

def get_b3_data():
    """
    Faz o scraping dos dados do pregão da B3 usando Selenium
    """
    url = "https://sistemaswebb3-listados.b3.com.br/indexPage/day/IBOV?language=pt-br"
    
    try:
        # Configurar e iniciar o Chrome Driver
        driver, download_dir = setup_chrome_driver()
        
        # Acessar a página
        driver.get(url)
        
        # Aguardar o botão de download ficar visível e clicável
        download_button = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, "//a[contains(text(), 'Download')]"))
        )
        
        # Clicar no botão de download
        download_button.click()
        
        # Aguardar o download do arquivo
        time.sleep(5)  # Esperar 5 segundos para o download completar
        
        # Encontrar o arquivo CSV mais recente no diretório de downloads
        csv_files = [f for f in os.listdir(download_dir) if f.endswith('.csv')]
        if not csv_files:
            raise Exception("Arquivo CSV não encontrado no diretório de downloads")
        
        latest_csv = max([os.path.join(download_dir, f) for f in csv_files], key=os.path.getctime)
        
        # Ler o CSV
        df = pd.read_csv(latest_csv, delimiter=';', thousands='.', decimal=',', encoding='latin1')
        
        # Adicionar data de processamento
        df['data_processamento'] = datetime.now().strftime('%Y-%m-%d')
        
        # Limpar arquivos temporários
        for f in csv_files:
            os.remove(os.path.join(download_dir, f))
        
        # Fechar o driver
        driver.quit()
        
        return df
        
    except Exception as e:
        if 'driver' in locals():
            driver.quit()
        print(f"Erro ao obter dados da B3: {str(e)}")
        raise

def save_to_parquet(df, bucket_name):
    """
    Salva o DataFrame em formato Parquet no S3
    """
    # Criar nome do arquivo com data
    data_processamento = datetime.now().strftime('%Y-%m-%d')
    file_name = f"raw/data_processamento={data_processamento}/b3_data.parquet"
    
    try:
        # Converter para tabela PyArrow
        table = pa.Table.from_pandas(df)
        
        # Salvar localmente primeiro
        local_file = "/tmp/b3_data.parquet"
        pq.write_table(table, local_file)
        
        # Upload para S3
        s3 = boto3.client('s3',
                         aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
                         aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
                         region_name=os.getenv('AWS_REGION'))
        
        s3.upload_file(local_file, bucket_name, file_name)
        
        print(f"Arquivo salvo com sucesso em s3://{bucket_name}/{file_name}")
        
        # Limpar arquivo temporário
        os.remove(local_file)
        
    except Exception as e:
        print(f"Erro ao salvar arquivo no S3: {str(e)}")
        raise

def main():
    # Obter nome do bucket das variáveis de ambiente
    bucket_name = os.getenv('BUCKET_NAME')
    if not bucket_name:
        raise ValueError("Variável de ambiente BUCKET_NAME não definida")
    
    try:
        # Obter dados da B3
        df = get_b3_data()
        
        # Salvar no S3
        save_to_parquet(df, bucket_name)
        
        print("Processo de scraping concluído com sucesso!")
        
    except Exception as e:
        print(f"Erro durante o processo de scraping: {str(e)}")
        raise

if __name__ == "__main__":
    main() 