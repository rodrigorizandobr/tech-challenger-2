// Importar o handler do crawler
const { handler } = require('./crawler');

// Simular as variáveis de ambiente do Lambda
process.env.BUCKET_NAME = 'seu-bucket-local';
process.env.GLUE_WORKFLOW_NAME = 'seu-workflow-local';

// Função para executar o teste
async function runTest() {
    try {
        console.log('Iniciando teste local do crawler...');
        const result = await handler({});
        console.log('Resultado:', result);
    } catch (error) {
        console.error('Erro no teste:', error);
    }
}

// Executar o teste
runTest(); 