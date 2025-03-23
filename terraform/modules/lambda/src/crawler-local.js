const fs = require('fs').promises;
const path = require('path');
const {
    initBrowser,
    accessB3Page,
    extractTableData,
    convertToParquet,
    generateFilenames,
    createDateDirectory
} = require('./crawler-common');

async function crawl() {
    let browser = null;
    
    try {
        // Inicializar navegador com Chrome local
        const { browser: _browser, page } = await initBrowser({
            channel: 'chrome'  // Usar Chrome instalado no sistema
        });
        browser = _browser;

        // Acessar página da B3
        await accessB3Page(page);

        // Extrair dados da tabela
        const tableData = await extractTableData(page);

        // Converter dados para Parquet
        console.log('Convertendo dados para Parquet...');
        const parquetBuffer = await convertToParquet(tableData);

        // Criar diretório e gerar nomes de arquivos
        const today = new Date();
        const saveDir = await createDateDirectory(__dirname + '/downloads', today);
        const filenames = generateFilenames(today);
        
        // Salvar arquivo Parquet
        const parquetFilePath = path.join(saveDir, filenames.parquet);
        await fs.writeFile(parquetFilePath, parquetBuffer);
        console.log('Arquivo Parquet salvo em:', parquetFilePath);

        // Salvar dados da tabela em JSON (para debug)
        const jsonFilePath = path.join(saveDir, filenames.json);
        await fs.writeFile(jsonFilePath, JSON.stringify(tableData, null, 2));
        console.log('Arquivo JSON salvo em:', jsonFilePath);

        return {
            status: 'success',
            parquetFilePath,
            jsonFilePath,
            tableData
        };
    } catch (error) {
        console.error('Erro:', error);
        throw error;
    } finally {
        if (browser !== null) {
            try {
                await browser.close();
                console.log('Navegador fechado com sucesso');
            } catch (error) {
                console.error('Erro ao fechar o navegador:', error);
            }
        }
    }
}

// Executar o crawler
crawl().catch(console.error); 