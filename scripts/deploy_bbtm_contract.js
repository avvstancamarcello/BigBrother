// scripts/deploy_bbtm_contract.js
// Questo è uno script JavaScript, Hardhat userà hardhat.config.js per la compilazione e il deploy.

const hre = require("hardhat");

async function main() {
    // La regola del Filo di Arianna: Verifica delle credenziali e dello stato
    console.log("--- LA REGOLA DEL FILO DI ARIANNA: INIZIO DEPLOY ---");
    console.log("Verifico le credenziali e il saldo del deployer...");

    const [deployer] = await hre.ethers.getSigners();

    if (!deployer) {
        console.error("ERRORE: Deployer account non trovato. Assicurati che PRIVATE_KEY sia configurata nel tuo .env");
        process.exit(1);
    }

    const deployerBalance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("Account Deployer (firmatario della transazione):", deployer.address);
    console.log("Saldo del Deployer:", hre.ethers.utils.formatEther(deployerBalance), "MATIC");

    if (deployerBalance.lt(hre.ethers.utils.parseEther("0.1"))) { // Controlla se il saldo è inferiore a 0.1 MATIC
        console.warn("ATTENZIONE: Saldo MATIC del deployer potenzialmente insufficiente per il deploy e le transazioni future. Considera di aggiungere più fondi.");
    }

    const CONTRACT_NAME = "BigBrotherTheMusical"; // Nome del contratto nel tuo .sol (BigBrotherTheMusical.sol)

    // RECUPERA LA FACTORY DEL CONTRATTO
    // La Regola del Filo di Arianna: Assicurati di puntare al contratto corretto.
    const ContractFactory = await hre.ethers.getContractFactory(CONTRACT_NAME);

    // --- PARAMETRI PER IL COSTRUTTORE DEL CONTRATTO BBTM ---
    // La Regola del Filo di Arianna: La baseURI deve essere precisa e non ambigua.
    const baseURI = "ipfs://bafybeicrgxjcqb7h6gj7qkceyxshalzc6ra4gu6kzrwjcq2ttg6yl4vmhq/"; 
    const ownerAddress = deployer.address; // L'account che deploya diventa l'owner
    const creatorWalletAddress = "0xf18c4cC01F72b50B389252e4d84AA376649Eb347"; // L'indirizzo del tuo creator (sostituisci se diverso)

    console.log("Base URI configurato per i metadati NFT:", baseURI);
    console.log("Owner del Contratto:", ownerAddress);
    console.log("Creator Wallet:", creatorWalletAddress);
    console.log("------------------------------------------");

    // Deploy del contratto passando i 3 argomenti corretti
    // La Regola SPOK: Il teletrasporto del contratto inizia!
    console.log("Inizio il teletrasporto del contratto...");
    const contract = await ContractFactory.deploy(baseURI, ownerAddress, creatorWalletAddress);
    await contract.waitForDeployment(); // Usato .waitForDeployment() per le versioni recenti di Hardhat/Ethers.js

    const deployedAddress = await contract.getAddress();
    console.log("✅ Contratto 'BigBrotherTheMusical' (BBTM) teletrasportato con successo su indirizzo:", deployedAddress);
    console.log("--- LA REGOLA DEL FILO DI ARIANNA: DEPLOY COMPLETATO ---");
    console.log("Non dimenticare di salvare questo indirizzo per il tuo frontend!");
    console.log("------------------------------------------");
}

main().catch((error) => {
    console.error("❌ ERRORE DURANTE IL TELETRASPORTO DEL CONTRATTO:", error);
    process.exitCode = 1;
});

