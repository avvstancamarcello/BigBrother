/** @type import('hardhat/config').HardhatUserConfig */
require('dotenv').config(); // Carica le variabili d'ambiente dal file .env
require("@nomicfoundation/hardhat-ethers"); // CRUCIALE: Importa il plugin hardhat-ethers

module.exports = {
  solidity: {
    version: "0.8.26", // La versione di Solidity che abbiamo usato
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // Numero di runs per l'ottimizzatore
      },
    },
  },
  networks: {
    hardhat: {
      // Configurazioni per la rete Hardhat di default (sviluppo locale)
    },
    polygon: { // Questo è il network 'polygon'
      url: process.env.NODE_URL_POLYGON_MAINNET || "", // URL dell'endpoint Polygon da .env
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [], // Chiave privata da .env
      chainId: 137, // Chain ID di Polygon Mainnet (aggiunto per chiarezza)
      gasPrice: 30 * 10**9, // Gas Price impostato a 30 Gwei (30 * 10^9 Wei) (aggiunto per chiarezza)
    },
    // Se hai altre reti di test (es. sepolia), puoi aggiungerle qui
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY, // API Key per Polygonscan da .env (per la verifica del contratto)
  },
};
