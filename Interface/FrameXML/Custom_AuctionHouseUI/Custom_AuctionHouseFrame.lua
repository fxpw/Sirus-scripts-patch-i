
local MaxNumActiveBidsTracked = 100;

UIPanelWindows["AuctionHouseFrame"] = { area = "doublewide", pushable = 0, xoffset = "20", yoffset = "0" };

StaticPopupDialogs["AUCTIONHOUSE_BUYOUT_AUCTION"] = {
	text = BUYOUT_AUCTION_CONFIRMATION,
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
		C_AuctionHouse.PlaceBid(self.data.auctionID, self.data.buyout);
	end,
	OnShow = function(self)
		MoneyFrame_Update(self.moneyFrame, self.data.buyout);
	end,
	hasMoneyFrame = 1,
	showAlert = 1,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

StaticPopupDialogs["AUCTIONHOUSE_BID_AUCTION"] = {
	text = BID_AUCTION_CONFIRMATION,
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
		C_AuctionHouse.PlaceBid(self.data.auctionID, self.data.bid);
	end,
	OnShow = function(self)
		MoneyFrame_Update(self.moneyFrame, self.data.bid);
	end,
	hasMoneyFrame = 1,
	showAlert = 1,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

StaticPopupDialogs["AUCTIONHOUSE_CANCEL_AUCTION"] = {
	text = CANCEL_AUCTION_CONFIRMATION,
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
		C_AuctionHouse.CancelAuction(self.data.auctionID);
	end,
	OnShow = function(self)
		local cancelCost = C_AuctionHouse.GetCancelCost(self.data.auctionID);
		MoneyFrame_Update(self.moneyFrame, cancelCost);
		if cancelCost > 0 then
			self.text:SetText(CANCEL_AUCTION_CONFIRMATION_MONEY);
		else
			self.text:SetText(CANCEL_AUCTION_CONFIRMATION);
		end
	end,
	hasMoneyFrame = 1,
	showAlert = 1,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

AUCTION_HOUSE_STATIC_POPUPS = {
	"AUCTIONHOUSE_BUYOUT_AUCTION",
	"AUCTIONHOUSE_BID_AUCTION",
	"AUCTIONHOUSE_CANCEL_AUCTION",
};


local AuctionHouseSortVersion = 2;
local MaxNumAuctionHouseSortTypes = 2;

AuctionHouseSortOrderState = tInvert({
	"None",
	"PrimarySorted",
	"PrimaryReversed",
	"Sorted",
	"Reversed",
});


local function InitAuctionHouseSortsBySearchContext()
	-- If the sort version couldn't be updated, do a clean reset.
	if g_auctionHouseSortsBySearchContext == nil or g_auctionHouseSortsBySearchContext.auctionHouseSortVersion ~= AuctionHouseSortVersion then
		g_auctionHouseSortsBySearchContext = { auctionHouseSortVersion = AuctionHouseSortVersion };

		local browseContexts = {
			[AuctionHouseSearchContext.BrowseAll] = true,
			[AuctionHouseSearchContext.BrowseWeapons] = true,
			[AuctionHouseSearchContext.BrowseArmor] = true,
			[AuctionHouseSearchContext.BrowseContainers] = true,
			[AuctionHouseSearchContext.BrowseConsumables] = true,
			[AuctionHouseSearchContext.BrowseGlpyhs] = true,
			[AuctionHouseSearchContext.BrowseTradeGoods] = true,
			[AuctionHouseSearchContext.BrowseAmmo] = true,
			[AuctionHouseSearchContext.BrowseQuiver] = true,
			[AuctionHouseSearchContext.BrowseRecipes] = true,
			[AuctionHouseSearchContext.BrowseGems] = true,
			[AuctionHouseSearchContext.BrowseMiscellaneous] = true,
			[AuctionHouseSearchContext.BrowseQuestItems] = true,
			[AuctionHouseSearchContext.AllFavorites] = true,
		};

		local itemContexts = {
			[AuctionHouseSearchContext.BuyItems] = true,
			[AuctionHouseSearchContext.SellItems] = true,
			[AuctionHouseSearchContext.AuctionsItems] = true,
			[AuctionHouseSearchContext.BidItems] = true,
		};

		local ownedContexts = {
			[AuctionHouseSearchContext.AllAuctions] = true,
			[AuctionHouseSearchContext.AllBids] = true,
		};

		for i, searchContext in pairs(AuctionHouseSearchContext) do
			g_auctionHouseSortsBySearchContext[searchContext] = {};

			if browseContexts[searchContext] then
				g_auctionHouseSortsBySearchContext[searchContext][1] = { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false };
				g_auctionHouseSortsBySearchContext[searchContext][2] = { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false };
			elseif itemContexts[searchContext] then
				g_auctionHouseSortsBySearchContext[searchContext][1] = { sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false };
				g_auctionHouseSortsBySearchContext[searchContext][2] = { sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false };
			elseif ownedContexts[searchContext] then
				g_auctionHouseSortsBySearchContext[searchContext][1] = { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false };
				g_auctionHouseSortsBySearchContext[searchContext][2] = { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false };
			end
		end
	end
end

local function AddSortType(searchContext, newSortType)
	if not g_auctionHouseSortsBySearchContext[searchContext] then
		g_auctionHouseSortsBySearchContext[searchContext] = {};
	end

	local sorts = g_auctionHouseSortsBySearchContext[searchContext];
	for i, sortType in ipairs(sorts) do
		if sortType.sortOrder == newSortType.sortOrder then
			if (i == 1) and sortType.reverseSort == newSortType.reverseSort then
				newSortType.reverseSort = not newSortType.reverseSort;
			end

			table.remove(sorts, i);
			break;
		end
	end

	table.insert(sorts, 1, newSortType);

	if #sorts > MaxNumAuctionHouseSortTypes then
		sorts[#sorts] = nil;
	end
end

local function GetSortTypes(searchContext)
	return g_auctionHouseSortsBySearchContext[searchContext] or {};
end

local function GetSortOrderState(searchContext, sortOrder)
	local sorts = g_auctionHouseSortsBySearchContext[searchContext];
	if not sorts then
		return AuctionHouseSortOrderState.None;
	end

	for i, sortType in ipairs(sorts) do
		if sortType.sortOrder == sortOrder then
			if sortType.reverseSort then
				return (i == 1) and AuctionHouseSortOrderState.PrimaryReversed or AuctionHouseSortOrderState.Reversed;
			else
				return (i == 1) and AuctionHouseSortOrderState.PrimarySorted or AuctionHouseSortOrderState.Sorted;
			end
		end
	end

	return AuctionHouseSortOrderState.None;
end

local function AreSortTypesLoaded()
	return g_auctionHouseSortsBySearchContext ~= nil;
end


local function InitBidLists()
	g_outbidAuctionIDs = {};
end

local function UpdateBidLists()
	-- Mark all active bids as outbid. We'll reset the mark on auctions that we have an active bid on.
	for i = 1, #g_activeBidAuctionIDs do
		local auctionID = g_activeBidAuctionIDs[i];
		g_outbidAuctionIDs[auctionID] = true;
	end

	g_activeBidAuctionIDs = {};
	for i = 1, C_AuctionHouse.GetNumBids() do
		local bid = C_AuctionHouse.GetBidInfo(i);
		local auctionID = bid.auctionID;

		if #g_activeBidAuctionIDs < MaxNumActiveBidsTracked then
			table.insert(g_activeBidAuctionIDs, auctionID);
		end

		if bid.bidder and bid.bidder == UnitName("player") then
			g_outbidAuctionIDs[auctionID] = nil;
		end
	end
end

local function HasBeenOutbid(auctionID)
	return g_outbidAuctionIDs[auctionID];
end

local function GetActiveBidList()
	return g_activeBidAuctionIDs;
end


AuctionHouseFrameMixin = CreateFromMixins(CallbackRegistryMixin);

AuctionHouseFrameMixin:GenerateCallbackEvents(
{
	"CategorySelected",
	"CommoditiesQuantitySelectionChanged",
	"BrowseSearchStarted",
});

local AUCTION_HOUSE_FRAME_EVENTS = {
	"PLAYER_MONEY",
};

local AUCTION_HOUSE_FRAME_CUSTOM_EVENTS = {
	"ITEM_SEARCH_RESULTS_ADDED",
	"ITEM_SEARCH_RESULTS_UPDATED",
	"COMMODITY_SEARCH_RESULTS_ADDED",
	"COMMODITY_SEARCH_RESULTS_UPDATED",
	"BIDS_UPDATED",
	"BID_ADDED",
	"OWNED_AUCTIONS_UPDATED",
};

local function AuctionHouseFrame_GenerateMaxWidthFunction(self, cacheName, maxPriceFunction, key)
	if key then
		local function GetMaxWidth(self, fontObject)
			local cache = self[cacheName];
			local cacheByKey = cache[key];

			return (cacheByKey and cacheByKey[fontObject]) or self:GetMaxPriceWidth(cache, key, fontObject, maxPriceFunction());
		end

		return GetMaxWidth;
	else
		local function GetMaxWidth(self, itemKey, fontObject)
			local cache = self[cacheName];

			-- We should only have display item results for a single itemKey at once.
			local cacheKey = "SearchResults";
			local cacheByKey = cache[cacheKey];
			return (cacheByKey and cacheByKey[fontObject]) or self:GetMaxPriceWidth(cache, cacheKey, fontObject, maxPriceFunction(itemKey));
		end

		return GetMaxWidth;
	end
end

local MaxWidthArguments = {
	GetMaxBidWidth 							= { "maxBidPriceWidth", C_AuctionHouse.GetMaxItemSearchResultBid, };
	GetMaxBidPriceWidthForAllAuctions 		= { "maxBidPriceWidth", C_AuctionHouse.GetMaxOwnedAuctionBid, "AllAuctions" };
	GetMaxBidPriceWidthForAllBids 			= { "maxBidPriceWidth", C_AuctionHouse.GetMaxBidItemBid, "AllBids" };
	GetMaxBuyoutWidth 						= { "maxBuyoutPriceWidth", C_AuctionHouse.GetMaxItemSearchResultBuyout };
	GetMaxBuyoutPriceWidthForAllAuctions 	= { "maxBuyoutPriceWidth", C_AuctionHouse.GetMaxOwnedAuctionBuyout, "AllAuctions" };
	GetMaxBuyoutPriceWidthForAllBids 		= { "maxBuyoutPriceWidth", C_AuctionHouse.GetMaxBidItemBuyout, "AllBids" };
	GetMaxUnitPriceWidth 					= { "maxUnitPriceWidth", C_AuctionHouse.GetMaxCommoditySearchResultPrice };
};

function AuctionHouseFrameMixin:OnLoad()
	self.MoneyFrameInset:SetFrameLevel(self:GetFrameLevel());

	CallbackRegistryMixin.OnLoad(self);

	self.activeSearches = {};

	self.maxBidPriceWidth = {};
	self.maxBuyoutPriceWidth = {};
	self.maxUnitPriceWidth = {};

	for functionName, arguments in pairs(MaxWidthArguments) do
		self[functionName] = AuctionHouseFrame_GenerateMaxWidthFunction(self, unpack(arguments));
	end

	PanelTemplates_SetNumTabs(self, #self.Tabs);

	self.tabsForDisplayMode = {};
	for i, tab in ipairs(self.Tabs) do
		self.tabsForDisplayMode[AuctionHouseFrameDisplayMode[tab:GetAttribute("displayMode")]] = i;

		if tab == self.SellTab then
			self.tabsForDisplayMode[AuctionHouseFrameDisplayMode.CommoditiesSell] = i;
		end
	end
end

function AuctionHouseFrameMixin:OnShow()
	if BankFrame:IsShown() then
		HideUIPanel(BankFrame);
	end

	if not self.isLoadded then
		InitAuctionHouseSortsBySearchContext();
		InitBidLists();

		-- We need to query bids to properly show outbid indicators.
		self:QueryAll(AuctionHouseSearchContext.AllBids);
		self.isLoadded = true;
	end

	FrameUtil.RegisterFrameForEvents(self, AUCTION_HOUSE_FRAME_EVENTS);
	FrameUtil.RegisterFrameForCustomEvents(self, AUCTION_HOUSE_FRAME_CUSTOM_EVENTS);

	self:SetPortraitToUnit("target");

	self:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy);

	self:UpdateMoneyFrame();

	if C_AuctionHouse.HasFavorites() then
		self:QueryAll(AuctionHouseSearchContext.AllFavorites);
	end

	PlaySound("AuctionWindowOpen");
end

function AuctionHouseFrameMixin:OnEvent(event, ...)
	if event == "PLAYER_MONEY" then
		self:UpdateMoneyFrame();
	elseif event == "ITEM_SEARCH_RESULTS_ADDED" or event == "ITEM_SEARCH_RESULTS_UPDATED" or
			event == "OWNED_AUCTIONS_UPDATED" or event == "BIDS_UPDATED" or event == "BID_ADDED" then
		-- Clear the cached values.
		self:ClearMaxWidthCaches();

		if event == "BIDS_UPDATED" then
			UpdateBidLists();
		end
	elseif event == "COMMODITY_SEARCH_RESULTS_ADDED" or event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
		-- Clear the cached values.
		self.maxUnitPriceWidth = {};
	end
end

function AuctionHouseFrameMixin:OnHide()
	FrameUtil.UnregisterFrameForEvents(self, AUCTION_HOUSE_FRAME_EVENTS);
	FrameUtil.UnregisterFrameForCustomEvents(self, AUCTION_HOUSE_FRAME_CUSTOM_EVENTS);

	AuctionHouseMultisellProgressFrame:Hide();

	self.BrowseResultsFrame:Reset();

	self:ClearPostItem();

	C_AuctionHouse.CloseAuctionHouse();

	self:CloseStaticPopups();

	if GetAuctionSellItemInfo() then
		ClearCursor();
		ClickAuctionSellItemButton();
		ClearCursor();
	end

	PlaySound("AuctionWindowClose")
end

function AuctionHouseFrameMixin:CloseStaticPopups()
	for i, popup in ipairs(AUCTION_HOUSE_STATIC_POPUPS) do
		if StaticPopup_Visible(popup) then
			StaticPopup_Hide(popup);
		end
	end
end

function AuctionHouseFrameMixin:ClearMaxWidthCaches()
	self.maxBidPriceWidth = {};
	self.maxBuyoutPriceWidth = {};
	self.maxUnitPriceWidth = {};
end

function AuctionHouseFrameMixin:UpdateMoneyFrame()
	self.MoneyFrameBorder.MoneyFrame:SetAmount(GetMoney());
end

AuctionHouseFrameDisplayMode = {
	Buy = {
		"CategoriesList",
		"SearchBar",
		"BrowseResultsFrame",
	},

	CommoditiesBuy = {
		"CategoriesList",
		"SearchBar",
		"CommoditiesBuyFrame",
	},

	ItemBuy = {
		"CategoriesList",
		"SearchBar",
		"ItemBuyFrame",
	},

	CommoditiesSell = {
		"CommoditiesSellFrame",
		"CommoditiesSellList",
	},

	ItemSell = {
		"ItemSellFrame",
		"ItemSellList",
	},

	Auctions = {
		"AuctionsFrame",
	},
};

AuctionHouseFrameDialogs = {
	"BuyDialog",
};

AuctionHouseFramePopups = {
	"AUCTIONHOUSE_BID_AUCTION",
	"AUCTIONHOUSE_BUYOUT_AUCTION",
	"AUCTIONHOUSE_CANCEL_AUCTION",
};

function AuctionHouseFrameMixin:SetDisplayMode(displayMode)
	-- If we have an active post item, show that display.
	if displayMode == AuctionHouseFrameDisplayMode.ItemSell or
		displayMode == AuctionHouseFrameDisplayMode.CommoditiesSell then

		if self.ItemSellFrame:GetItem() then
			displayMode = AuctionHouseFrameDisplayMode.ItemSell;
		elseif self.CommoditiesSellFrame:GetItem() then
			displayMode = AuctionHouseFrameDisplayMode.CommoditiesSell;
		end
	end

	if self.displayMode == displayMode then
		return;
	end

	self.displayMode = displayMode;

	local subframesToUpdate = {};
	for displayModeName, mode in pairs(AuctionHouseFrameDisplayMode) do
		for j, subframe in ipairs(mode) do
			subframesToUpdate[subframe] = subframesToUpdate[subframe] or mode == displayMode;
		end
	end

	for subframe, shouldShow in pairs(subframesToUpdate) do
		if not shouldShow then
			self[subframe]:Hide();
		end
	end

	for i = 1, #displayMode do
		local subFrame = displayMode[i];
		self[subFrame]:Show();
	end

	local tab = self.tabsForDisplayMode[displayMode];
	if tab then
		PanelTemplates_SetTab(self, tab);
		self:UpdateTitle();
	end

	for i, dialogName in ipairs(AuctionHouseFrameDialogs) do
		self[dialogName]:Hide();
	end

	for i, popup in ipairs(AuctionHouseFramePopups) do
		StaticPopup_Hide(popup);
	end
end

function AuctionHouseFrameMixin:GetDisplayMode()
	return self.displayMode;
end

function AuctionHouseFrameMixin:IsListingAuctions()
	local displayMode = self:GetDisplayMode();
	return displayMode == AuctionHouseFrameDisplayMode.ItemSell or displayMode == AuctionHouseFrameDisplayMode.CommoditiesSell;
end

function AuctionHouseFrameMixin:SetPostItem(itemLocation)
	local isValid = itemLocation and itemLocation:IsValid();
	if not isValid or not C_AuctionHouse.IsSellItemValid(itemLocation) or AuctionHouseMultisellProgressFrame:IsShown() then
		return;
	end

	local itemCommodityStatus = C_AuctionHouse.GetItemCommodityStatus(itemLocation);
	if itemCommodityStatus == Enum.ItemCommodityStatus.Unknown then
		return; -- No item data, bail out.
	end

	self:ClearPostItem();

	if itemCommodityStatus == Enum.ItemCommodityStatus.Commodity then
		self:SetDisplayMode(AuctionHouseFrameDisplayMode.CommoditiesSell);
		self.CommoditiesSellFrame:SetItem(itemLocation);
		self.CommoditiesSellList:SetItemID(isValid);
	elseif itemCommodityStatus == Enum.ItemCommodityStatus.Item then
		self:SetDisplayMode(AuctionHouseFrameDisplayMode.ItemSell);
		self.ItemSellFrame:SetItem(itemLocation);
	end
end

function AuctionHouseFrameMixin:ClearPostItem()
	self.CommoditiesSellFrame:SetItem(nil);
	self.CommoditiesSellList:SetItemID(nil);
	self.ItemSellFrame:SetItem(nil);
end

function AuctionHouseFrameMixin:UpdateTitle()
	local tab = PanelTemplates_GetSelectedTab(self);

	local title = AUCTION_HOUSE_FRAME_TITLE_BUY;
	if tab == 2 then
		title = AUCTION_HOUSE_FRAME_TITLE_SELL;
	elseif tab == 3 then
		title = AUCTION_HOUSE_AUCTIONS_SUB_TAB;
	end

	PortraitFrameTemplate_SetTitle(self, title);
end

function AuctionHouseFrameMixin:GetCategoriesList()
	return self.CategoriesList;
end

function AuctionHouseFrameMixin:GetBrowseResultsFrame()
	return self.BrowseResultsFrame;
end

function AuctionHouseFrameMixin:GetItemSellList()
	return self.ItemSellList;
end

function AuctionHouseFrameMixin:GetCommoditiesSellListFrames()
	return self.CommoditiesSellList, self.CommoditiesSellListHeaders;
end

function AuctionHouseFrameMixin:GetFavoriteDropDown()
	return self.FavoriteDropDown;
end

function AuctionHouseFrameMixin:GetBrowseSearchContext()
	if self.isDisplayingFavorites then
		return AuctionHouseSearchContext.AllFavorites;
	else
		return self:GetCategorySearchContext();
	end
end

function AuctionHouseFrameMixin:GetCategorySearchContext()
	local selectedCategoryIndex = self:GetCategoriesList():GetSelectedCategory();
	local browseSearchContext = AuctionHouseUtil.ConvertCategoryToSearchContext(selectedCategoryIndex);
	return browseSearchContext;
end

function AuctionHouseFrameMixin:SelectBrowseResult(browseResult)
	local itemKey = browseResult.itemKey;
	local itemKeyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey);
	local searchContext = itemKeyInfo.isCommodity and AuctionHouseSearchContext.BuyCommodities or AuctionHouseSearchContext.BuyItems;
	if itemKeyInfo.isCommodity then
		self.CommoditiesBuyFrame:SetItemIDAndPrice(itemKey.itemID, browseResult.minPrice);
		self:SetDisplayMode(AuctionHouseFrameDisplayMode.CommoditiesBuy);
	else
		self.ItemBuyFrame:SetItemKey(itemKey);
		self:SetDisplayMode(AuctionHouseFrameDisplayMode.ItemBuy);
	end
end

function AuctionHouseFrameMixin:GetSortOrderState(searchContext, sortOrder)
	return GetSortOrderState(searchContext, sortOrder);
end

function AuctionHouseFrameMixin:SetSortOrder(searchContext, sortOrder)
	if not AreSortTypesLoaded() then
		return;
	end

	local activeSearch = self.activeSearches[searchContext];
	if not activeSearch then
		return;
	end

	local sortType = { sortOrder = sortOrder, reverseSort = false };
	AddSortType(searchContext, sortType);

	if searchContext == AuctionHouseSearchContext.BuyItems or searchContext == AuctionHouseSearchContext.SellItems or searchContext == AuctionHouseSearchContext.AuctionsItems or searchContext == AuctionHouseSearchContext.BidItems then
		self:QueryItem(unpack(activeSearch));
	elseif searchContext == AuctionHouseSearchContext.AllFavorites or searchContext == AuctionHouseSearchContext.AllAuctions or searchContext == AuctionHouseSearchContext.AllBids then
		self:QueryAll(unpack(activeSearch));
	else
		self:SendBrowseQueryInternal(unpack(activeSearch));
	end
end

function AuctionHouseFrameMixin:SetBrowseSortOrder(sortOrder)
	local browseSearchContext = self:GetBrowseSearchContext();
	self:SetSortOrder(browseSearchContext, sortOrder);
end

function AuctionHouseFrameMixin:GetBrowseSortOrderState(sortOrder)
	local browseSearchContext = self:GetBrowseSearchContext();
	return self:GetSortOrderState(browseSearchContext, sortOrder);
end

function AuctionHouseFrameMixin:GetSortsForContext(searchContext)
	return GetSortTypes(searchContext);
end

function AuctionHouseFrameMixin:QueryItem(searchContext, itemKey, byItemID)
	if not AreSortTypesLoaded() then
		return;
	end

	self.activeSearches[searchContext] = { searchContext, itemKey, byItemID };

	self.isDisplayingFavorites = false;

	local sorts = GetSortTypes(searchContext);
	local separateOwnerItems = searchContext == AuctionHouseSearchContext.AuctionsItems or searchContext == AuctionHouseSearchContext.AuctionsCommodities;
	if byItemID then
		C_AuctionHouse.SendSellSearchQuery(itemKey, sorts, separateOwnerItems);
	else
		C_AuctionHouse.SendSearchQuery(itemKey, sorts, separateOwnerItems);
	end
end

function AuctionHouseFrameMixin:QueryAll(searchContext)
	if not AreSortTypesLoaded() then
		return;
	end

	self.activeSearches[searchContext] = { searchContext };

	local sorts = GetSortTypes(searchContext);

	self.isDisplayingFavorites = searchContext == AuctionHouseSearchContext.AllFavorites;

	if searchContext == AuctionHouseSearchContext.AllFavorites then
		C_AuctionHouse.SearchForFavorites(sorts);
		self:TriggerEvent(AuctionHouseFrameMixin.Event.BrowseSearchStarted);
		self:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy);
	elseif searchContext == AuctionHouseSearchContext.AllAuctions then
		C_AuctionHouse.QueryOwnedAuctions(sorts);
	elseif searchContext == AuctionHouseSearchContext.AllBids then
		C_AuctionHouse.QueryBids(sorts, GetActiveBidList());
	end
end

function AuctionHouseFrameMixin:SendBrowseQuery(searchString, minLevel, maxLevel, filtersArray)
	if not AreSortTypesLoaded() then
		return;
	end

	local browseSearchContext = self:GetCategorySearchContext();
	self:SendBrowseQueryInternal(browseSearchContext, searchString, minLevel, maxLevel, filtersArray);
	self:TriggerEvent(AuctionHouseFrameMixin.Event.BrowseSearchStarted);
end

function AuctionHouseFrameMixin:SendBrowseQueryInternal(browseSearchContext, searchString, minLevel, maxLevel, filtersArray)
	if not AreSortTypesLoaded() then
		return;
	end

	local categoriesList = self:GetCategoriesList();
	local filterData = categoriesList:GetCategoryFilterData();

	self.activeSearches[browseSearchContext] = { browseSearchContext, searchString, minLevel, maxLevel, filtersArray };

	self.isDisplayingFavorites = browseSearchContext == AuctionHouseSearchContext.AllFavorites;

	local query = {};
	query.searchString = searchString;
	query.minLevel = minLevel;
	query.maxLevel = maxLevel;
	query.filters = filtersArray;
	query.itemClassFilters = filterData;
	query.sorts = GetSortTypes(browseSearchContext);
	C_AuctionHouse.SendBrowseQuery(query);

	self:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy);
end

function AuctionHouseFrameMixin:RefreshSearchResults(searchContext, itemKey)
	if C_AuctionHouse.HasSearchResults(itemKey) then
		local itemKeyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey);
		if itemKeyInfo.isCommodity then
			C_AuctionHouse.RefreshCommoditySearchResults(itemKey.itemID);
		else
			C_AuctionHouse.RefreshItemSearchResults(itemKey);
		end
	else
		self:QueryItem(searchContext, itemKey);
	end
