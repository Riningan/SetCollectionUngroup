local _AddonName, _Addon = ...;


local IN_PROGRESS_FONT_COLOR = CreateColor(0.251, 0.753, 0.251);
local SET_PROGRESS_BAR_MAX_WIDTH = 204;


local _ScrollFrame = nil;
local _FavoriteDropDown = nil;
local _SetsDataProvider = nil;
local _ButtonHeight = nil;


local function CalculateCount()
	local countAll = 0;
	local countCollected = 0;
	local baseSets = _SetsDataProvider:GetBaseSets();
	for _, baseSet in pairs(baseSets) do
		local variantSets = _SetsDataProvider:GetVariantSets(baseSet.setID);
		if #variantSets > 0 then
			for _, variantSet in pairs(variantSets) do
				local numCollected, numTotal = _SetsDataProvider:GetSetSourceCounts(variantSet.setID);
				if numTotal > 0 then
					countAll = countAll + 1;
					if numCollected == numTotal then
						countCollected = countCollected + 1;
					end
				end
			end
		else
			local numCollected, numTotal = _SetsDataProvider:GetSetSourceCounts(baseSet.setID);
			if numTotal > 0 then
				countAll = countAll + 1;
				if numCollected == numTotal then
					countCollected = countCollected + 1;
				end
			end
		end
	end
	return countAll, countCollected;
end

function ScrollFrameButton_BindSet(pButton, pBaseSet, pVariantSet, pIsHeader)
	local numCollected, numTotal = _SetsDataProvider:GetSetSourceCounts(pVariantSet.setID);
	local setCollected = numCollected == numTotal;
	
	pButton.setID = pBaseSet.setID;
	pButton.setVariantID = pVariantSet.setID;
	pButton:Show();
	
	pButton.Name:SetText(pVariantSet.name);
	local color;
	if setCollected then
		color = NORMAL_FONT_COLOR;
	elseif numCollected == 0 then
		color = GRAY_FONT_COLOR;
	else 
		color = IN_PROGRESS_FONT_COLOR;
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
	
	pButton.SelectedTexture:SetShown(pVariantSet.setID == _ScrollFrame.selectedSetID);
	
	if numCollected == 0 then
		pButton.ProgressBar:Hide();
	else
		pButton.ProgressBar:Show();
		pButton.ProgressBar:SetWidth(SET_PROGRESS_BAR_MAX_WIDTH * numCollected / numTotal);
	end
end

function ScrollFrame_Update()
	_SetsDataProvider:ClearSets();
	
	local offset = HybridScrollFrame_GetOffset(_ScrollFrame) + 1;
	local baseSets = _SetsDataProvider:GetBaseSets();
	local buttons = _ScrollFrame.buttons;
	local index = 0;
	local indexButton = 1; 
	for _, baseSet in pairs(baseSets) do
		if indexButton > #buttons then
			break;
		end
		index = index + 1;
		local variantSets = _SetsDataProvider:GetVariantSets(baseSet.setID);
		if #variantSets == 0 then
			if offset <= index then
				ScrollFrameButton_BindSet(buttons[indexButton], baseSet, baseSet, true);
				indexButton = indexButton + 1;
			end
		else
			if offset <= index then
				ScrollFrameButton_BindSet(buttons[indexButton], baseSet, variantSets[1], true);
				indexButton = indexButton + 1;
			end
			for i = 2, #variantSets do
				if indexButton > #buttons then
					break;
				end
				index = index + 1;
				if offset <= index then
					ScrollFrameButton_BindSet(buttons[indexButton], baseSet, variantSets[i], false);
					indexButton = indexButton + 1;
				end	
			end
		end
	end
	for i = indexButton, #buttons do 
		buttons[i]:Hide();
	end
	
	local countAll, countCollected = CalculateCount();
	
	WardrobeCollectionFrame.progressBar:SetMinMaxValues(0, countAll);
	WardrobeCollectionFrame.progressBar:SetValue(countCollected);
	WardrobeCollectionFrame.progressBar.text:SetFormattedText(HEIRLOOMS_PROGRESS_FORMAT, countCollected, countAll);
	
	local totalHeight = countAll * _ButtonHeight;
	local range = math.floor(totalHeight - _ScrollFrame:GetHeight() + 0.5);
	if range > 0 then
		local minVal, maxVal = _ScrollFrame.scrollBar:GetMinMaxValues();
		_ScrollFrame.scrollBar:SetMinMaxValues(0, range)
		if math.floor(_ScrollFrame.scrollBar:GetValue()) >= math.floor(maxVal) then
			if math.floor(_ScrollFrame.scrollBar:GetValue()) ~= math.floor(range) then
				_ScrollFrame.scrollBar:SetValue(range);
			else
				HybridScrollFrame_SetOffset(_ScrollFrame, range); 
			end
		end
		_ScrollFrame.scrollBar:Enable();
		HybridScrollFrame_UpdateButtonStates(_ScrollFrame);
		_ScrollFrame.scrollBar:Show();
	else
		_ScrollFrame.scrollBar:SetValue(0);
		_ScrollFrame.scrollBar:Disable();
		_ScrollFrame.scrollUp:Disable();
		_ScrollFrame.scrollDown:Disable();
		_ScrollFrame.scrollBar.thumbTexture:Hide();
	end
	_ScrollFrame.range = range;
	_ScrollFrame:UpdateScrollChildRect();
