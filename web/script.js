// Globální proměnné
let currentShopId = null;
let shopProducts = {};
let availableInventory = []; 
let isAdmin = false;
let selectedDepositItem = null;

window.addEventListener('message', function(event) {
    let data = event.data;

    // DEBUG: Vypíše do F8 konzole, co přesně přišlo
    if(data.action) {
        console.log(`[JS DEBUG] Akce: ${data.action}`);
    }

    // 1. OTEVŘENÍ MANAGEMENTU
    if (data.action === 'open') {
        $('#management-app').fadeIn(200).css('display', 'flex');
        $('#buyer-app').hide();

        currentShopId = data.shopData.shop_id;
        shopProducts = data.shopData.products || {};
        
        // ZDE JE OPRAVA: Bere to buď 'inventory' nebo 'inventoryItems'
        availableInventory = data.inventory || data.inventoryItems || [];
        isAdmin = data.isAdmin;
        let settings = data.shopData.settings || { blipSprite: 52, blipColor: 2, openHour: 0, closeHour: 24 };
        
        $('#blip-sprite').val(settings.blipSprite);
        $('#blip-color').val(settings.blipColor);
        $('#open-hour').val(settings.openHour);
        $('#close-hour').val(settings.closeHour);
        console.log(`[JS DEBUG] Počet itemů v inventáři pro vklad: ${availableInventory.length}`);
        
        // Update textů
        $('#shop-name-display').text(data.shopData.label);
        $('#new-shop-name').val(data.shopData.label);
        $('#shop-money').text(data.shopData.money.toLocaleString());
        $('#shop-owner').text(data.shopData.owner ? data.shopData.owner : "Admin / Nikdo");

        if (!isAdmin) $('#admin-actions').hide();
        else $('#admin-actions').show();

        // Inicializace
        SwitchTab('products');
        SwitchProductView('stock');
        RenderConfiguredProducts();
        RenderInventoryForDeposit();

    // 2. OTEVŘENÍ NÁKUPNÍHO KOŠÍKU (ZÁKAZNÍK)
    } else if (data.action === 'openBuyer') {
        $('#buyer-app').fadeIn(200).css('display', 'flex');
        $('#management-app').hide();
        
        currentShopId = data.shopId;
        $('#buyer-shop-title').text(data.shopLabel);
        
        RenderBuyerItems(data.items);
    }
});

// Zavření klávesou ESC
document.onkeyup = function(data) {
    if (data.key === "Escape") {
        CloseUI();
    }
};

function CloseUI() {
    $('#management-app').fadeOut(200);
    $('#buyer-app').fadeOut(200);
    $.post('https://aprts_shops/close', JSON.stringify({}));
}

// ==============================================
// LOGIKA MANAGEMENTU
// ==============================================

function SwitchTab(tabId) {
    $('.tab-content').hide();
    $('#' + tabId).show();
    $('.sidebar button').removeClass('active-tab');
    $('#btn-' + tabId).addClass('active-tab');
}

function SwitchProductView(view) {
    $('#view-stock').hide();
    $('#view-deposit').hide();
    $('#view-' + view).fadeIn(100);
    
    $('.sub-nav button').removeClass('active-sub');
    $('#sub-btn-' + view).addClass('active-sub');
    
    $('#deposit-settings').hide();
    selectedDepositItem = null;
}

