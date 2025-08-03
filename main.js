// Main.js - Big Brother The Musical Web3 Interface
// This file contains the main JavaScript functionality for the BBTM NFT interface

// Global variables for euro price management
let currentEuroPrice = 1.0; // Default EUR/POL rate, easily updatable
let currentRating = 0; // Current star rating
let comments = []; // Array to store comments

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('Big Brother The Musical interface loaded');
    initializeTokenTable();
    initializeCommentSystem();
    populateTokenTable();
});

// Initialize token value table with calculations
function initializeTokenTable() {
    console.log('Initializing token table with current euro price:', currentEuroPrice);
    const euroInput = document.getElementById('euro-price-input');
    if (euroInput) {
        euroInput.value = currentEuroPrice.toFixed(2);
    }
}

// Populate the token table with all 20 tokens
function populateTokenTable() {
    const tableBody = document.getElementById('token-table-body');
    if (!tableBody) return;
    
    tableBody.innerHTML = ''; // Clear existing content
    
    for (let tokenId = 1; tokenId <= 20; tokenId++) {
        const bbtmValue = tokenId * 5;
        const polValue = bbtmValue; // 1:1 ratio
        const euroValue = polValue * currentEuroPrice;
        const weiValue = BigInt(bbtmValue) * BigInt(10**18);
        
        const row = document.createElement('tr');
        row.innerHTML = `
            <td><strong>${tokenId}</strong></td>
            <td>${bbtmValue} BBTM</td>
            <td>${polValue} POL</td>
            <td id="euro-${tokenId}">€${euroValue.toFixed(2)}</td>
            <td>${weiValue.toString()}</td>
        `;
        tableBody.appendChild(row);
    }
}

// Initialize comment and rating system
function initializeCommentSystem() {
    console.log('Initializing comment and rating system');
    
    // Setup star rating functionality
    const stars = document.querySelectorAll('.star');
    stars.forEach(star => {
        star.addEventListener('click', function() {
            const rating = parseInt(this.getAttribute('data-rating'));
            setRating(rating);
        });
        
        star.addEventListener('mouseover', function() {
            const rating = parseInt(this.getAttribute('data-rating'));
            highlightStars(rating);
        });
    });
    
    // Reset stars on mouse leave
    const starContainer = document.getElementById('star-rating');
    if (starContainer) {
        starContainer.addEventListener('mouseleave', function() {
            highlightStars(currentRating);
        });
    }
    
    // Load existing comments from localStorage
    loadComments();
    displayComments();
}

// Set the current rating
function setRating(rating) {
    currentRating = rating;
    highlightStars(rating);
    updateRatingDisplay();
}

// Highlight stars up to the given rating
function highlightStars(rating) {
    const stars = document.querySelectorAll('.star');
    stars.forEach((star, index) => {
        if (index < rating) {
            star.classList.add('active');
            star.textContent = '★';
        } else {
            star.classList.remove('active');
            star.textContent = '☆';
        }
    });
}

// Update rating display text
function updateRatingDisplay() {
    const display = document.getElementById('rating-display');
    if (display) {
        if (currentRating > 0) {
            display.textContent = `${currentRating} stella${currentRating > 1 ? 'e' : ''}`;
        } else {
            display.setAttribute('data-key', 'no_rating');
            display.textContent = 'Nessuna valutazione';
        }
    }
}

// Function to update euro prices throughout the interface
function updateEuroPrices(newEuroPrice) {
    if (typeof newEuroPrice === 'number' && newEuroPrice > 0) {
        currentEuroPrice = newEuroPrice;
        console.log('Euro price updated to:', currentEuroPrice);
        recalculateTokenValues();
    } else {
        console.error('Invalid euro price provided:', newEuroPrice);
        alert('Inserire un prezzo valido maggiore di 0');
    }
}

// Recalculate all token values based on current euro price
function recalculateTokenValues() {
    // Update all token value displays
    for (let tokenId = 1; tokenId <= 20; tokenId++) {
        const bbtmValue = tokenId * 5;
        const polValue = bbtmValue; // 1:1 ratio
        const euroValue = polValue * currentEuroPrice;
        
        // Update table cells
        updateTokenRowDisplay(tokenId, euroValue);
    }
}

// Update individual token row display
function updateTokenRowDisplay(tokenId, euroValue) {
    const euroCell = document.getElementById(`euro-${tokenId}`);
    if (euroCell) {
        euroCell.textContent = `€${euroValue.toFixed(2)}`;
    }
}

// Submit a comment
function submitComment() {
    const commentText = document.getElementById('comment-text');
    if (!commentText) return;
    
    const text = commentText.value.trim();
    if (text === '') {
        alert('Inserire un commento prima di inviare');
        return;
    }
    
    const comment = {
        id: Date.now(),
        text: text,
        rating: currentRating,
        timestamp: new Date().toLocaleString('it-IT')
    };
    
    comments.unshift(comment); // Add to beginning of array
    saveComments();
    displayComments();
    
    // Reset form
    commentText.value = '';
    setRating(0);
    
    alert('Commento inviato con successo!');
}

// Save comments to localStorage
function saveComments() {
    localStorage.setItem('bbtm_comments', JSON.stringify(comments));
}

// Load comments from localStorage
function loadComments() {
    const saved = localStorage.getItem('bbtm_comments');
    if (saved) {
        try {
            comments = JSON.parse(saved);
        } catch (e) {
            console.error('Error loading comments:', e);
            comments = [];
        }
    }
}

// Display all comments
function displayComments() {
    const commentsList = document.getElementById('comments-list');
    if (!commentsList) return;
    
    if (comments.length === 0) {
        commentsList.innerHTML = '<p style="text-align: center; color: #666;">Nessun commento ancora. Sii il primo a commentare!</p>';
        return;
    }
    
    commentsList.innerHTML = comments.map(comment => `
        <div class="comment-item">
            ${comment.rating > 0 ? `<div class="comment-rating">${'★'.repeat(comment.rating)}${'☆'.repeat(5 - comment.rating)}</div>` : ''}
            <div class="comment-text">${escapeHtml(comment.text)}</div>
            <div class="comment-timestamp">${comment.timestamp}</div>
        </div>
    `).join('');
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Export functions for global access
window.updateEuroPrices = updateEuroPrices;
window.currentEuroPrice = currentEuroPrice;
window.submitComment = submitComment;