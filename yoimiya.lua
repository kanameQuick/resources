local dataStoreService = game:GetService("DataStoreService")
local httpService = game:GetService("HttpService")
local replicatedStorage = game.ReplicatedStorage

local remotes = replicatedStorage.remotes
local bindables = replicatedStorage.bindables
local modules = replicatedStorage.modules
local serverModules = game.ServerScriptService.serverModules

local numberCountr = require(modules.numberCountr)
local idBlacklist = require(modules.idBlacklist)
local textFilter = require(serverModules.textFilter)

-----[[ ID BLACKLIST ]]-----
local lists = dataStoreService:GetDataStore("lists")

function getBlacklist(player, assetType)
	local data
	
	print("[DS]", "getting " .. assetType .. " blacklist for player " .. player.Name)
	
	repeat
		local success, err = pcall(function()
			if assetType == "image" then
				data = lists:GetAsync("idBlacklist")
			elseif assetType == "audio" then
				data = lists:GetAsync("audioBlacklist")
			end
		end)
		if not success then
			print("[DS]", "failed to get " .. assetType .. " blacklist for player " .. player.Name .. " (" .. err .. "), retrying")
			
			wait(1)
		end
	until success
	
	if not data then
		data = {}
	end
	
	return data
end

remotes.getBlacklist.OnServerInvoke = getBlacklist

-----[[ DATA STORES ]]-----
function getPersonalDataStore(player, dataStoreName)
	local dataStore = dataStoreService:GetDataStore(dataStoreName)
	
	local data

	print("[DS]", "getting " .. dataStoreName .. " for player " .. player.Name .. " with key " .. player.UserId)
	
	repeat
		local success, err = pcall(function()
			data = dataStore:GetAsync(player.UserId)
		end)
		if not success then
			print("[DS]", "failed to get " .. dataStoreName .. " for player " .. player.Name .. " (" .. err .. "), retrying")

			wait(1)
		end
	until success

	return data
end

remotes.getPersonalDataStore.OnServerInvoke = getPersonalDataStore

function setPersonalDataStore(player, dataStoreName, data)
	local dataStore = dataStoreService:GetDataStore(dataStoreName)

	print("[DS]", "setting " .. dataStoreName .. " for player " .. player.Name .. " with key " .. player.UserId)
	
	----- UPDATING APPEARANCE ATTRIBUTES -----
	if dataStoreName == "settings" then
		----- NAMETAG CUSTOMISATION INFO -----
		--- defaults ---
		-- chat
		player:SetAttribute("ChatFont", data.chatFont)
		player:SetAttribute("ChatColour", Color3.fromHex(data.chatColour))
		player:SetAttribute("NameColour", Color3.fromHex(data.nameColour))
		-- glow
		player:SetAttribute("GlowColour", Color3.fromHex(data.glowColour))
		player:SetAttribute("GlowDistance", data.glowDist)
		-- nametag
		player:SetAttribute("RPNameFont", data.rpNameFont)
		player:SetAttribute("RPNameColour", Color3.fromHex(data.rpNameColour))
		player:SetAttribute("BioFont", data.bioFont)
		player:SetAttribute("BioColour", Color3.fromHex(data.bioColour))
		-- tts
		player:SetAttribute("TtsEnabled", data.ttsEnabled)
		
		--- updating the nametag ---
		local character = player.Character

		local nametagAttachment

		local existingCanvas = character:FindFirstChild("canvas")
		if existingCanvas then
			nametagAttachment = existingCanvas.nametagAttachment
		else
			nametagAttachment = character.HumanoidRootPart.nametagAttachment
		end
		
		local nametagFrame = nametagAttachment.nametag.mainFrame

		-- nametag
		local rpNameFont = player:GetAttribute("RPNameFont")
		local rpNameColour = player:GetAttribute("RPNameColour")
		local bioFont = player:GetAttribute("BioFont")
		local bioColour = player:GetAttribute("BioColour")
		
		-- rp name
		nametagFrame.rpName.TextColor3 = rpNameColour
		if tonumber(rpNameFont) then
			nametagFrame.rpName.FontFace = Font.fromId(tonumber(rpNameFont))
		else
			nametagFrame.rpName.Font = Enum.Font[rpNameFont]
		end

		-- rp bio
		nametagFrame.bio.TextColor3 = bioColour
		if tonumber(bioFont) then
			nametagFrame.bio.FontFace = Font.fromId(tonumber(bioFont))
		else
			nametagFrame.bio.Font = Enum.Font[bioFont]
		end
		
		-- glow
		local glow = character.HumanoidRootPart:WaitForChild("glow")

		glow.Color = Color3.fromHex(data.glowColour)
		glow.Range = data.glowDist
	elseif dataStoreName == "profileSettings" then
		player:SetAttribute("ProfileBanner", idBlacklist.checkBlacklist(data.profileBanner))
		player:SetAttribute("ProfileBio", (data.bio ~= "") and textFilter.filterString(data.bio, player) or "<i>No bio</i>")
	end
	
	----- SAVING THE DATA -----
	repeat
		local success, err = pcall(function()
			dataStore:SetAsync(player.UserId, data)
			
			print("[DS]", "successfully set '" .. dataStoreName .. "' for player " .. player.Name)
		end)
		if not success then
			if string.find(err:lower(), ("Data stores can only accept valid UTF-8 characters."):lower(), 1, true) then
				remotes.notify:FireClient(player, "An error occurred while trying to save data. Please review the information you provided and try again.", "error")
				break
			else
				warn("[DS]", "failed to set '" .. dataStoreName .. "' for player " .. player.Name .. " (" .. err .. "), retrying")

				wait(1)
			end
		end
	until success
