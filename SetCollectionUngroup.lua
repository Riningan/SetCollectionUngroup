local _AddonName, _Addon = ...;

local IN_PROGRESS_FONT_COLOR = CreateColor(0.251, 0.753, 0.251);
local SET_PROGRESS_BAR_MAX_WIDTH = 204;


local _SetsDataProvider = nil;
local _ButtonHeight = nil;
local _CountAll = nil;
local _CurSelectSetID = nil;
local _PrevSelectSetID = nil;
local _PrevScrollValue = nil;
local _CurScrollValue = nil;
local OriginHybridScrollFrame_Update = nil;


local function BindSet(pButton, pBaseSet, pVariantSet, pIsHeader)
	local numCollected, numTotal = _SetsDataProvider:GetSetSourceCounts(pVariantSet.setID);
	local setCollected = numCollected == numTotal;
	local selectedSetID = WardrobeCollectionFrameScrollFrame:GetParent():GetSelectedSetID();
	
	pButton.setID = pBaseSet.setID;
	pButton.setVariantID = pVariantSet.setID;
	pButton:Show();
	
	pButton.Name:SetText(pVariantSet.name);
	local color = IN_PROGRESS_FONT_COLOR;
	if setCollected then
		color = NORMAL_FONT_COLOR;
	elseif numCollected == 0 then
		color = GRAY_FONT_COLOR;
	end
	pButton.Name:SetTextColor(color.r, color.g, color.b);
	
	if pVariantSet.description and pVariantSet.label then
		pButton.Label:SetText(pVariantSet.description .. ' - ' .. pVariantSet.label);
	else
		pButton.Label:SetText(pVariantSet.label);
	end
	
	if pIsHeader then
		pButton.IconCover:Show();
		pButton.IconCover:SetShown(false);
		pButton.Icon:Show();
		pButton.Icon:SetDesaturation(0);
		pButton.Icon:SetTexture(_SetsDataProvider:GetIconForSet(pBaseSet.setID));
		pButton.Icon:SetDesaturation((topSourcesCollected == 0) and 1 or 0);
		pButton.Favorite:SetShown(pBaseSet.favoriteSetID);
	else
		pButton.IconCover:Hide();
		pButton.Icon:Hide();
		pButton.Favorite:Hide();
	end
	
	pButton.New:SetShown(_SetsDataProvider:IsBaseSetNew(pBaseSet.setID));
	
	pButton.SelectedTexture:SetShown(pVariantSet.setID == selectedSetID);
	
	if numCollected == 0 or setCollected then
		pButton.ProgressBar:Hide();
	else
		pButton.ProgressBar:Show();
		pButton.ProgressBar:SetWidth(SET_PROGRESS_BAR_MAX_WIDTH * numCollected / numTotal);
	end
	
	pButton:RegisterForClicks("AnyUp", "AnyDown");
	pButton:SetScript("OnMouseUp", function(pSelf, pButton, pDown)
		if pButton == "LeftButton" then
			--PlaySound("igMainMenuOptionCheckBoxOn");
			pSelf:GetParent():GetParent():GetParent():SelectSet(pSelf.setVariantID);
		elseif pButton == "RightButton" then
			local dropDown = pSelf:GetParent():GetParent().FavoriteDropDown;
			dropDown.baseSetID = pSelf.setID;
			ToggleDropDownMenu(1, nil, dropDown, pSelf, 0, 0);
			--PlaySound("igMainMenuOptionCheckBoxOn");
		end
	end)
end