end

local function ScrollFrame_SelectSet(pSetID)
	_ScrollFrame.selectedSetID = pSetID;
	WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(pSetID);
	ScrollFrame_Update();
end

local function ScrollFrame_ScrollToSet(pSetID)
	local totalHeight = 0;
	local scrollFrameHeight = _ScrollFrame:GetHeight();
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
	if totalHeight + _ButtonHeight > _ScrollFrame.scrollBar.scrollValue + scrollFrameHeight then
		_ScrollFrame.scrollBar.scrollValue = totalHeight + _ButtonHeight - scrollFrameHeight;
	elseif totalHeight < _ScrollFrame.scrollBar.scrollValue then
		_ScrollFrame.scrollBar.scrollValue = totalHeight;
	end
	_ScrollFrame.scrollBar:SetValue(_ScrollFrame.scrollBar.scrollValue, true);
end

local function ScrollFrame_HandleKey(pKey)
	if not _ScrollFrame.selectedSetID then
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
				if _ScrollFrame.selectedSetID == variantSet.setID then
					curSet = variantSet;
				else
					prevSet = variantSet;
				end
			end
		else
			if curSet then
				nextSet = baseSet;
			elseif _ScrollFrame.selectedSetID == baseSet.setID then
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
			ScrollFrame_SelectSet(nextSet.setID);
			ScrollFrame_ScrollToSet(nextSet.setID);
		end
	elseif pKey == WARDROBE_UP_VISUAL_KEY then
		if prevSet then
			ScrollFrame_SelectSet(prevSet.setID);
			ScrollFrame_ScrollToSet(prevSet.setID);
		end
	end
end

