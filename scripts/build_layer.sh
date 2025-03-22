#!/bin/bash

# Criar diretório para o output
mkdir -p terraform/modules/lambda/files

# Construir a imagem Docker
docker build -t lambda-layer -f Dockerfile.layer .

# Executar o container para copiar o ZIP
docker run --rm -v $(pwd)/terraform/modules/lambda/files:/output lambda-layer 