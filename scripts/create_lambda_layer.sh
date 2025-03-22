#!/bin/bash

# Criar diretório temporário
mkdir -p lambda_layer
cd lambda_layer

# Criar estrutura de diretórios
mkdir -p python/lib/python3.9/site-packages
mkdir -p opt

# Instalar dependências Python
pip install --target python/lib/python3.9/site-packages \
    pandas \
    pyarrow \
    selenium \
    webdriver_manager \
    python-dotenv

# Baixar Chrome e ChromeDriver
curl -SL https://github.com/adieuadieu/serverless-chrome/releases/download/v1.0.0-55/stable-headless-chromium-amazonlinux-2.zip > headless-chromium.zip
unzip headless-chromium.zip -d opt/
rm headless-chromium.zip

CHROMEDRIVER_VERSION=$(curl -sS https://chromedriver.storage.googleapis.com/LATEST_RELEASE)
curl -SL https://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip > chromedriver.zip
unzip chromedriver.zip -d opt/
rm chromedriver.zip

# Dar permissões de execução
chmod 755 opt/headless-chromium
chmod 755 opt/chromedriver

# Criar ZIP do layer
zip -r ../terraform/modules/lambda/files/scraper_dependencies.zip python opt/

# Limpar
cd ..
rm -rf lambda_layer 