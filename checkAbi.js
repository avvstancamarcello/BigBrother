const fs = require('fs');
const path = require('path');

const abiJsPath = path.join(__dirname, 'abi.js');
const compiledJsonPath = path.join(__dirname, 'artifacts', 'contracts', 'BigBrotherTheMusical.sol', 'BigBrotherTheMusical.json');

// Carica la ABI da abi.js (assumendo: const contractABI = [...])
function loadAbiJs() {
    const abiJsContent = fs.readFileSync(abiJsPath, 'utf8');
    // Estrae solo l'array, sia che sia JSON puro sia 'const contractABI = [...]'
    const match = abiJsContent.match(/\[\s*{[\s\S]*}\s*\]/);
    if (match) {
        return JSON.parse(match[0]);
    }
    // Se è già JSON puro:
    try {
        return JSON.parse(abiJsContent);
    } catch(e) {
        throw new Error('Impossibile interpretare abi.js');
    }
}

// Carica la ABI dal JSON compilato
function loadCompiledAbi() {
    const compiledContent = fs.readFileSync(compiledJsonPath, 'utf8');
    const compiled = JSON.parse(compiledContent);
    return compiled.abi;
}

function main() {
    try {
        const abiJs = loadAbiJs();
        const compiledAbi = loadCompiledAbi();

        const abiJsStr = JSON.stringify(abiJs, null, 2);
        const compiledAbiStr = JSON.stringify(compiledAbi, null, 2);

        if (abiJsStr === compiledAbiStr) {
            console.log('✅ Le ABI sono IDENTICHE!');
        } else {
            console.log('❌ Le ABI sono DIVERSE!');
            // Mostra un diff di massima
            const jsdiff = require('diff');
            const diff = jsdiff.diffLines(abiJsStr, compiledAbiStr);
            diff.forEach(part => {
                const color = part.added ? '\x1b[32m' :
                              part.removed ? '\x1b[31m' : '\x1b[0m';
                process.stderr.write(color + part.value + '\x1b[0m');
            });
        }
    } catch (err) {
        console.error('Errore durante il controllo:', err.message);
    }
}

main();