local function FavoriteDropDown_Init(pSelf)
	if not _ScrollFrame.menuInitBaseSetID then
		return;
	end

	local baseSet = _SetsDataProvider:GetBaseSetByID(_ScrollFrame.menuInitBaseSetID);
	local variantSets = _SetsDataProvider:GetVariantSets(_ScrollFrame.menuInitBaseSetID);
	local useDescription = (#variantSets > 0);

	local info1 = UIDropDownMenu_CreateInfo();
	info1.notCheckable = true;
	info1.disabled = nil;
	if baseSet.favoriteSetID then
		if useDescription then
			local setInfo = C_TransmogSets.GetSetInfo(baseSet.favoriteSetID);
			info1.text = format(TRANSMOG_SETS_UNFAVORITE_WITH_DESCRIPTION, setInfo.description);
		else
			info1.text = BATTLE_PET_UNFAVORITE;
		end
		info1.func = function()
			C_TransmogSets.SetIsFavorite(baseSet.favoriteSetID, false);
		end
	else
		local targetSetID = WardrobeCollectionFrame.SetsCollectionFrame:GetDefaultSetIDForBaseSet(_ScrollFrame.menuInitBaseSetID);
		if useDescription then
			local setInfo = C_TransmogSets.GetSetInfo(targetSetID);
			info1.text = format(TRANSMOG_SETS_FAVORITE_WITH_DESCRIPTION, setInfo.description);
		else
			info1.text = BATTLE_PET_FAVORITE;
		end
		info1.func = function()
			C_TransmogSets.SetIsFavorite(targetSetID, true);
		end
	end
	UIDropDownMenu_AddButton(info1, 1);
  
	--local info2 = UIDropDownMenu_CreateInfo();
	--info2.notCheckable = true;
	--info2.disabled = nil;
	--info2.text = CANCEL;
	--info2.func = nil;
	--UIDropDownMenu_AddButton(info2, 1);
end


local SetCollection = nil;
local frame = CreateFrame("frame"); 
frame:RegisterEvent("ADDON_LOADED");
frame:SetScript("OnEvent", function(pSelf, pEvent, pUnit)
	if pEvent == "ADDON_LOADED" and pUnit == "Blizzard_Collections" then
		WardrobeCollectionFrameScrollFrame:Hide();
		
		_ButtonHeight = WardrobeCollectionFrameScrollFrame.buttons[1]:GetHeight();
		
		_SetsDataProvider = CreateFromMixins(WardrobeSetsDataProviderMixin);
		
		_ScrollFrame = CreateFrame("ScrollFrame", "SetCollectionUngroupScrollFrame", WardrobeCollectionFrame.SetsCollectionFrame, "HybridScrollFrameTemplate");
		_ScrollFrame:SetAllPoints(WardrobeCollectionFrameScrollFrame);
		
		_ScrollFrame.scrollBar = CreateFrame("Slider", "SetCollectionUngroupScrollFrameScrollBar", _ScrollFrame, "HybridScrollBarTrimTemplate");
		_ScrollFrame.scrollBar:SetAllPoints(WardrobeCollectionFrameScrollFrame.scrollBar);
		_ScrollFrame.scrollBar:SetScript("OnValueChanged", function(pSelf, pValue) 
			pSelf.scrollValue = pValue;
			HybridScrollFrame_OnValueChanged(pSelf, pValue);
			ScrollFrame_Update();
		end);
		_ScrollFrame.scrollBar.trackBG:Show();
		_ScrollFrame.scrollBar.trackBG:SetVertexColor(0, 0, 0, 0.75);
		_ScrollFrame.scrollBar.scrollValue = 0;
		
		HybridScrollFrame_CreateButtons(_ScrollFrame, "WardrobeSetsScrollFrameButtonTemplate", 44, 0);
		for _, button in pairs(_ScrollFrame.buttons) do
			button.ProgressBar:SetTexture(1, 1, 1);
			button:RegisterForClicks("AnyUp", "AnyDown");
			button:SetScript("OnMouseUp", function(pSelf, pButton, pDown)
				if pButton == "LeftButton" then
					--PlaySound("igMainMenuOptionCheckBoxOn");
					CloseDropDownMenus();
					ScrollFrame_SelectSet(pSelf.setVariantID);
				elseif pButton == "RightButton" then
					_ScrollFrame.menuInitBaseSetID = pSelf.setID;
					ToggleDropDownMenu(1, nil, _FavoriteDropDown, pSelf, 0, 0);
					--PlaySound("igMainMenuOptionCheckBoxOn");
				end
			end)
		end
		
		_ScrollFrame.selectedSetID = _SetsDataProvider:GetBaseSets()[1].setID;
		local variantSets = _SetsDataProvider:GetVariantSets(_ScrollFrame.selectedSetID);
		if #variantSets > 0 then
			_ScrollFrame.selectedSetID = variantSets[1].setID;
		end
		WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(_ScrollFrame.selectedSetID);
		
		_FavoriteDropDown = CreateFrame("Frame", "SetCollectionUngroupFavoriteDropDown", _ScrollFrame, "UIDropDownMenuTemplate");
		UIDropDownMenu_Initialize(_FavoriteDropDown, FavoriteDropDown_Init, "MENU");

		hooksecurefunc(WardrobeCollectionFrameScrollFrame, "update", function(pSelf)
			_ScrollFrame.selectedSetID = WardrobeCollectionFrame.SetsCollectionFrame:GetSelectedSetID();
			ScrollFrame_Update();
		end);
		hooksecurefunc(WardrobeCollectionFrameScrollFrame, "Update", function(pSelf)
			_ScrollFrame.selectedSetID = WardrobeCollectionFrame.SetsCollectionFrame:GetSelectedSetID();
			ScrollFrame_Update();
		end);
		
		_ScrollFrame:SetScript("OnShow", function(pSelf) 
			ScrollFrame_Update();
			frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
			frame:RegisterEvent("PLAYER_REGEN_ENABLED");
			frame:RegisterEvent("TRANSMOG_SETS_UPDATE_FAVORITE");
		end);
		_ScrollFrame:SetScript("OnHide", function(pSelf) 
			frame:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED");
			frame:UnregisterEvent("PLAYER_REGEN_ENABLED");
			frame:UnregisterEvent("TRANSMOG_SETS_UPDATE_FAVORITE");
		end);
		_ScrollFrame:SetScript("OnKeyDown", function(pSelf, pKey)
			ScrollFrame_HandleKey(pKey);
		end);
	elseif _ScrollFrame then 
		if pEvent == "TRANSMOG_SETS_UPDATE_FAVORITE" then
			WardrobeCollectionFrameScrollFrame:OnEvent(pEvent);
		end
		ScrollFrame_Update();
	end
end)