// Vykreslení aktuálního skladu (co už v obchodě je)
function RenderConfiguredProducts() {
    const list = $('#products-list');
    list.empty();

    if (Object.keys(shopProducts).length === 0) {
        list.append('<tr><td colspan="4" style="text-align:center; color:#777; padding: 20px;">Obchod je prázdný. Přejdi na "Vložit zboží".</td></tr>');
        return;
    }

    Object.keys(shopProducts).forEach(itemName => {
        let prod = shopProducts[itemName];
        let stockDisplay = prod.infinite ? '<span style="color:#4dabf7; font-weight:bold;">∞ (Admin)</span>' : prod.count + ' ks';
        
        let label = itemName;
        // Zkusíme najít label
        let found = availableInventory.find(i => i.name === itemName);
        if(found) label = found.label;

        let row = `
            <tr>
                <td><strong>${label}</strong><br><small style="color:#666">${itemName}</small></td>
                <td>${stockDisplay}</td>
                <td style="color:#69db7c;">$${prod.price}</td>
                <td style="text-align: right;">
                    <button class="btn-sm-danger" onclick="RemoveProduct('${itemName}')">
                        <i class="fa-solid fa-arrow-right-from-bracket"></i> Vybrat
                    </button>
                </td>
            </tr>
        `;
        list.append(row);
    });
}

// Vykreslení inventáře pro vklad (GRID)
function RenderInventoryForDeposit() {
    const grid = $('#inventory-grid');
    grid.empty();
    
    // DEBUG: Kontrola při vykreslování
    if (!availableInventory || availableInventory.length === 0) {
        console.log("[JS DEBUG] Pole availableInventory je prázdné!");
        grid.html('<div style="grid-column:1/-1; text-align:center; padding: 20px;">Seznam itemů je prázdný. (Jsi Admin: '+isAdmin+')</div>');
        return;
    }

    availableInventory.forEach(item => {
        // Ignorujeme itemy s count < 1 (pokud nejsme admin v režimu generování)
        // Podle tvého JSONu máš všude count 9999, takže to projde.
        if(item.name === 'money') return;

        let imgUrl = `nui://ox_inventory/web/images/${item.name}.png`;
        let countDisplay = isAdmin ? '<span class="inv-count">∞</span>' : `<span class="inv-count">${item.count}x</span>`;

        let card = `
            <div class="inv-card" onclick="SelectDepositItem('${item.name}', '${item.label.replace(/'/g, "")}', ${item.count})">
                <img src="${imgUrl}" onerror="this.src='https://via.placeholder.com/60?text=?'">
                <div class="inv-info">
                    <span class="inv-name" title="${item.label}">${item.label}</span>
                    ${countDisplay}
                </div>
            </div>
        `;
        grid.append(card);
    });
}

function FilterInventory() {
    let term = $('#inventory-search').val().toLowerCase();
    $('.inv-card').each(function() {
        let text = $(this).text().toLowerCase();
        $(this).toggle(text.indexOf(term) > -1);
    });
}

function SelectDepositItem(name, label, maxCount) {
    selectedDepositItem = { name: name, label: label, max: maxCount };
    
    $('#deposit-settings').fadeIn(200);
    $('#deposit-item-name').text(label);
    
    // Reset
    $('#deposit-count').val(1).attr('max', maxCount);
    
    if(shopProducts[name]) {
        $('#deposit-price').val(shopProducts[name].price);
    } else {
        $('#deposit-price').val('');
    }
    
    if(isAdmin) {
        $('#max-deposit').text("Nekonečno");
        $('#deposit-count').parent().hide();
    } else {
        $('#max-deposit').text(maxCount);
        $('#deposit-count').parent().show();
    }
}

function ConfirmDeposit() {
    if(!selectedDepositItem) return;

    let count = parseInt($('#deposit-count').val());
    let price = parseInt($('#deposit-price').val());

    if(!price || price < 0) return;

    // Admin neřeší počet (posíláme 9999 nebo cokoliv, server to přepíše na infinite)
    if(!isAdmin && (count < 1 || count > selectedDepositItem.max)) return;

    $.post('https://aprts_shops/updatePrice', JSON.stringify({
        shopId: currentShopId,
        item: selectedDepositItem.name,
        count: count,
        price: price
    }));

    // Optimistický update UI
    if(!shopProducts[selectedDepositItem.name]) {
        shopProducts[selectedDepositItem.name] = { count: 0, price: price, infinite: isAdmin };
    }
    
    if(isAdmin) {
        shopProducts[selectedDepositItem.name].infinite = true;
    } else {
        shopProducts[selectedDepositItem.name].count += count;
        // Odečíst z lokálního inventáře, aby uživatel neklikal víckrát na to samé
        let localItem = availableInventory.find(i => i.name === selectedDepositItem.name);
        if(localItem) localItem.count -= count;
    }
    shopProducts[selectedDepositItem.name].price = price;

    RenderConfiguredProducts();
    RenderInventoryForDeposit();
    
    $('#deposit-settings').hide();
    SwitchProductView('stock');
}

