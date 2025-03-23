const fs = require('fs').promises;
const path = require('path');
const parquet = require('parquetjs');

// Função auxiliar para esperar
const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Função para extrair dados da tabela
async function extractTableData(page) {
    // Selecionar 120 registros
    console.log('Selecionando 120 registros...');
    await page.select('#selectPage', '120');
    
    // Esperar a tabela atualizar
    console.log('Aguardando atualização da tabela...');
    await wait(2000);
    
    // Extrair dados da tabela
    console.log('Extraindo dados da tabela...');
    const tableData = await page.evaluate(() => {
        const table = document.querySelector('table');
        const headers = Array.from(table.querySelectorAll('th')).map(th => th.textContent.trim());
        const rows = Array.from(table.querySelectorAll('tr')).slice(1); // Pular cabeçalho
        
        const data = rows.map(row => {
            const cells = Array.from(row.querySelectorAll('td'));
            return cells.map(cell => cell.textContent.trim());
        });
        
        return {
            headers,
            rows: data
        };
    });

    console.log('Dados extraídos (total de linhas):', tableData.rows.length);
    console.log('Processando dados sem as duas últimas linhas:', tableData.rows.length - 2);

    return {
        headers: tableData.headers,
        rows: tableData.rows.slice(0, -2) // Remove as duas últimas linhas
    };
}

// Função para converter dados em Parquet
async function convertToParquet(tableData) {
    const isLambda = process.env.AWS_LAMBDA_FUNCTION_NAME !== undefined;
    const tempDir = isLambda ? '/tmp' : __dirname;
    const tempFile = path.join(tempDir, 'temp.parquet');

    // Definir o schema com tipos apropriados
    const fields = {};
    tableData.headers.forEach(header => {
        // Colunas que devem ser string
        if (['Código', 'Ação', 'Tipo'].includes(header)) {
            fields[header] = { type: 'UTF8' };
        } 
        // Colunas numéricas
        else {
            fields[header] = { type: 'DOUBLE' };
        }
    });

    const schema = new parquet.ParquetSchema(fields);

    // Criar um novo arquivo Parquet
    const writer = await parquet.ParquetWriter.openFile(schema, tempFile);

    // Converter e escrever os dados
    for (const row of tableData.rows) {
        const rowData = {};
        tableData.headers.forEach((header, index) => {
            const value = row[index];
            // Se for uma coluna string, manter como string
            if (['Código', 'Ação', 'Tipo'].includes(header)) {
                rowData[header] = value;
            } 
            // Se for numérica, converter para número
            else {
                // Remove pontos e substitui vírgula por ponto para converter corretamente
                const numberValue = value.replace(/\./g, '').replace(',', '.');
                rowData[header] = parseFloat(numberValue) || 0;
            }
        });
        await writer.appendRow(rowData);
    }

    // Fechar o writer
    await writer.close();

    // Ler o arquivo gerado
    const buffer = await fs.readFile(tempFile);
    
    // Remover arquivo temporário
    await fs.unlink(tempFile);

    return buffer;
}

// Função para inicializar o navegador
async function initBrowser(options = {}) {
    const isLambda = process.env.AWS_LAMBDA_FUNCTION_NAME !== undefined;
    let browser;

    if (isLambda) {
        const chromium = require('@sparticuz/chromium');
        const puppeteer = require('puppeteer-core');

        browser = await puppeteer.launch({
            args: chromium.args,
            defaultViewport: chromium.defaultViewport,
            executablePath: await chromium.executablePath(),
            headless: chromium.headless,
            ignoreHTTPSErrors: true
        });
    } else {
        const puppeteer = require('puppeteer');
        const defaultOptions = {
            headless: "new",
            args: ['--no-sandbox', '--disable-setuid-sandbox']
        };
        const browserOptions = { ...defaultOptions, ...options };
        browser = await puppeteer.launch(browserOptions);
    }

    console.log('Navegador iniciado com sucesso');
    const page = await browser.newPage();
    console.log('Nova página criada');
    
    // Configurar timeouts
    await page.setDefaultNavigationTimeout(30000);
    await page.setDefaultTimeout(30000);

    return { browser, page };
}

// Função para acessar a página da B3
async function accessB3Page(page) {
    console.log('Acessando página da B3...');
    await page.goto('https://sistemaswebb3-listados.b3.com.br/indexPage/day/IBOV?language=pt-br', {
        waitUntil: ['networkidle0', 'domcontentloaded'],
        timeout: 30000
    });
    console.log('Página da B3 carregada');
}

// Função para gerar nomes de arquivos
function generateFilenames(date = new Date()) {
    const baseFileName = `bovespa_${date.toISOString().split('T')[0]}`;
    return {
        parquet: `${baseFileName}.parquet`
    };
}

// Função para criar diretório de data
async function createDateDirectory(baseDir, date = new Date()) {
    const saveDir = path.join(baseDir,
        date.getFullYear().toString(),
        (date.getMonth() + 1).toString().padStart(2, '0'),
        date.getDate().toString().padStart(2, '0')
    );
    
    await fs.mkdir(saveDir, { recursive: true });
    return saveDir;
}

module.exports = {
    wait,
    extractTableData,
    convertToParquet,
    initBrowser,
    accessB3Page,
    generateFilenames,
    createDateDirectory
}; 