local function CalculateCount()
	_CountAll = 0;
	local countCollected = 0;
	local baseSets = _SetsDataProvider:GetBaseSets();
	for _, baseSet in pairs(baseSets) do
		local variantSets = _SetsDataProvider:GetVariantSets(baseSet.setID);
		if #variantSets > 0 then
			for _, variantSet in pairs(variantSets) do
				local numCollected, numTotal = _SetsDataProvider:GetSetSourceCounts(variantSet.setID);
				if numTotal > 0 then
					_CountAll = _CountAll + 1;
					if numCollected == numTotal then
						countCollected = countCollected + 1;
					end
				end
			end
		else
			local numCollected, numTotal = _SetsDataProvider:GetSetSourceCounts(baseSet.setID);
			if numTotal > 0 then
				_CountAll = _CountAll + 1;
				if numCollected == numTotal then
					countCollected = countCollected + 1;
				end
			end
		end
	end
	
	WardrobeCollectionFrame.progressBar:SetMinMaxValues(0, _CountAll);
	WardrobeCollectionFrame.progressBar:SetValue(countCollected);
	WardrobeCollectionFrame.progressBar.text:SetFormattedText(HEIRLOOMS_PROGRESS_FORMAT, countCollected, _CountAll);
end

local function ScrollToSet(pSelf, pSetID)
	local totalHeight = 0;
	local scrollFrameHeight = pSelf.ScrollFrame:GetHeight();
	local baseSets = _SetsDataProvider:GetBaseSets();
	local b = false;
	for _, baseSet in pairs(baseSets) do
		local variantSets = _SetsDataProvider:GetVariantSets(baseSet.setID);
		if #variantSets > 0 then
			for _, variantSet in pairs(variantSets) do
				if variantSet.setID == pSetID then
					b = true;
					break;
				end
				totalHeight = totalHeight + _ButtonHeight;
			end
			if b then
				break;
			end
		else
			if baseSet.setID == pSetID then
				break;
			else
				totalHeight = totalHeight + _ButtonHeight;
			end
		end
	end
	local offset = _PrevScrollValue;
	if totalHeight + _ButtonHeight > offset + scrollFrameHeight then
		offset = totalHeight + _ButtonHeight - scrollFrameHeight;
	elseif totalHeight < offset then
		offset = totalHeight;
	end
	pSelf.ScrollFrame.scrollBar:SetValue(offset, true);
end

function MyHybridScrollFrame_Update(pSelf, pTotalHeight, pDisplayedHeight)
	if pSelf == WardrobeCollectionFrameScrollFrame then
		local offset = HybridScrollFrame_GetOffset(pSelf);
		offset = offset + 1;
		local baseSets = _SetsDataProvider:GetBaseSets();
		local index = 0;
		local indexButton = 1; 
		for _, baseSet in pairs(baseSets) do
			if indexButton > #pSelf.buttons then
				break;
			end
			index = index + 1;
			local variantSets = _SetsDataProvider:GetVariantSets(baseSet.setID);
			if #variantSets == 0 then
				if offset <= index then
					BindSet(pSelf.buttons[indexButton], baseSet, baseSet, true);
					indexButton = indexButton + 1;
				end
			else
				if offset <= index then
					BindSet(pSelf.buttons[indexButton], baseSet, variantSets[1], true);
					indexButton = indexButton + 1;
				end
				for i = 2, #variantSets do
					if indexButton > #pSelf.buttons then
						break;
					end
					index = index + 1;
					if offset <= index then
						BindSet(pSelf.buttons[indexButton], baseSet, variantSets[i], false);
						indexButton = indexButton + 1;
					end	
				end
			end
		end
		
		local extraHeight = (pSelf.largeButtonHeight and pSelf.largeButtonHeight - _ButtonHeight) or 0;
		pTotalHeight = _CountAll * _ButtonHeight + extraHeight;
		local range = math.floor(pTotalHeight - pSelf:GetHeight() + 0.5);
		if range > 0 and pSelf.scrollBar then
			local minVal, maxVal = pSelf.scrollBar:GetMinMaxValues();
			if math.floor(pSelf.scrollBar:GetValue()) >= math.floor(maxVal) then
				pSelf.scrollBar:SetMinMaxValues(0, range)
				if math.floor(pSelf.scrollBar:GetValue()) ~= math.floor(range) then
					pSelf.scrollBar:SetValue(range);
				else
					HybridScrollFrame_SetOffset(pSelf, range); 
				end
			else
				pSelf.scrollBar:SetMinMaxValues(0, range)
			end
			pSelf.scrollBar:Enable();
			HybridScrollFrame_UpdateButtonStates(pSelf);
			pSelf.scrollBar:Show();
		end
		
		pSelf.range = range;
		pSelf.scrollChild:SetHeight(pDisplayedHeight);
		pSelf:UpdateScrollChildRect();
	else 
		OriginHybridScrollFrame_Update(pSelf, pTotalHeight, pDisplayedHeight)
	end
