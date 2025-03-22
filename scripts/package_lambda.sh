#!/bin/bash

# Criar diretório temporário
mkdir -p lambda_package
cd lambda_package

# Criar ambiente virtual Python
python3 -m venv venv
source venv/bin/activate

# Instalar dependências
pip install -r ../terraform/modules/lambda/requirements.txt -t .

# Copiar código do Lambda
cp ../terraform/modules/lambda/files/b3_scraper.py .

# Criar ZIP
zip -r ../terraform/modules/lambda/files/b3_scraper.zip .

# Limpar
cd ..
rm -rf lambda_package
deactivate 