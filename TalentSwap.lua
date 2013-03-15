local debugOn = 0
local currentTalents

local TALENT_COLUMNS = 3
local MAX_MACROS = 54
local MAX_CHAR_MACROS = 18
local MAX_GLOBAL_MACROS = 36
local MAX_ACTION_BUTTONS = 144
local POSSESSION_START = 121
local POSSESSION_END = 132

local function dprint(output, threshold)
	if not threshold then
		threshold = 1
	end
	if threshold <= debugOn then
		if type(output) == "string" or type(output) == "number" then
			print("TalentSwap: "..tostring(output))
		elseif type(output) == "table" then
			DevTools_Dump(output)
		end
	end
end

local function GetTalents()
	local talents = {}
	
	for i=1,GetMaxTalentTier() do
		local _, id = GetTalentRowSelectionInfo(i)
		if id then
			table.insert(talents, id)
		else
			table.insert(talents, 0)
		end
	end
	
	dprint(talents, 2)
	return talents
end

function FindMacro(name)
	for i=1,MAX_MACROS do
		if GetMacroInfo(i) == name then
			return i
		end
	end
end

local function GetSpellId(name)
	local link = GetSpellLink(name)
	if link then
		return tonumber(string.match(link, "spell:(%d+)"))
	end
end

local function GetTalentName(id)
	return string.match(GetTalentLink(id), "[[]([^]]+)")
end

local frame, events = CreateFrame("Frame"), {}
function events:PLAYER_ENTERING_WORLD()
	currentTalents = GetTalents()
end
function events:PLAYER_TALENT_UPDATE()
	if not currentTalents then
		return
	end
	if InCombatLockdown() then
		dprint("Unable to adjust actionbars while in combat!")
	else
		local newTalents = GetTalents()
		dprint(newTalents)
		for i=1,#newTalents do
			if newTalents[i] > 0 and currentTalents[i] ~= newTalents[i] then
				dprint("New Talent Found!")
				-- Get the name and ID of the new spell
				local spellName = GetTalentName(newTalents[i])
				if spellName then
					dprint("spellName = "..spellName)
					local spellId = GetSpellId(spellName)
					if spellId then
						dprint("spellId = "..spellId)
					
						-- Get the names of the other choices in the tier of talents
						local spellsToReplace = {}
						local start = (i-1)*TALENT_COLUMNS+1
						local stop = (i-1)*TALENT_COLUMNS+3
						for j=start,stop do
							local name = GetTalentName(j)
							if name ~= spellName then
								table.insert(spellsToReplace, name)
							end
						end
						dprint(spellsToReplace)
					
						-- Start fresh with nothing on the cursor
						ClearCursor()
						-- Save current sound setting
						local soundToggle = GetCVar("Sound_EnableAllSound")
						-- Turn sound off
						SetCVar("Sound_EnableAllSound", 0)
						
						for j=1,MAX_ACTION_BUTTONS do
							if j < POSSESSION_START or j > POSSESSION_END then
								local type, id = GetActionInfo(j)
								if type or id then
									if type == "spell" or type == "macro" then
										local actionName
										if type == "spell" then
											actionName = GetSpellInfo(id)
										elseif type == "macro" then
											actionName = GetMacroInfo(id)
										end
										dprint('actionName = "'..actionName..'"', 3)
										for k=1,#spellsToReplace do
											if actionName == spellsToReplace[k] then
												dprint("Found match at Action Slot "..j..".")
												if IsPassiveSpell(spellName) then
													if FindMacro(spellName) then
														PickupAction(j)
														ClearCursor()
														PickupMacro(spellName)
														PlaceAction(j)
													else
														dprint("Passives cannot be put on ActionBars, leaving old spell on ActionBars.", 0)
													end
												else
													PickupAction(j)
													ClearCursor()
													PickupSpell(spellId)
													PickupMacro(spellName)
													PlaceAction(j)
												end
												break
											else
												dprint("No match at "..j..'. ("'..actionName..'" vs "'..spellsToReplace[k]..'")', 4)
											end
										end
									end
								end
							end
						end
						
						-- Restore old sound setting
						SetCVar("Sound_EnableAllSound", soundToggle)
					end
				end
				
			end
		end
		currentTalents = newTalents
	end
end
frame:SetScript("OnEvent", function(self, event, ...)
	events[event](self, ...) -- call one of the functions above
end)
for k, v in pairs(events) do
	frame:RegisterEvent(k) -- Register all events for which handlers have been defined
end