end

remotes.setPersonalDataStore.OnServerEvent:Connect(setPersonalDataStore)

-----[[ INITIAL + CUSTOMISATION SETTINGS ]]-----
local ranks = require(replicatedStorage.modules.ranks)

local defaultChatNameColours = {
	Color3.fromRGB(128,128,128),

	Color3.fromRGB(255,128,128),
	Color3.fromRGB(128,255,128),
	Color3.fromRGB(128,128,255),

	Color3.fromRGB(255,255,128),
	Color3.fromRGB(128,255,255),
	Color3.fromRGB(255,128,255),

	Color3.fromRGB(255,192,192),
	Color3.fromRGB(192,255,192),
	Color3.fromRGB(192,192,255),

	Color3.fromRGB(255,255,192),
	Color3.fromRGB(192,255,255),
	Color3.fromRGB(255,192,255),

	Color3.fromRGB(255,192,128),
	Color3.fromRGB(192,255,128),
	Color3.fromRGB(192,128,255),

	Color3.fromRGB(255,128,192),
	Color3.fromRGB(128,255,192),
	Color3.fromRGB(128,192,255),

	Color3.fromRGB(192,192,192),
}

local settingsDataStore = dataStoreService:GetDataStore("settings")

function onPlayerAdded(player)
	print("[DS]", "preparing to load data for " .. player)
	
	local key = player.UserId
	
	-----[[ TOTAL PLAYTIME ]]-----
	player:SetAttribute("JoinTimestamp", tick())
	
	local totalPlaytime = getPersonalDataStore(player, "totalPlaytime")
	
	if totalPlaytime then
		player:SetAttribute("TotalPlaytime", totalPlaytime)
	else
		warn(player.Name, "couldn't load total playtime, currently not set")
		player:SetAttribute("TotalPlaytime", 0)
	end

	-----[[ SETTINGS ]]-----
	----- NAMETAG CUSTOMISATION INFO -----
	--- defaults ---
	-- chat
	player:SetAttribute("ChatFont", "12187364147")
	player:SetAttribute("ChatColour", Color3.fromRGB(255, 255, 255))
	player:SetAttribute("NameColour", defaultChatNameColours[(key%20) + 1])
	-- glow
	player:SetAttribute("GlowColour", Color3.fromRGB(255, 255, 255))
	player:SetAttribute("GlowDistance", 15)
	-- nametag
	player:SetAttribute("RPNameFont", "12188570269")
	player:SetAttribute("RPNameColour", Color3.fromRGB(255, 255, 255))
	player:SetAttribute("BioFont", "12187364147")
	player:SetAttribute("BioColour", Color3.fromRGB(225, 225, 225))
	-- tts
	player:SetAttribute("TtsEnabled", false)
	
	----- PROFILE CUSTOMISATION INFO -----
	player:SetAttribute("ProfileBanner", 140255024272798)
	player:SetAttribute("ProfileBio", "<i>No bio</i>")
	player:SetAttribute("JoinedSince", "1970-01-01T00:00:00.000000Z")
	
	print("[DS]", "loading settings for person '" .. player.Name .. "' with key '" .. key .. "'")


	----- SETTINGS -----
	local settingsData = getPersonalDataStore(player, "settings")
	
	if settingsData then
		print("[DS]", "successfully loaded settings for user '" .. player.Name .. "'")
		
		if settingsData.chatFont then
			player:SetAttribute("ChatFont", settingsData.chatFont)
		end
		
		if settingsData.chatColour then
			player:SetAttribute("ChatColour", Color3.fromHex(settingsData.chatColour))
			player:SetAttribute("NameColour", Color3.fromHex(settingsData.nameColour))
		end

		if settingsData.glowColour then
			player:SetAttribute("GlowColour", Color3.fromHex(settingsData.glowColour))
			player:SetAttribute("GlowDistance", settingsData.glowDist)
		end

		if settingsData.rpNameFont then
			player:SetAttribute("RPNameFont", settingsData.rpNameFont)
			player:SetAttribute("RPNameColour", Color3.fromHex(settingsData.rpNameColour))
			player:SetAttribute("BioFont", settingsData.bioFont)
			player:SetAttribute("BioColour", Color3.fromHex(settingsData.bioColour))
		end

		if settingsData.ttsVolume then
			player:SetAttribute("TtsEnabled", settingsData.ttsEnabled)
		end
	else
		warn(player.Name, "couldn't load settings, currently not set")
	end
	
	----- PROFILE SETTINGS -----
	local profileSettingsData = getPersonalDataStore(player, "profileSettings")
	
	if profileSettingsData then
		if profileSettingsData.profileBanner then
			player:SetAttribute("ProfileBanner", idBlacklist.checkBlacklist(profileSettingsData.profileBanner))
		end
		
		if profileSettingsData.bio then
			player:SetAttribute("ProfileBio", (profileSettingsData.bio ~= "") and textFilter.filterString(profileSettingsData.bio, player) or "<i>No bio</i>")
		end
	else
		warn(player.Name, "couldn't load profile settings, currently not set")
	end
	
	----- JOIN DATE -----
	local firstTimeVisitData = getPersonalDataStore(player, "firstTimeVisit")
	
	if firstTimeVisitData then -- if the player already has the visit data
		if firstTimeVisitData.joinedSince then
			warn("[DS]", "First-time visit data existed for " .. player.Name)
			
			player:SetAttribute("JoinedSince", firstTimeVisitData.joinedSince)
		end
	else
		-- repeat this 5 times, if it fails, continue
		for i = 1, 5 do
			local success, data = pcall(httpService.GetAsync, httpService, `https://badges.roproxy.com/v1/users/{player.UserId}/badges/awarded-dates?badgeIds=2124986016`)
			
			if not success then
				warn("[DS]", "Failed to load badge data for " .. player.Name .. " | " .. data)
				
				task.wait()
			else
				local dataTable = httpService:JSONDecode(data)
				
				if #dataTable.data > 0 then -- if the player already has the badge
					warn("[DS]", "Successfully loaded badge data for " .. player.Name)
					player:SetAttribute("JoinedSince", dataTable.data[1].awardedDate)
				else -- if not yet, then use the time right now
					warn("[DS]", "Badge data loaded, but no information for " .. player.Name)
					player:SetAttribute("JoinedSince", DateTime.now():ToIsoDate())
				end
				
				break
			end	
		end
	end

	----- CUSTOMISATIONS -----
	local groupRank
	local membershipTier
	repeat
		groupRank = player:GetAttribute("GroupRank")
		membershipTier = player:GetAttribute("MembershipTier")
		if not ((groupRank ~= nil) and (membershipTier ~= nil)) then if not player then return else wait() end end
	until (groupRank ~= nil) and (membershipTier ~= nil) 
	
	----- APPLYING CUSTOMISATIONS -----

	-----[[ STREAKS ]]-----
	local streaks = getPersonalDataStore(player, "streaks")

	local currTime = os.time()
	if streaks then
		if currTime - streaks.lastVisitTimestamp > 172800 then -- if delta time is more than 2 days, reset streak
			warn(player.Name, "delta time since last visit exceeded, resetting streaks")
			player:SetAttribute("Streaks", 0)
			player:SetAttribute("LastStreakTimestamp", currTime)
		elseif currTime - streaks.lastVisitTimestamp > 43200 then -- if delta time is more than 12 hrs, increase streak
			player:SetAttribute("Streaks", streaks.amount+1)
			player:SetAttribute("LastStreakTimestamp", currTime)
		else -- if the player visits 12 hrs before the next streak cycle
			player:SetAttribute("Streaks", streaks.amount)
			player:SetAttribute("LastStreakTimestamp", streaks.lastVisitTimestamp)
		end
	else
		warn(player.Name, "couldn't load daily streaks, currently not set")
		player:SetAttribute("Streaks", 0)
		player:SetAttribute("LastStreakTimestamp", currTime)
	end
	
	local function onCharacterAdded()
		-- glow
		local glowColour = player:GetAttribute("GlowColour")
		local glowDistance = player:GetAttribute("GlowDistance")
		-- nametag
		local rpNameFont = player:GetAttribute("RPNameFont")
		local rpNameColour = player:GetAttribute("RPNameColour")
		local bioFont = player:GetAttribute("BioFont")
		local bioColour = player:GetAttribute("BioColour")
		-- tts
		-- local ttsEnabled = player:GetAttribute("TtsEnabled", false)
		
		warn(player, "character added")
		
		local character = player.Character
		
		if character then
			-----[[ NAME TAG ]]-----
			local nametagAttachment = replicatedStorage.attachmentsContainer.nametagAttachment:Clone()
			local nametagFrame = nametagAttachment.nametag.mainFrame
			
			nametagAttachment.Parent = character.HumanoidRootPart
			nametagAttachment.CFrame = CFrame.new(Vector3.new(0, 1 + (character.HumanoidRootPart.Size.Y/2) + character.Head.Size.Y, 0))
			
			--- rp info ---
			-- rp name
			nametagFrame.rpName.Text = player.DisplayName
			nametagFrame.rpName.TextColor3 = rpNameColour
			if tonumber(rpNameFont) then
				nametagFrame.rpName.FontFace = Font.fromId(tonumber(rpNameFont))
			else
				nametagFrame.rpName.Font = Enum.Font[rpNameFont]
			end
			
			-- rp bio
			nametagFrame.bio.Text = "<i>Not morphed</i>"
			nametagFrame.bio.TextColor3 = bioColour
			if tonumber(bioFont) then
				nametagFrame.bio.FontFace = Font.fromId(tonumber(bioFont))
			else
				nametagFrame.bio.Font = Enum.Font[bioFont]
			end
			
			--- pfp ---
			nametagFrame.nameFrame.pfp.Image = "https://www.roblox.com/headshot-thumbnail/image?height=150&format=png&width=150&userId=" .. player.UserId
			--- group rank ---
			if groupRank > 0 then
				nametagFrame.nameFrame.infoFrame.username.groupRank.Visible = true
				nametagFrame.nameFrame.infoFrame.username.groupRank.Image = ranks.groupRanks[tostring(groupRank)][2]
				nametagFrame.nameFrame.infoFrame.username.groupRank.ImageColor3 = ranks.groupRanks[tostring(groupRank)][3]
			else
				nametagFrame.nameFrame.infoFrame.username.groupRank.Visible = false
			end
			--- membership ---
			if membershipTier > 0 then
				nametagFrame.nameFrame.infoFrame.username.membership.Visible = true
				nametagFrame.nameFrame.infoFrame.username.membership.Image = ranks.memberships[tostring(membershipTier)][2]
				nametagFrame.nameFrame.infoFrame.username.membership.ImageColor3 = ranks.memberships[tostring(membershipTier)][3]
			else
				nametagFrame.nameFrame.infoFrame.username.membership.Visible = false
			end
			--- premium ---
			nametagFrame.nameFrame.infoFrame.username.premium.Visible = player.MembershipType == Enum.MembershipType.Premium
			--- username ---
			nametagFrame.nameFrame.infoFrame.username.username.Text = "@" .. player.Name
			--- streaks ---
			nametagFrame.nameFrame.streaksFrame.value.Text = numberCountr.abbreviateNumber(player:GetAttribute("Streaks"))
			--- bottom frame ---
			nametagFrame.nameFrame.infoFrame.imageId.Visible = false
			--- status ---
			nametagFrame.statusFrame.BackgroundTransparency = 1
			nametagFrame.statusFrame.Size = UDim2.fromScale(.02, .125)
			nametagFrame.statusFrame.icon.ImageTransparency = 1
			nametagFrame.statusFrame.text.TextTransparency = 1
			--- typing ---
			nametagFrame.typingFrame.BackgroundTransparency = 1
			nametagFrame.typingFrame.Size = UDim2.fromOffset(16, 32)
			nametagFrame.typingFrame.dot1.ImageTransparency = 1
			nametagFrame.typingFrame.dot2.ImageTransparency = 1
			nametagFrame.typingFrame.dot3.ImageTransparency = 1
			
			-----[[ GLOW ]]-----
			local glow = character.HumanoidRootPart:WaitForChild("glow")
			
			glow.Color = glowColour
			glow.Range = glowDistance
		end
	end
	
	player.CharacterAdded:Connect(onCharacterAdded)
	onCharacterAdded()

	-----[[ ROLEPLAY RANK ]]-----
	local roleplayExp = getPersonalDataStore(player, "roleplayExp")

	if roleplayExp then
		player:SetAttribute("RoleplayExp", roleplayExp)
	else
		warn(player.Name, "couldn't load total roleplay EXP, currently not set")
		player:SetAttribute("RoleplayExp", 0)
	end
	
	-----[[ MORI ]]-----
	local currency = getPersonalDataStore(player, "currency")

	if currency then
		player:SetAttribute("Currency", currency)
	else
		warn(player.Name, "couldn't load currency, currently not set")
		player:SetAttribute("Currency", 50)
	end
	
	-----[[ FINALISING ]]-----
	player:SetAttribute("DataLoaded", true)
	
	-----[[ OTHER ATTRIBS ]]-----
	player:SetAttribute("CurrentMap", workspace.serverStats.startingMap.Value)
	player:SetAttribute("CurrentZone", workspace.serverStats.startingZone.Value)
