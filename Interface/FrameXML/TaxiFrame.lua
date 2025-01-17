-- The following function is used with permission from Daniel Stephens <iriel@vigilance-committee.org>
TAXIROUTE_LINEFACTOR = 32/30; -- Multiplying factor for texture coordinates
TAXIROUTE_LINEFACTOR_2 = TAXIROUTE_LINEFACTOR / 2; -- Half o that

TAXI_MAP_WIDTH = 580;
TAXI_MAP_HEIGHT = 580;
NUM_TAXI_BUTTONS = 0;
NUM_TAXI_ROUTES = 0;

TaxiButtonTypes = { };
TaxiButtonTypes["CURRENT"] = {
	file = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green"
}
TaxiButtonTypes["REACHABLE"] = {
	file = "Interface\\TaxiFrame\\UI-Taxi-Icon-White"
}
TaxiButtonTypes["DISTANT"] = {
	file = "Interface\\TaxiFrame\\UI-Taxi-Icon-Yellow"
}

TAXI_BUTTON_HALF_WIDTH = 8;
TAXI_BUTTON_HALF_HEIGHT = 8;


function TaxiFrame_OnLoad(self)
	self.Bg:SetTexture(0.37, 0.31, 0.41)
	self:RegisterEvent("TAXIMAP_OPENED");
	self:RegisterEvent("TAXIMAP_CLOSED");
end