end

local function HookSelectSet(pSelf, pSetID)
	_PrevSelectSetID = _CurSelectSetID;
	_CurSelectSetID = pSetID;
end

local function HookScrollSetValue(pSelf, pValue)
	_PrevScrollValue = _CurScrollValue;
	_CurScrollValue = pValue;
end

local function HookHandleKey(pSelf, pKey)
	local selectedSetID = pSelf:GetSelectedSetID();
	if not selectedSetID then
		return;
	end
	
	local baseSets = _SetsDataProvider:GetBaseSets();
	local prevSet = nil;
	local curSet = nil;
	local nextSet = nil;
	for _, baseSet in pairs(baseSets) do
		local variantSets = _SetsDataProvider:GetVariantSets(baseSet.setID);
		if #variantSets > 0 then
			for _, variantSet in pairs(variantSets) do
				if curSet then
					nextSet = variantSet;
					break;
				end
				if _PrevSelectSetID == variantSet.setID then
					curSet = variantSet;
				else
					prevSet = variantSet;
				end
			end
		else
			if curSet then
				nextSet = baseSet;
			elseif _PrevSelectSetID == baseSet.setID then
				curSet = baseSet;
			else
				prevSet = baseSet;
			end
		end
		if nextSet then
			break;
		end
	end
	if pKey == WARDROBE_DOWN_VISUAL_KEY then
		if nextSet then
			pSelf:SelectSet(nextSet.setID);
			ScrollToSet(pSelf, nextSet.setID);
		end
	elseif pKey == WARDROBE_UP_VISUAL_KEY then
		if prevSet then
			pSelf:SelectSet(prevSet.setID);
			ScrollToSet(pSelf, prevSet.setID);
		end
	end
end

local frame = CreateFrame("frame"); 
frame:RegisterEvent("ADDON_LOADED");
frame:SetScript("OnEvent", function(pSelf, pEvent, pUnit)
	if pEvent == "ADDON_LOADED" and pUnit == "Blizzard_Collections" then
		_ButtonHeight = WardrobeCollectionFrameScrollFrame.buttons[1]:GetHeight();
		_SetsDataProvider = CreateFromMixins(WardrobeSetsDataProviderMixin);
		_CurSelectSetID = _SetsDataProvider:GetBaseSets()[1].setID;
		_CurScrollValue = 0;
		local variantSets = _SetsDataProvider:GetVariantSets(_CurSelectSetID);
		if #variantSets > 0 then
			_CurSelectSetID = variantSets[1].setID;
		end
		WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(_CurSelectSetID);
		
		CalculateCount()
		
		OriginHybridScrollFrame_Update = HybridScrollFrame_Update;
		HybridScrollFrame_Update = MyHybridScrollFrame_Update;
		
		hooksecurefunc(WardrobeCollectionFrame.SetsCollectionFrame, "HandleKey", HookHandleKey);
		hooksecurefunc(WardrobeCollectionFrame.SetsCollectionFrame, "SelectSet", HookSelectSet);
		hooksecurefunc(WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame.scrollBar, "SetValue", HookScrollSetValue);
		
		frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
		frame:RegisterEvent("PLAYER_REGEN_ENABLED");
		frame:RegisterEvent("TRANSMOG_SETS_UPDATE_FAVORITE");
	elseif pEvent == "TRANSMOG_COLLECTION_UPDATED" and _SetsDataProvider then
		_SetsDataProvider:ClearSets();
		CalculateCount()
	elseif pEvent == "PLAYER_REGEN_ENABLED" and _SetsDataProvider then
		_SetsDataProvider:ClearSets();
		CalculateCount()
	elseif pEvent == "TRANSMOG_SETS_UPDATE_FAVORITE" and _SetsDataProvider then
		_SetsDataProvider:ClearSets();
		CalculateCount()
	end
end)