end

function AuctionHouseFrameMixin:StartCommoditiesPurchase(itemID, quantity, unitPrice, totalPrice)
	self.BuyDialog:SetItemID(itemID, quantity, unitPrice, totalPrice);
	self.BuyDialog:Show();
	C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity, unitPrice);
end

function AuctionHouseFrameMixin:StartItemBid(auctionID, bid)
	local data = { auctionID = auctionID, bid = bid };
	StaticPopup_Show("AUCTIONHOUSE_BID_AUCTION", nil, nil, data);
end

function AuctionHouseFrameMixin:StartItemBuyout(auctionID, buyout)
	local data = { auctionID = auctionID, buyout = buyout };
	StaticPopup_Show("AUCTIONHOUSE_BUYOUT_AUCTION", nil, nil, data);
end

function AuctionHouseFrameMixin:SetSearchText(text)
	if self.displayMode == AuctionHouseFrameDisplayMode.Buy or self.displayMode == AuctionHouseFrameDisplayMode.ItemBuy or self.displayMode == AuctionHouseFrameDisplayMode.CommoditiesBuy then
		self.SearchBar:SetSearchText(text);
		return true;
	end

	return false;
end

function AuctionHouseFrameMixin:GetMaxPriceWidth(cache, key, fontObject, maxPrice)
	self.DummyMoneyDisplayFrame:SetAmount(maxPrice or 0);
	self.DummyMoneyDisplayFrame:SetFontObject(fontObject);
	local width = self.DummyMoneyDisplayFrame:GetWidth();

	cache[key] = cache[key] or {};
	cache[key][fontObject] = width;
	return width;
end

function AuctionHouseFrameMixin:GetBidStatus(bidInfo)
	if not bidInfo.bidder then
		return AuctionHouseBidStatus.NoBid;
	elseif bidInfo.bidder == UnitName("player") then
		return AuctionHouseBidStatus.PlayerBid;
	elseif HasBeenOutbid(bidInfo.auctionID) then
		return AuctionHouseBidStatus.PlayerOutbid;
	else
		return AuctionHouseBidStatus.OtherBid;
	end
end