function TaxiFrame_OnEvent(self, event, ...)
	if ( event == "TAXIMAP_OPENED" ) then
		-- Show the merchant we're dealing with
		self.TitleText:SetText(FLIGHT_MAP)

		-- Set the texture coords on the map
		self.InsetBg:Hide()
		self.InsetMapBg:SetTexCoord(0,1,0,1);
		SetTaxiMap(self.InsetMapBg);

		-- Show the taxi node map and buttons
		local num_nodes = NumTaxiNodes();
		if ( num_nodes > NUM_TAXI_BUTTONS ) then
			local button;
			for i = NUM_TAXI_BUTTONS+1, num_nodes do
				button = CreateFrame("Button", "TaxiButton"..i, TaxiRouteMap, "TaxiButtonTemplate");
				button:SetID(i);
			end
		end

		-- Draw nodes
		local taxiNodePositions = {};
		local numValidFlightNodes = 0;
		for index = 1, num_nodes do
			local type = TaxiNodeGetType(index);
			local button = _G["TaxiButton"..index];
			taxiNodePositions[index] = {};
			if ( type ~= "NONE" ) then
				numValidFlightNodes = numValidFlightNodes + 1;
				local x, y = TaxiNodePosition(button:GetID());
				local currX = x*TAXI_MAP_WIDTH;
				local currY = y*TAXI_MAP_HEIGHT;
				taxiNodePositions[index].x = currX;
				taxiNodePositions[index].y = currY;
				-- check if we are obscuring a previous placement (eg: Ebon Hold and Light's Hope Chapel)
				if ( numValidFlightNodes > 1 ) then
					for checkNode = 1, index - 1 do
						local checkX = taxiNodePositions[checkNode].x;
						local checkY = taxiNodePositions[checkNode].y;
						if ( taxiNodePositions[checkNode].x ) then
							if ( (currX > checkX - TAXI_BUTTON_HALF_WIDTH) and (currX < checkX + TAXI_BUTTON_HALF_WIDTH) ) then
								if ( (currY > checkY - TAXI_BUTTON_HALF_HEIGHT) and (currY < checkY + TAXI_BUTTON_HALF_HEIGHT) ) then
									taxiNodePositions[index].x = currX + (currX - checkX) * 0.5;
									taxiNodePositions[index].y = currY + (currY - checkY) * 0.5;
									taxiNodePositions[checkNode].x = checkX + (checkX - currX) * 0.5;
									taxiNodePositions[checkNode].y = checkY + (checkY - currY) * 0.5;
								end
							end
						end
					end
				end
				-- set the button position
				button:ClearAllPoints();
				button:SetPoint("CENTER", "TaxiRouteMap", "BOTTOMLEFT", taxiNodePositions[index].x, taxiNodePositions[index].y);
				button:SetNormalTexture(TaxiButtonTypes[type].file);
				button:Show();
			else
				button:Hide();
			end
		end

		-- Hide remaining nodes
		for index = num_nodes+1, NUM_TAXI_BUTTONS, 1 do
			local button = _G["TaxiButton"..index];
			button:Hide();
		end

		if ( num_nodes > NUM_TAXI_BUTTONS ) then
			NUM_TAXI_BUTTONS = num_nodes
		end

		-- All set...
		ShowUIPanel(self)
		if ( not self:IsShown() ) then
			CloseTaxiMap();
		end
		return;
	end
	if ( event == "TAXIMAP_CLOSED" ) then
		for i=1, NUM_TAXI_ROUTES do
			_G["TaxiRoute"..i]:Hide()
		end

		HideUIPanel(self);
		return;
	end
end

function TaxiNodeOnButtonEnter(button)
	local index = button:GetID();
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
	GameTooltip:AddLine(TaxiNodeName(index), "", 1.0, 1.0, 1.0);

	-- Setup variables
	local numRoutes = GetNumRoutes(index);
	local line;
	local sX, sY, dX, dY;
	local w = TaxiRouteMap:GetWidth();
	local h = TaxiRouteMap:GetHeight();

	local type = TaxiNodeGetType(index);
	if ( type == "REACHABLE" ) then
		SetTooltipMoney(GameTooltip, TaxiNodeCost(button:GetID()));
		TaxiNodeSetCurrent(index);

		if ( numRoutes > NUM_TAXI_ROUTES ) then
			for i = NUM_TAXI_ROUTES+1, numRoutes do
				line = TaxiRouteMap:CreateTexture("TaxiRoute"..i, "BACKGROUND");
				line:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Line");
			end
			NUM_TAXI_ROUTES = numRoutes;
		end

		for i=1, NUM_TAXI_ROUTES do
			line = _G["TaxiRoute"..i];
			if ( i <= numRoutes ) then
				sX = TaxiGetSrcX(index, i)*w;
				sY = TaxiGetSrcY(index, i)*h;
				dX = TaxiGetDestX(index, i)*w;
				dY = TaxiGetDestY(index, i)*h;
				DrawLine(line, "TaxiRouteMap", sX, sY, dX, dY, 32, TAXIROUTE_LINEFACTOR);
				line:Show();
			else
				line:Hide();
			end
		end
	elseif ( type == "CURRENT" ) then
		GameTooltip:AddLine(TAXINODEYOUAREHERE, "", 0.5, 1.0, 0.5);
		DrawOneHopLines();
	end

	GameTooltip:Show();
end

-- Draw all flightpaths within one hop of current location
function DrawOneHopLines()
	local line;
	local sX, sY, dX, dY;
	local w = TaxiRouteMap:GetWidth();
	local h = TaxiRouteMap:GetHeight();
	local numNodes = NumTaxiNodes();
	local numLines = 0;
	local numSingleHops = 0;
	for i=1, numNodes  do
		if ( GetNumRoutes(i) == 1 ) then
			numSingleHops = numSingleHops + 1;
			numLines = numLines + 1;
			if ( numLines > NUM_TAXI_ROUTES ) then
				line = TaxiRouteMap:CreateTexture("TaxiRoute"..numLines, "BACKGROUND");
				line:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Line");
				NUM_TAXI_ROUTES = numLines;
			else
				line = _G["TaxiRoute"..numLines];
			end
			if ( line ) then
				sX = TaxiGetSrcX(i, 1)*w;
				sY = TaxiGetSrcY(i, 1)*h;
				dX = TaxiGetDestX(i, 1)*w;
				dY = TaxiGetDestY(i, 1)*h;
				DrawLine(line, "TaxiRouteMap", sX, sY, dX, dY, 32, TAXIROUTE_LINEFACTOR);
				line:Show();
			end
		end
	end
	for i=numLines+1, NUM_TAXI_ROUTES do
		_G["TaxiRoute"..i]:Hide();
	end
	if ( numSingleHops == 0 ) then
		UIErrorsFrame:AddMessage(ERR_TAXINOPATHS, 1.0, 0.1, 0.1, 1.0);
		HideUIPanel(TaxiFrame);
	end
end