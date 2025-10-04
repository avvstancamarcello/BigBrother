// SPDX-License-Identifier: MIT
// Copyright © Giugno 2025 Avv. Marcello Stanca - Firenze.
// Questo smart contract "Big Brother The Musical" (BBTM) e le sue funzioni implementate
// sono protetti da Best Practice Copyright Marcello Stanca, che ne riconosce la paternità.
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Nota: Le librerie OpenZeppelin come Context, IERC165, ERC165, SafeCast, Panic, Math, SignedMath, Arrays
// e altre che erano "espanse" nel tuo LHISA_LecceNFT.sol, non sono importate qui direttamente
// perché si assume che Hardhat le gestisca tramite le dipendenze npm di OpenZeppelin
// (o siano già incluse nel file appiattito finale per il deploy).
// Questo codice è per il file sorgente pulito.

contract BigBrotherTheMusical is ERC1155URIStorage, Ownable, Pausable, ReentrancyGuard, ERC2981 {
    string public name = "BigBrotherTheMusical";
    string public symbol = "BBTM";

    mapping(uint256 => uint256) public maxSupply;
    mapping(uint256 => uint256) public totalMinted;
    mapping(uint256 => uint256) public pricesInWei;
    mapping(uint256 => bool) public isValidTokenId;

    // Mappature per CID e URI criptati (mantenute dal tuo LHISA_LecceNFT.sol, ma useremo customTokenURIs per i metadati pubblici)
    mapping(uint256 => string) public encryptedURIs; 
    mapping(uint256 => string) public tokenCIDs; 

    // Mappatura informativa sul valore in euro (dal tuo LHISA_LecceNFT.sol)
    mapping(uint256 => uint256) public euroValueForTokenId;

    // NUOVA MAPPATURA PER GESTIRE I CID SPECIFICI DEI METADATI JSON CHE HANNO LA PRIORITÀ
    mapping(uint256 => string) public customTokenURIs; // Memorizza URI specifici per tokenId (JSON)

    address public withdrawWallet;
    address public creatorWallet;
    uint256 public creatorSharePercentage;
    uint96 public defaultRoyaltyFeeNumerator; // Aggiunto per tracciare il valore numeratore royalty di default
    string public baseURI; // Questa sarà la baseURI della cartella principale per i metadati JSON

    // --- Whitelist ---
    bool public whitelistActive = false;
    mapping(address => bool) public whitelist;

    // --- Limitazione mint tokenID specifico (adattato) ---
    bool public limitSpecificTokenActive; 
    mapping(address => uint256) public lastMintTimeSpecificToken; 
    mapping(address => uint256) public mintedSpecificTokenLast24h; 

    // --- Governance ---
    struct Proposal {
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
        bool active;
        bool allowNewMintsToVote; // Mantenuta dal tuo LHISA_LecceNFT.sol
        mapping(address => uint256) balancesSnapshot;
    }
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public nextProposalId;

    // --- Burn Request ---
    struct BurnRequest {
        address requester;
        uint256 tokenId;
        uint256 quantity;
        bool approved;
    }
    BurnRequest[] public burnRequests;

    uint256 public constant MINIMUM_TOTAL_VALUE = 84000; // Valore dal tuo LHISA_LecceNFT.sol

    // --- Eventi (Allineati con LHISA_LecceNFT.sol e la nuova logica) ---
    event NFTMinted(address indexed buyer, uint256 tokenId, uint256 quantity, uint256 price, string metadataURI); // Modificato da encryptedURI a metadataURI
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event BaseURIUpdated(string newBaseURI);
    event TokenCIDUpdated(uint256 indexed tokenId, string newCID);
    event TokenCIDsUpdated(uint256[] tokenIds, string[] newCIDs);
    event EncryptedURIUpdated(uint256 indexed tokenId, string newEncryptedURI);
    event EncryptedURIsUpdated(uint256[] tokenIds, string[] newEncryptedURIs);
    event NFTBurned(address indexed owner, uint256 tokenId, uint256 quantity);
    event BurnRequested(address indexed requester, uint256 tokenId, uint256 quantity, uint256 requestId);
    event BurnApproved(uint256 requestId, address indexed requester, uint256 tokenId, uint256 quantity);
    event BurnDenied(uint256 requestId, address indexed requester, uint256 tokenId, uint256 quantity);
    event CreatorShareTransferred(address indexed receiver, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, string description, uint256 startTime, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool vote, uint256 weight);
    event WithdrawWalletChanged(address indexed oldWallet, address indexed newWallet);
    event CreatorWalletChanged(address indexed oldWallet, address indexed newWallet);
    event PriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event LimitToken100ActiveChanged(bool newStatus);
    event WhitelistStatusChanged(bool status);
    // event CustomTokenURIUpdated(uint256 indexed tokenId, string newCustomURI); // Nuovo evento opzionale per tracciare i customURI
    // event CustomTokenURIsUpdated(uint256[] tokenIds, string[] newCustomURIs); // Nuovo evento opzionale

    constructor(
        string memory _baseURI, // E.g., "ipfs://bafybeicrgxjcqb7h6gj7qkceyxshalzc6ra4gu6kzrwjcq2ttg6yl4vmhq/"
        address _ownerAddress,
        address _creatorWalletAddress
    )
        ERC1155(_baseURI) // La baseURI standard viene passata al costruttore ERC1155
        Ownable(_ownerAddress)
    {
        require(bytes(_baseURI).length > 0, "Base URI cannot be empty");
        require(_ownerAddress != address(0), "Owner address cannot be zero");
        require(_creatorWalletAddress != address(0), "Creator wallet address cannot be zero");

        withdrawWallet = _ownerAddress;
        creatorWallet = _creatorWalletAddress;
        baseURI = _baseURI; // Salva la baseURI della cartella per uso interno (e default uri())
        creatorSharePercentage = 6;
        nextProposalId = 0;
        limitSpecificTokenActive = false; // Rinominata da limitToken100Active

        // Inizializzazione per i 20 TokenID di BBTM con prezzi e maxSupply definiti
        for (uint256 i = 1; i <= 20; i++) {
            pricesInWei[i] = i * 20 * (10**18); // Prezzo: TokenID * 20 MATIC in Wei
            if (i <= 10) {
                maxSupply[i] = 1000;
            } else {
                maxSupply[i] = 1500;
            }
            isValidTokenId[i] = true;
            // customTokenURIs NON vengono inizializzati qui, verranno impostati in seguito con setCustomTokenURI
        }

        // Popola euroValueForTokenId (esempi dal tuo LHISA_LecceNFT, adattati per i nuovi ID se necessario)
        // Questi sono solo a scopo informativo e non influenzano i prezzi on-chain.
        euroValueForTokenId[1] = 10; 
        euroValueForTokenId[5] = 50; 
        euroValueForTokenId[10] = 100;
        euroValueForTokenId[20] = 200; 
        // Puoi aggiungere tutti i 20 ID qui se vuoi.

        // Royalties default (5%)
        _setDefaultRoyalty(_creatorWalletAddress, 500);
        defaultRoyaltyFeeNumerator = 500;
    }

    // --- Whitelist controls ---
    function setWhitelist(address[] calldata addresses, bool status) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; ++i) {
            whitelist[addresses[i]] = status;
        }
    }
    function setWhitelistActive(bool status) external onlyOwner {
        whitelistActive = status;
        emit WhitelistStatusChanged(status);
    }

    // --- Pausable controls ---
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // --- Limitazione mint tokenID specifico ---
    function setLimitSpecificTokenActive(bool active) external onlyOwner {
        limitSpecificTokenActive = active;
        emit LimitToken100ActiveChanged(active); // Usiamo l'evento esistente dal contratto schema
    }

    // Funzione interna per il controllo del limite (allineata con la logica del tuo precedente)
    function _checkMintLimitSpecificToken(address user, uint256 /* tokenId */, uint256 quantity) internal returns (bool) {
        if (!limitSpecificTokenActive) {
            return true;
        }
        uint256 nowTime = block.timestamp;
        if (nowTime - lastMintTimeSpecificToken[user] > 1 days) {
            mintedSpecificTokenLast24h[user] = 0;
            lastMintTimeSpecificToken[user] = nowTime;
        }
        require(mintedSpecificTokenLast24h[user] + quantity <= 50, "Mint limit for this token exceeded in 24h"); 
        mintedSpecificTokenLast24h[user] += quantity; // Aggiunta questa riga per aggiornare il contatore
        return true; // Ritorna true se tutti i controlli passano
    }

    // --- Mint (singolo) ---
    function mintNFT(uint256 tokenId, uint256 quantity) external payable whenNotPaused nonReentrant {
        if (whitelistActive) {
            require(whitelist[msg.sender], "Not whitelisted for mint");
        }
        require(isValidTokenId[tokenId], "The provided tokenId is not supported");
        require(totalMinted[tokenId] + quantity <= maxSupply[tokenId], "Minting exceeds maximum supply");
        require(quantity > 0, "Mint quantity must be greater than zero");

        // Ho generalizzato il controllo limite per tutti i token attivi, non solo 100
        _checkMintLimitSpecificToken(msg.sender, tokenId, quantity);

        uint256 totalCostInWei = pricesInWei[tokenId] * quantity;
        require(msg.value == totalCostInWei, "Incorrect ETH amount sent for minting");

        uint256 creatorShare = (totalCostInWei * creatorSharePercentage) / 100;
        if (creatorShare > 0) {
            (bool successCreator, ) = creatorWallet.call{value: creatorShare}("");
            require(successCreator, "Failed to transfer creator share");
            emit CreatorShareTransferred(creatorWallet, creatorShare);
        }

        totalMinted[tokenId] += quantity;
        _mint(msg.sender, tokenId, quantity, "");
        emit NFTMinted(msg.sender, tokenId, quantity, pricesInWei[tokenId], uri(tokenId)); // Ora emette l'URI finale del metadato
    }

    // --- Batch Mint ---
    function mintBatchNFT(uint256[] calldata tokenIds, uint256[] calldata quantities) external payable whenNotPaused nonReentrant {
        if (whitelistActive) {
            require(whitelist[msg.sender], "Not whitelisted for mint");
        }
        require(tokenIds.length == quantities.length, "Arrays length mismatch");
        uint256 totalCost = 0;
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];
            uint256 quantity = quantities[i];
            require(isValidTokenId[tokenId], "Invalid tokenId");
            require(quantity > 0, "Quantity must be > 0");
            require(totalMinted[tokenId] + quantity <= maxSupply[tokenId], "Exceeds max supply");

            _checkMintLimitSpecificToken(msg.sender, tokenId, quantity); // Applicato a tutti i token nel batch

            totalCost += pricesInWei[tokenId] * quantity;
        }
        require(msg.value == totalCost, "Incorrect ETH amount sent for batch minting");
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            totalMinted[tokenIds[i]] += quantities[i];
        }
        _mintBatch(msg.sender, tokenIds, quantities, "");

        uint256 creatorShare = (totalCost * creatorSharePercentage) / 100;
        if (creatorShare > 0) {
            (bool successCreator, ) = creatorWallet.call{value: creatorShare}("");
            require(successCreator, "Failed to transfer creator share");
            emit CreatorShareTransferred(creatorWallet, creatorShare);
        }
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            emit NFTMinted(msg.sender, tokenIds[i], quantities[i], pricesInWei[tokenIds[i]], uri(tokenIds[i])); // Ora emette l'URI finale del metadato
        }
    }

    // --- Burn ---
    function burn(address account, uint256 tokenId, uint256 quantity) external whenNotPaused {
        require(
            account == msg.sender || isApprovedForAll(account, msg.sender),
            "Caller is not owner nor approved"
        );
        _burn(account, tokenId, quantity);
        totalMinted[tokenId] -= quantity; // Aggiunto per allineamento con LHISA_LecceNFT.sol
        emit NFTBurned(account, tokenId, quantity);
    }

    // --- Withdraw ---
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");
        (bool sent, ) = payable(withdrawWallet).call{value: balance}("");
        require(sent, "Withdraw failed");
        emit FundsWithdrawn(withdrawWallet, balance);
    }

    // --- Governance: Proposal & voto quadratico con snapshot (Dal tuo LHISA_LecceNFT.sol) ---
    function createProposal(
        string calldata description,
        uint256 startTime,
        uint256 endTime,
        bool allowNewMintsToVote
    ) external onlyOwner {
        require(startTime < endTime, "Start must be before end");
        Proposal storage prop = proposals[nextProposalId];
        prop.description = description;
        prop.startTime = startTime;
        prop.endTime = endTime;
        prop.yesVotes = 0;
        prop.noVotes = 0;
        prop.active = true;
        prop.allowNewMintsToVote = allowNewMintsToVote;
        emit ProposalCreated(nextProposalId, description, startTime, endTime);
        nextProposalId++;
    }

    function voteOnProposal(uint256 proposalId, bool support) external whenNotPaused {
        require(proposalId < nextProposalId, "Invalid proposal");
        Proposal storage prop = proposals[proposalId];
        require(prop.active, "Proposal not active");
        require(block.timestamp >= prop.startTime && block.timestamp <= prop.endTime, "Voting not allowed at this time");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        if (prop.balancesSnapshot[msg.sender] == 0) {
            uint256 balance = 0;
            for (uint256 i = 1; i <= 20; i++) { // Range aggiornato per BBTM
                balance += balanceOf(msg.sender, i);
            }
            require(balance > 0, "Must own at least one NFT to vote");
            prop.balancesSnapshot[msg.sender] = balance;
        }
        uint256 voteWeight = sqrt(prop.balancesSnapshot[msg.sender]);

        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            prop.yesVotes += voteWeight;
        } else {
            prop.noVotes += voteWeight;
        }
        emit Voted(proposalId, msg.sender, support, voteWeight);
    }

    function endProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "Proposal not active");
        require(block.timestamp > proposal.endTime, "Voting period has not ended yet");
        proposal.active = false;
    }

    function getProposalResults(uint256 proposalId) public view returns (string memory description, uint256 yesVotes, uint256 noVotes, bool active, uint256 startTime, uint256 endTime) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.description, proposal.yesVotes, proposal.noVotes, proposal.active, proposal.startTime, proposal.endTime);
    }

    // --- Burn Request (Dal tuo LHISA_LecceNFT.sol) ---
    function requestBurn(uint256 tokenId, uint256 quantity) external {
        require(isValidTokenId[tokenId], "Invalid tokenId");
        require(balanceOf(msg.sender, tokenId) >= quantity, "Insufficient balance");

        burnRequests.push(BurnRequest({
            requester: msg.sender,
            tokenId: tokenId,
            quantity: quantity,
            approved: false
        }));
        uint256 requestId = burnRequests.length - 1;
        emit BurnRequested(msg.sender, tokenId, quantity, requestId);
    }

    function approveBurn(uint256 requestId, bool approve) external onlyOwner {
        require(requestId < burnRequests.length, "Invalid requestId");
        BurnRequest storage request = burnRequests[requestId];
        require(!request.approved, "Request already processed");

        if (approve) {
            uint256 totalValueAfterBurn = calculateTotalValueAfterBurn(request.tokenId, request.quantity);
            require(totalValueAfterBurn >= MINIMUM_TOTAL_VALUE, "Cannot burn below minimum total value");
            _burn(request.requester, request.tokenId, request.quantity);
            totalMinted[request.tokenId] -= request.quantity;
            request.approved = true;
            emit BurnApproved(requestId, request.requester, request.tokenId, request.quantity);
        } else {
            emit BurnDenied(requestId, request.requester, request.tokenId, request.quantity);
        }
    }

    function calculateTotalValueAfterBurn(uint256 tokenId, uint256 quantity) public view returns (uint256) {
        uint256 totalValue = 0;
        uint256[] memory mintedTokens = new uint256[](20); // Array size updated for BBTM's 20 TokenIDs
        uint256 idx = 0;
        for (uint256 i = 1; i <= 20; i++) { // Loop updated for BBTM's 20 TokenIDs
            mintedTokens[idx] = totalMinted[i]; 
            idx++; 
        }
        uint256 tokenArrayIndex = tokenId - 1; // Logica adattata per TokenID 1-20
        require(tokenArrayIndex < 20, "Token ID not in burn calculation range"); 
        mintedTokens[tokenArrayIndex] -= quantity;

        idx = 0;
        for (uint256 i = 1; i <= 20; i++) { // Loop updated for BBTM's 20 TokenIDs
            totalValue += mintedTokens[idx] * pricesInWei[i];
            idx++; 
        }
        return totalValue;
    }

    // --- Utility Functions (dal tuo LHISA_LecceNFT.sol) ---
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    // --- Aggiorna Prezzi e Wallet con eventi ---
    function updatePrice(uint256 tokenId, uint256 newPrice) external onlyOwner {
        require(isValidTokenId[tokenId], "Invalid tokenId");
        uint256 oldPrice = pricesInWei[tokenId];
        pricesInWei[tokenId] = newPrice;
        emit PriceUpdated(tokenId, oldPrice, newPrice);
    }
    function updateWithdrawWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid wallet");
        address old = withdrawWallet;
        withdrawWallet = newWallet;
        emit WithdrawWalletChanged(old, newWallet);
    }

    function updateCreatorWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid wallet");
        address old = creatorWallet;
        creatorWallet = newWallet;
        emit CreatorWalletChanged(old, newWallet);
        _setDefaultRoyalty(newWallet, defaultRoyaltyFeeNumerator);
    }

    // --- Royalties ERC2981 (Dal tuo LHISA_LecceNFT.sol) ---
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
        defaultRoyaltyFeeNumerator = feeNumerator;
    }    

    // --- Implementazione della funzione URI per gestire la priorità e la logica di denominazione ---
    // Override la funzione uri() di ERC1155URIStorage
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(isValidTokenId[tokenId], "The provided tokenId is not supported");

        // Regola di priorità: Se esiste un customTokenURI per questo tokenId, usalo!
        if (bytes(customTokenURIs[tokenId]).length > 0) {
            return customTokenURIs[tokenId];
        }

        // Altrimenti: Torna alla baseURI standard della cartella per la compatibilità con OpenSea/MetaMask
        // Calcola il suffisso del nome del file JSON (es. 5, 10, ..., 100)
        uint256 fileSuffix = tokenId * 5; 
        return string(abi.encodePacked(baseURI, Strings.toString(fileSuffix), ".json"));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // --- Funzioni Owner per aggiornare baseURI, customTokenURIs, tokenCIDs ed encryptedURIs ---
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    // Funzione per impostare un URI specifico per i metadati di un TokenID
    // (Consente di bypassare la baseURI standard per singoli TokenID)
    function setCustomTokenURI(uint256 tokenId, string memory newURI) external onlyOwner {
        require(isValidTokenId[tokenId], "TokenId non valido");
        require(bytes(newURI).length > 0, "URI cannot be empty");
        customTokenURIs[tokenId] = newURI;
        emit TokenCIDUpdated(tokenId, newURI); // Riutilizzo dell'evento esistente per semplicità
    }

    // Funzione per impostare URI specifici per più TokenID in batch
    function setCustomTokenURIs(uint256[] calldata tokenIds, string[] calldata newURIs) external onlyOwner {
        require(tokenIds.length == newURIs.length, "Array length mismatch");
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            require(isValidTokenId[tokenIds[i]], "TokenId non valido");
            require(bytes(newURIs[i]).length > 0, "URI cannot be empty");
            customTokenURIs[tokenIds[i]] = newURIs[i];
        }
        emit TokenCIDsUpdated(tokenIds, newURIs); // Riutilizzo dell'evento esistente
    }

    // Mantengo le funzioni originali per tokenCIDs ed encryptedURIs dal tuo LHISA_LecceNFT.sol,
    // assumendo che possano avere scopi diversi dai metadati JSON gestiti da customTokenURIs.
    function setTokenCID(uint256 tokenId, string memory newCID) external onlyOwner {
        require(isValidTokenId[tokenId], "TokenId non valido");
        tokenCIDs[tokenId] = newCID;
        emit TokenCIDUpdated(tokenId, newCID);
    }

    function setTokenCIDs(uint256[] calldata tokenIds, string[] calldata newCIDs) external onlyOwner {
        require(tokenIds.length == newCIDs.length, "Array length mismatch");
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            require(isValidTokenId[tokenIds[i]], "TokenId non valido");
            tokenCIDs[tokenIds[i]] = newCIDs[i];
        }
        emit TokenCIDsUpdated(tokenIds, newCIDs);
    }

    function setEncryptedURI(uint256 tokenId, string memory newEncryptedURI) external onlyOwner {
        require(isValidTokenId[tokenId], "TokenId non valido");
        encryptedURIs[tokenId] = newEncryptedURI;
        emit EncryptedURIUpdated(tokenId, newEncryptedURI);
    }

    function setEncryptedURIs(uint256[] calldata tokenIds, string[] calldata newEncryptedURIs) external onlyOwner {
        require(tokenIds.length == newEncryptedURIs.length, "Array length mismatch");
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            require(isValidTokenId[tokenIds[i]], "TokenId non valido");
            encryptedURIs[tokenIds[i]] = newEncryptedURIs[i];
        }
        emit EncryptedURIsUpdated(tokenIds, newEncryptedURIs);
    }

    // --- Funzioni di lettura pubblica per trasparenza (Dal tuo LHISA_LecceNFT.sol) ---
    function getTokenCID(uint256 tokenId) public view returns (string memory) {
        return tokenCIDs[tokenId];
    }
    function getEncryptedURI(uint256 tokenId) public view returns (string memory) {
        return encryptedURIs[tokenId];
    }
    function getAllTokenCIDs() public view returns (string[] memory) {
        string[] memory cids = new string[](20); // Array size updated for BBTM's 20 TokenIDs
        uint256 idx = 0;
        for (uint256 i = 1; i <= 20; i++) { // Loop updated for BBTM's 20 TokenIDs
            cids[idx] = tokenCIDs[i];
            idx++; 
        }
        return cids;
    }
    function getAllEncryptedURIs() public view returns (string[] memory) {
        string[] memory uris = new string[](20); // Array size updated for BBTM's 20 TokenIDs
        uint256 idx = 0;
        for (uint256 i = 1; i <= 20; i++) { // Loop updated for BBTM's 20 TokenIDs
            uris[idx] = encryptedURIs[i];
            idx++; 
        }
        return uris;
    }

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    fallback() external payable {
        revert("Fallback not allowed");
    }
}
