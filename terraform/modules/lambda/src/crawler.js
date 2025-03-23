const {
    initBrowser,
    accessB3Page,
    extractTableData,
    convertToParquet,
    generateFilenames
} = require('./crawler-common');
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const glue = new AWS.Glue();

exports.handler = async (event, context) => {
    let browser = null;
    
    try {
        // Inicializar navegador com Chrome do Lambda
        const { browser: _browser, page } = await initBrowser();
        browser = _browser;

        // Acessar página da B3
        await accessB3Page(page);

        // Extrair dados da tabela
        const tableData = await extractTableData(page);

        // Converter dados para Parquet
        console.log('Convertendo dados para Parquet...');
        const parquetBuffer = await convertToParquet(tableData);

        // Gerar nomes de arquivos
        const today = new Date();
        const filenames = generateFilenames(today);
        
        // Definir caminho no S3
        const s3BasePath = `raw/${today.getFullYear()}/${(today.getMonth() + 1).toString().padStart(2, '0')}/${today.getDate().toString().padStart(2, '0')}`;
        const parquetKey = `${s3BasePath}/${filenames.parquet}`;

        // Fazer upload do arquivo Parquet para o S3
        console.log('Fazendo upload do arquivo Parquet para o S3...');
        await s3.putObject({
            Bucket: process.env.BUCKET_NAME,
            Key: parquetKey,
            Body: parquetBuffer,
            ContentType: 'application/octet-stream'
        }).promise();
        console.log('Arquivo Parquet enviado para:', parquetKey);

        // Após salvar o parquet no S3, acionar o Glue Workflow
        console.log('Acionando Workflow do Glue...');
        const glueParams = {
            Name: process.env.GLUE_WORKFLOW_NAME // Nome do workflow Glue
        };

        const response = await glue.startWorkflowRun(glueParams).promise();
        console.log('Workflow do Glue acionado com sucesso:', response);

        return {
            statusCode: 200,
            body: JSON.stringify({
                status: 'success',
                parquetKey,
                message: 'Arquivo Parquet enviado com sucesso para o S3 e Workflow do Glue acionado'
            })
        };
    } catch (error) {
        console.error('Erro:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                status: 'error',
                message: error.message
            })
        };
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
}; 