end

function onPlayerRemoving(removingPlayer)
	local player = {
		Name = removingPlayer.Name,
		UserId = removingPlayer.UserId
	}
	
	if removingPlayer:GetAttribute("DataLoaded") then
		local totalPlaytime = removingPlayer:GetAttribute("TotalPlaytime")
		local finalPlaytime = totalPlaytime + (tick() - removingPlayer:GetAttribute("JoinTimestamp"))
		local roleplayExp = removingPlayer:GetAttribute("RoleplayExp")
		local currency = removingPlayer:GetAttribute("Currency")
		local streaks = removingPlayer:GetAttribute("Streaks")
		local lastStreakTimestamp = removingPlayer:GetAttribute("LastStreakTimestamp")
		local joinedSince = removingPlayer:GetAttribute("JoinedSince")
		
		setPersonalDataStore(player, "totalPlaytime", finalPlaytime)
		setPersonalDataStore(player, "roleplayExp", roleplayExp)
		setPersonalDataStore(player, "currency", currency)
		setPersonalDataStore(player, "streaks", {
			lastVisitTimestamp = lastStreakTimestamp,
			amount = streaks
		})
		setPersonalDataStore(player, "firstTimeVisit", {
			joinedSince = joinedSince
		})
		
		print("[DS]", "successfully saved data for " .. player.Name)
	else
		warn("[DS]", "unable to save data for " .. player.Name .. ", data not fully loaded")
	end
end

game.Players.PlayerAdded:Connect(onPlayerAdded)
game.Players.PlayerRemoving:Connect(onPlayerRemoving)

-----[[ INCREMENTING DATA ]]-----
function incrementData(player, dataType, value)
	if player:GetAttribute("DataLoaded") then
		if dataType == "exp" then
			local currentExp = player:GetAttribute("RoleplayExp")
			
			player:SetAttribute("RoleplayExp", currentExp + value)
		elseif dataType == "currency" then
			local currentCurrency = player:GetAttribute("Currency")

			player:SetAttribute("Currency", currentCurrency + value)
		end
		
		print(player.Name, "incremented", dataType, "by", value)
	end
end

remotes.incrementData.OnServerEvent:Connect(incrementData)
bindables.incrementValue.Event:Connect(incrementData)
