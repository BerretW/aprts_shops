let currentShopId = null;
let gameItems = []; // Všechny itemy ve hře
let shopProducts = {}; // Nastavené ceny v tomto obchodě

window.addEventListener('message', function(event) {
    if (event.data.action === 'open') {
        $('#app').fadeIn(200);
        
        // Data ze serveru
        currentShopId = event.data.shopData.shop_id;
        shopProducts = event.data.shopData.products || {};
        gameItems = event.data.gameItems || [];

        // UI Update
        $('#shop-name').text(event.data.shopData.label);
        $('#shop-money').text(event.data.shopData.money);
        $('#shop-owner').text(event.data.shopData.owner || "Nikdo");

        // Admin tlačítka
        if (!event.data.isAdmin) {
            $('#admin-actions').hide();
        } else {
            $('#admin-actions').show();
        }

        // 1. Naplnit našeptávač (datalist) všemi itemy
        PopulateDatalist();

        // 2. Vykreslit tabulku již nastavených cen
        RenderConfiguredProducts();
    }
});

function SwitchTab(tabId) {
    $('.tab-content').hide();
    $('#' + tabId).show();
    $('.sidebar button').removeClass('active-tab');
    event.currentTarget.classList.add('active-tab');
}

function CloseUI() {
    $('#app').fadeOut(200);
    $.post('https://aprts_shops/close', JSON.stringify({}));
}

// Naplnění výběru itemů (Všech ve hře)
function PopulateDatalist() {
    const dataList = $('#all-items-datalist');
    dataList.empty();
    
    // Abychom nezahlitili DOM, omezíme to nebo přidáme vše, 
    // moderní prohlížeče zvládají tisíce items v datalistu celkem ok.
    gameItems.forEach(item => {
        // Value je jméno itemu, Label se zobrazí uživateli
        dataList.append(`<option value="${item.name}">${item.label}</option>`);
    });
}

// Funkce pro přidání nového itemu do ceníku
function AddNewItem() {
    const itemName = $('#new-item-input').val();
    const price = parseInt($('#new-item-price').val());

    if (!itemName || !price || price < 0) return;

    // Najdeme label itemu pro hezčí zobrazení
    const itemData = gameItems.find(i => i.name === itemName);
    if (!itemData) {
        // Pokud item neexistuje v databázi ox_inv (uživatel napsal blbost)
        // Můžeme povolit, ale bez labelu, nebo zamítnout. Zde povolíme.
    }

    // Odeslat na server
    $.post('https://aprts_shops/updatePrice', JSON.stringify({
        shopId: currentShopId,
        item: itemName,
        price: price
    }));

    // Lokální update (pro okamžitou odezvu)
    shopProducts[itemName] = { price: price };
    
    // Vyčistit inputy
    $('#new-item-input').val('');
    $('#new-item-price').val('');

    RenderConfiguredProducts();
}

// Vykreslení tabulky JEN s itemy, které mají nastavenou cenu
function RenderConfiguredProducts() {
    const list = $('#products-list');
    list.empty();

    // Iterujeme přes nastavené produkty (shopProducts)
    // shopProducts je objekt: { "water": {price: 10}, "bread": {price: 5} }
    
    Object.keys(shopProducts).forEach(itemName => {
        let price = shopProducts[itemName].price;
        
        // Zkusíme najít hezký název
        let itemLabel = itemName;
        let foundItem = gameItems.find(i => i.name === itemName);
        if (foundItem) itemLabel = foundItem.label;

        let row = `
            <tr>
                <td><b>${itemLabel}</b> <br><small style="color:#777">${itemName}</small></td>
                <td>$${price}</td>
                <td>
                    <button class="btn-danger" onclick="RemovePrice('${itemName}')">Odstranit</button>
                </td>
            </tr>
        `;
        list.append(row);
    });
}

// Odstranění itemu z ceníku (cena 0 nebo smazat klíč)
function RemovePrice(itemName) {
    delete shopProducts[itemName]; // Lokální smazání
    RenderConfiguredProducts(); // Překreslit

    // Serveru pošleme cenu 0 nebo null, logika na serveru by to měla smazat
    // V naší serverové logice jen updatujeme JSON, tak tam pošleme update.
    // Aby to bylo čisté, pošleme delete flag nebo prostě update celého pole, 
    // ale pro zachování struktury "updatePrice" pošleme např -1 a server to smaže, nebo prostě update.
    
    // Zde jednoduše pošleme update s cenou 0 (nebo to můžeme ošetřit na serveru jako smazání)
    // Pro tento příklad, updatePrice přepíše hodnotu.
    // Ideálně by server měl mít "removeItem", ale použijeme existující event:
    
    // POZOR: Pokud chceš item úplně smazat z DB, je lepší to udělat takto:
    $.post('https://aprts_shops/updatePrice', JSON.stringify({
        shopId: currentShopId,
        item: itemName,
        price: null // Null signalizuje smazání
    }));
}

function WithdrawMoney() {
    $.post('https://aprts_shops/withdraw', JSON.stringify({shopId: currentShopId}));
}

function SaveSettings() {
    const newName = $('#new-shop-name').val();
    $.post('https://aprts_shops/updateSettings', JSON.stringify({
        shopId: currentShopId,
        label: newName
    }));
}

function AdminDeleteShop() {
    $.post('https://aprts_shops/deleteShop', JSON.stringify({shopId: currentShopId}));
    CloseUI();
}

// Admin Callbacks
RegisterNUICallback('close', function(data, cb) { SetNuiFocus(false, false); cb('ok'); });