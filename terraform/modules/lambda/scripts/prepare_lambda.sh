#!/bin/bash
set -e

echo "Iniciando preparação do pacote Lambda..."

# Criar diretório temporário
TEMP_DIR="temp_build"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Copiando arquivos fonte..."
cp src/crawler.js "$TEMP_DIR/"
cp src/crawler-common.js "$TEMP_DIR/"
cp src/package.json "$TEMP_DIR/"

echo "Instalando dependências..."
cd "$TEMP_DIR"
npm install --production

echo "Criando arquivo ZIP..."
# Remover ZIP anterior se existir
rm -f ../crawler.zip
# Incluir todos os arquivos, incluindo node_modules
zip -r ../crawler.zip .

echo "Limpando arquivos temporários..."
cd ..
rm -rf "$TEMP_DIR"

echo "Pacote Lambda preparado com sucesso!"

# Verificar conteúdo do ZIP
echo "Conteúdo do ZIP:"
unzip -l crawler.zip 