function RemoveProduct(itemName) {
    $.post('https://aprts_shops/updatePrice', JSON.stringify({
        shopId: currentShopId,
        item: itemName,
        remove: true
    }));
    
    delete shopProducts[itemName];
    RenderConfiguredProducts();
}

function WithdrawMoney() {
    $.post('https://aprts_shops/withdraw', JSON.stringify({shopId: currentShopId}));
    $('#shop-money').text('0');
}

function SaveSettings() {
    const newName = $('#new-shop-name').val();
    const blipSprite = $('#blip-sprite').val();
    const blipColor = $('#blip-color').val();
    const openHour = $('#open-hour').val();
    const closeHour = $('#close-hour').val();

    // Validace, aby tam hráč neměl název, pokud ho nechce měnit (necháme starý v inputu, nebo pošleme prázdný a server to pořeší, ale lepší je poslat aktuální)
    // V HTML inputu '#new-shop-name' máme aktuální název, takže:
    
    $.post('https://aprts_shops/updateSettings', JSON.stringify({
        shopId: currentShopId,
        label: newName,
        blipSprite: blipSprite,
        blipColor: blipColor,
        openHour: openHour,
        closeHour: closeHour
    }));
    
    // UI Update textu
    $('#shop-name-display').text(newName);
}

function AdminDeleteShop() {
    $.post('https://aprts_shops/deleteShop', JSON.stringify({shopId: currentShopId}));
    CloseUI();
}

// ==============================================
// LOGIKA ZÁKAZNÍKA (BUYER)
// ==============================================

function RenderBuyerItems(items) {
    const grid = $('#buyer-items-grid');
    grid.empty();

    if (!items || items.length === 0) {
        grid.html('<div style="width:100%; text-align:center; color:#777; grid-column: 1 / -1;">Obchod je momentálně prázdný.</div>');
        return;
    }

    items.forEach(item => {
        let imgUrl = `nui://ox_inventory/web/images/${item.name}.png`;
        
        let card = `
            <div class="product-card">
                <div class="img-wrapper">
                    <img src="${imgUrl}" alt="${item.label}" 
                         onerror="this.onerror=null; this.src='https://via.placeholder.com/100?text=?'">
                </div>
                <div class="product-info">
                    <span class="product-name" title="${item.label}">${item.label}</span>
                    <span class="product-price">$${item.price}</span>
                </div>
                <div class="buy-controls">
                    <button class="qty-btn" onclick="AdjustQty('${item.name}', -1)">-</button>
                    <input type="number" id="qty-${item.name}" value="1" min="1" class="qty-input" onchange="ValidateQty(this)">
                    <button class="qty-btn" onclick="AdjustQty('${item.name}', 1)">+</button>
                </div>
                <button class="buy-btn" onclick="BuyItem('${item.name}')">
                    <i class="fa-solid fa-cart-shopping"></i> Koupit
                </button>
            </div>
        `;
        grid.append(card);
    });
}

function AdjustQty(itemName, change) {
    const input = $(`#qty-${itemName}`);
    let val = parseInt(input.val());
    val += change;
    if (val < 1) val = 1;
    input.val(val);
}

function ValidateQty(input) {
    if (input.value < 1) input.value = 1;
}

function BuyItem(itemName) {
    const qtyInput = $(`#qty-${itemName}`);
    const amount = parseInt(qtyInput.val());
    if (!amount || amount < 1) return;

    $.post('https://aprts_shops/buyItem', JSON.stringify({
        shopId: currentShopId,
        item: itemName,
        count: amount
    }));
}