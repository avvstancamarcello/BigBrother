// scripts/deploy_bbtm_contract.js
// Questo è uno script JavaScript, Hardhat userà hardhat.config.js per la compilazione e il deploy.

// NON importare 'hre' direttamente con require("hardhat");
// Hardhat inietta automaticamente l'ambiente runtime (hre) e le sue proprietà globali.
// Accediamo direttamente a 'ethers' da hardhat.
const { ethers } = require("hardhat"); // CORRETTO: Accede a 'ethers' globalmente dall'ambiente Hardhat

async function main() {
    // La regola del Filo di Arianna: Verifica delle credenziali e dello stato
    console.log("--- LA REGOLA DEL FILO DI ARIANNA: INIZIO DEPLOY ---");
    console.log("Verifico le credenziali e il saldo del deployer...");

    // USO CORRETTO DI ETHERS: Chiamate direttamente su 'ethers'
    const [deployer] = await ethers.getSigners(); // Corretto

    if (!deployer) {
        console.error("ERRORE: Deployer account non trovato. Assicurati che PRIVATE_KEY sia configurata nel tuo .env");
        process.exit(1);
    }

    const deployerBalance = await ethers.provider.getBalance(deployer.address); // Corretto
    // RETTIFICATO per ethers.js v6: formatEther direttamente su ethers
    console.log("Account Deployer (firmatario della transazione):", deployer.address);
    console.log("Saldo del Deployer:", ethers.formatEther(deployerBalance), "MATIC"); // CORRETTO

    // RETTIFICATO per ethers.js v6: parseEther direttamente su ethers
    if (deployerBalance.lt(ethers.parseEther("0.1"))) { // CORRETTO
        console.warn("ATTENZIONE: Saldo MATIC del deployer potenzialmente insufficiente per il deploy e le transazioni future. Considera di aggiungere più fondi.");
    }

    const CONTRACT_NAME = "BigBrotherTheMusical"; // Nome del contratto nel tuo .sol (BigBrotherTheMusical.sol)

    // RECUPERA LA FACTORY DEL CONTRATTO
    // La Regola del Filo di Arianna: Assicurati di puntare al contratto corretto.
    const ContractFactory = await ethers.getContractFactory(CONTRACT_NAME); // Corretto

    // --- PARAMETRI PER IL COSTRUTTORE DEL CONTRATTO BBTM ---
    // La Regola del Filo di Arianna: La baseURI deve essere precisa e non ambigua.
    const baseURI = "ipfs://bafybeickfxxa5nmkt3afvbohnfuaodylzbt4c4ei5yf2ht3kf5mb5i7iye/"; // CID FINALE DEI METADATI JSON
    const ownerAddress = "0x83114bA5262CD62AF6E7d619035d20bfaF33Eaa5"; // L'account che deploya diventa l'owner
    const creatorWalletAddress = "0x83114bA5262CD62AF6E7d619035d20bfaF33Eaa5"; // L'indirizzo del tuo creator

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
