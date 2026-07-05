--------------------------------------------------------------------------
-- FriendShare.lua 
--------------------------------------------------------------------------
--[[
FriendShare

author: Vimrasha <vimrasha@fastmail.fm>

FriendShare synchronizes your friends lists across all your alts. No more jotting
down a character name and then logging into all your alts to add it. Just add it
once, and it will be added to your alts automatically when they log in.

Removing friends works the same way. If you remove a friend, then it will be
removed from your alts automatically the next time they log in.

When you log in, that alt is automatically added to your global friends list, and
will become a friend of all your other alts as they log in. This is really just
for auto name completion at the mailbox. If you manually remove an alt from your
friend list, it will not be re-added when you log that alt back in.

When you first start using FrendShare, the global friend list is initialized from
each alt as you log them in. So, just log all your alts in once and from that point
on they will all remain synchronized.

This all works without any user intervention.

Friends are stored on a per server, per faction (Horde or Alliance) basis.
]]--

local Saved_AddFriend = nil;
local Saved_RemoveFriend = nil;

local importedGlobalFriends = {};
local realmAndFaction = {};
local initialized = false;
local addonPrefix = "FriendShare";
local whisperPrefix = "FSHARE:";
local suppressFriendMessages = false;
local suppressPeerBroadcast = false;
local receivingFullSync = {};
local recentSyncMessages = {};
local recentSyncTargets = {};

-- Store current friends so that they are available when processing
-- the PLAYER_LEAVING_WORLD event.
local currentFriends = nil;

--[[ SavedVariables --]]
FriendShare_GlobalFriends = FriendShare_GlobalFriends or {};
FriendShare_RemovedFriends = FriendShare_RemovedFriends or {};
FriendShare_Alts = FriendShare_Alts or {};
if ( not FriendShare_ConfigVersion ) then
	FriendShare_AutoAlts = false;
	FriendShare_ConfigVersion = 2;
end
if ( FriendShare_AutoAlts == nil ) then FriendShare_AutoAlts = false; end
if ( FriendShare_RemoveAlts == nil ) then FriendShare_RemoveAlts = true; end
if ( FriendShare_RemoveAltsVersion == nil ) then FriendShare_RemoveAltsVersion = 0; end
FriendShare_Peers = FriendShare_Peers or {};


function FriendShare_ChatPrint(str)
	if ( DEFAULT_CHAT_FRAME ) then 
		DEFAULT_CHAT_FRAME:AddMessage(str, 0.3, 0.3, 1.0);
	end
end

function FriendShare_NormalizeName(name)
	if ( not name ) then return nil; end
	name = string.gsub(name, "%-.*$", "");
	name = string.lower(name);
	name = string.gsub(name, "^%l", string.upper);
	return name;
end

function FriendShare_CountList(list)
	local count = 0;
	for i, name in pairs( list ) do
		count = count + 1;
	end
	return count;
end

function FriendShare_ListToString(list)
	local text = "";
	for i, name in pairs( list ) do
		if ( text == "" ) then
			text = name;
		else
			text = text .. ", " .. name;
		end
	end
	return text;
end

function FriendShare_PrintChanged(action, list)
	local count = FriendShare_CountList( list );
	if ( count == 0 ) then return; end
	if ( count == 1 ) then
		FriendShare_ChatPrint( "FriendShare: " .. action .. "好友：" .. FriendShare_ListToString( list ) );
	else
		FriendShare_ChatPrint( "FriendShare: " .. action .. "好友：" .. FriendShare_ListToString( list ) );
	end
end

function FriendShare_CurrentAltTable()
	if ( not FriendShare_Alts[realmAndFaction] ) then FriendShare_Alts[realmAndFaction] = {}; end
	return FriendShare_Alts[realmAndFaction];
end

function FriendShare_CurrentGlobalTable()
	if ( not FriendShare_GlobalFriends[realmAndFaction] ) then FriendShare_GlobalFriends[realmAndFaction] = {}; end
	return FriendShare_GlobalFriends[realmAndFaction];
end

function FriendShare_CurrentRemovedTable()
	if ( not FriendShare_RemovedFriends[realmAndFaction] ) then FriendShare_RemovedFriends[realmAndFaction] = {}; end
	return FriendShare_RemovedFriends[realmAndFaction];
end

function FriendShare_SendAddonMessage(target, message)
	if ( not target or target == "" ) then return; end
	target = FriendShare_NormalizeName( target );
	if ( GetTime ) then
		recentSyncTargets[target] = GetTime();
	else
		recentSyncTargets[target] = 0;
	end
	if ( SendAddonMessage ) then
		local ok = pcall( SendAddonMessage, addonPrefix, message, "WHISPER", target );
		if ( not ok ) then
			FriendShare_ChatPrint( "FriendShare: 无法向 " .. target .. " 发送插件同步消息。" );
		end
	end
	if ( SendChatMessage ) then
		local whisperMessage = string.gsub( message, "|", "~" );
		local ok = pcall( SendChatMessage, whisperPrefix .. whisperMessage, "WHISPER", nil, target );
		if ( not ok ) then
			FriendShare_ChatPrint( "FriendShare: 无法向 " .. target .. " 发送密语同步消息。" );
		end
	end
end

function FriendShare_IsSyncWhisper(message)
	if ( not message ) then return false; end
	return string.find( message, "^" .. whisperPrefix );
end

function FriendShare_FilterSyncWhisper(self, event, message, author)
	if ( FriendShare_IsSyncWhisper( message ) ) then
		return true;
	end
end

function FriendShare_FilterSyncSystemMessage(self, event, message)
	if ( not message ) then return false; end
	local now = 0;
	if ( GetTime ) then now = GetTime(); end
	local lowerMessage = string.lower( message );
	for target, sentAt in pairs( recentSyncTargets ) do
		if ( now - sentAt > 8 ) then
			recentSyncTargets[target] = nil;
		elseif ( string.find( lowerMessage, string.lower( target ), 1, true ) and
			( string.find( message, "未找到", 1, true ) or
			string.find( message, "在线玩家", 1, true ) or
			string.find( lowerMessage, "no player named", 1, true ) or
			string.find( lowerMessage, "not found", 1, true ) or
			string.find( lowerMessage, "not currently playing", 1, true ) ) )
		then
			return true;
		end
	end
	return false;
end

function FriendShare_BroadcastToPeers(message)
	if ( suppressPeerBroadcast ) then return; end
	for peer, name in pairs( FriendShare_Peers ) do
		FriendShare_SendAddonMessage( name, message );
	end
end

function FriendShare_BroadcastRemoveAltsSetting(skipPeer)
	if ( suppressPeerBroadcast ) then return; end
	local setting = "OFF";
	if ( FriendShare_RemoveAlts ) then setting = "ON"; end
	for peer, name in pairs( FriendShare_Peers ) do
		if ( name ~= skipPeer ) then
			FriendShare_SendAddonMessage( name, "SET_REMOVEALTS|" .. realmAndFaction .. "|" .. setting .. "," .. FriendShare_RemoveAltsVersion );
		end
	end
end

function FriendShare_NextRemoveAltsVersion()
	local now = 0;
	if ( time ) then
		now = time();
	elseif ( GetTime ) then
		now = GetTime();
	end
	if ( now <= FriendShare_RemoveAltsVersion ) then
		now = FriendShare_RemoveAltsVersion + 1;
	end
	FriendShare_RemoveAltsVersion = now;
	return now;
end

function FriendShare_SetRemoveAlts(enabled, broadcast, silent, skipPeer, version)
	if ( version and version <= FriendShare_RemoveAltsVersion ) then
		return;
	end
	if ( version ) then
		FriendShare_RemoveAltsVersion = version;
	else
		FriendShare_NextRemoveAltsVersion();
	end
	FriendShare_RemoveAlts = enabled;
	if ( FriendShare_RemoveAlts ) then
		if ( not silent ) then
			FriendShare_ChatPrint( "FriendShare: 自动删除好友列表里的小号已开启。" );
		end
		FriendShare_ProcessAlts( FriendShare_CurrentFriends() );
	else
		if ( not silent ) then
			FriendShare_ChatPrint( "FriendShare: 自动删除好友列表里的小号已关闭。" );
		end
	end

	if ( broadcast ) then
		FriendShare_BroadcastRemoveAltsSetting( skipPeer );
	end
end

function FriendShare_SendNameChunks(peer, command, names)
	local chunk = "";
	for i, name in pairs( names ) do
		local nextChunk;
		if ( chunk == "" ) then
			nextChunk = name;
		else
			nextChunk = chunk .. "," .. name;
		end

		if ( string.len( nextChunk ) > 160 ) then
			FriendShare_SendAddonMessage( peer, command .. "|" .. realmAndFaction .. "|" .. chunk );
			chunk = name;
		else
			chunk = nextChunk;
		end
	end
	if ( chunk ~= "" ) then
		FriendShare_SendAddonMessage( peer, command .. "|" .. realmAndFaction .. "|" .. chunk );
	end
end

function FriendShare_AddNamesToList(list, names)
	if ( not names or names == "" ) then return; end
	for name in string.gmatch( names, "([^,]+)" ) do
		name = FriendShare_NormalizeName( name );
		if ( name and name ~= "" and name ~= UNKNOWN ) then
			list[name] = name;
		end
	end
end

function FriendShare_SendFullSync(peer)
	FriendShare_UpdateGlobalFriends( FriendShare_CurrentFriends() );
	local globalFriends = FriendShare_CurrentGlobalTable();
	local removedFriends = FriendShare_CurrentRemovedTable();
	local alts = FriendShare_CurrentAltTable();
	local player = UnitName( "player" );

	FriendShare_SendAddonMessage( peer, "BEGIN|" .. realmAndFaction );
	if ( FriendShare_RemoveAlts ) then
		FriendShare_SendAddonMessage( peer, "SET_REMOVEALTS|" .. realmAndFaction .. "|ON," .. FriendShare_RemoveAltsVersion );
	else
		FriendShare_SendAddonMessage( peer, "SET_REMOVEALTS|" .. realmAndFaction .. "|OFF," .. FriendShare_RemoveAltsVersion );
	end
	FriendShare_SendAddonMessage( peer, "ALT|" .. realmAndFaction .. "|" .. player );
	FriendShare_SendNameChunks( peer, "ALTS", alts );
	FriendShare_SendNameChunks( peer, "FRIENDS", globalFriends );
	FriendShare_SendNameChunks( peer, "REMOVES", removedFriends );
	FriendShare_SendAddonMessage( peer, "END|" .. realmAndFaction );
	FriendShare_ChatPrint( "FriendShare: 已向 " .. peer .. " 发送同步数据。" );
end

function FriendShare_RequestFullSync(peer)
	FriendShare_SendAddonMessage( peer, "REQ|" .. realmAndFaction );
	FriendShare_ChatPrint( "FriendShare: 已向 " .. peer .. " 请求同步数据。" );
end

function FriendShare_OnLoad()

	-- register events
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("PLAYER_LEAVING_WORLD");
	this:RegisterEvent("CHAT_MSG_ADDON");
	this:RegisterEvent("CHAT_MSG_WHISPER");
	if ( RegisterAddonMessagePrefix ) then
		RegisterAddonMessagePrefix( addonPrefix );
	end
	if ( ChatFrame_AddMessageEventFilter ) then
		ChatFrame_AddMessageEventFilter( "CHAT_MSG_WHISPER", FriendShare_FilterSyncWhisper );
		ChatFrame_AddMessageEventFilter( "CHAT_MSG_WHISPER_INFORM", FriendShare_FilterSyncWhisper );
		ChatFrame_AddMessageEventFilter( "CHAT_MSG_SYSTEM", FriendShare_FilterSyncSystemMessage );
	end

	SLASH_FRIENDSHARE1 = "/friendshare";
	SLASH_FRIENDSHARE2 = "/fs";
	SlashCmdList["FRIENDSHARE"] = function(msg)
		FriendShare_Command(msg);
	end

	-- Hook the Add/Remove friend handlers
	Saved_AddFriend = AddFriend;
	AddFriend = FriendShare_AddFriend;
	Saved_RemoveFriend = RemoveFriend;
	RemoveFriend = FriendShare_RemoveFriend;

	-- FriendShare_ChatPrint("FriendShare by Vimrasha loaded.");
end

function FriendShare_RealmAndFaction()
	local realmName = GetCVar("realmName");
	local faction = UnitFactionGroup("player");
	return realmName .. "-" .. faction;
end

function FriendShare_CurrentFriends()
	local numFriends = GetNumFriends();
	local curFriends = {};
	
	-- Build a list of my current friends
	for i=1, numFriends do
		local name, level, class, area, connected = GetFriendInfo(i);
		if (name and name ~= UNKNOWN) then curFriends[name] = name; end
	end
	return curFriends;
end


function FriendShare_Command(command)
	local i,j, cmd, param = string.find(command, "^([^ ]+) (.+)$");
	if (not cmd) then cmd = command; end
	if (not cmd) then cmd = ""; end
	if (not param) then param = ""; end

	if ((cmd == "") or (cmd == "help")) then
		local  lineFormat = "  |cffffffff/friendshare %s|r - %s";
		FriendShare_ChatPrint( "用法：" );
		FriendShare_ChatPrint(string.format(lineFormat, "<help>", "显示帮助信息。"));
		FriendShare_ChatPrint(string.format(lineFormat, "reset", "用当前角色好友列表重置全局好友列表。"));
		FriendShare_ChatPrint(string.format(lineFormat, "import", "导入全局好友列表。"));
		FriendShare_ChatPrint(string.format(lineFormat, "alts", "切换小号列表维护开关。"));
		FriendShare_ChatPrint(string.format(lineFormat, "alts on|off", "开启或关闭小号列表维护。"));
		FriendShare_ChatPrint(string.format(lineFormat, "removealts", "切换是否自动删除好友列表里的小号。"));
		FriendShare_ChatPrint(string.format(lineFormat, "removealts on|off", "开启或关闭自动删除好友列表里的小号。"));
		FriendShare_ChatPrint(string.format(lineFormat, "peer add <name>", "添加跨账号同步角色。"));
		FriendShare_ChatPrint(string.format(lineFormat, "peer remove <name>", "移除跨账号同步角色。"));
		FriendShare_ChatPrint(string.format(lineFormat, "peers", "列出跨账号同步角色。"));
		FriendShare_ChatPrint(string.format(lineFormat, "sync [name]", "与一个或全部同步角色交换好友数据。"));
	end
	if (cmd == "reset" ) then
		FriendShare_ChatPrint( "FriendShare: 已用当前角色好友列表重置全局好友列表。" );
		-- Reset global friends list to match my friends
		FriendShare_GlobalFriends[realmAndFaction] = FriendShare_CurrentFriends();
		FriendShare_RemovedFriends[realmAndFaction] = {};
	end
	if (cmd == "import" ) then
		-- Import global friends list
		FriendShare_Import();
	end
	if (cmd == "alts" ) then
		local autoAlts = FriendShare_AutoAlts;
		if ( param == "" ) then
			FriendShare_AutoAlts = not FriendShare_AutoAlts;
			if ( FriendShare_AutoAlts ) then
				FriendShare_ChatPrint( "FriendShare: 小号列表维护已开启。" );
			else
				FriendShare_ChatPrint( "FriendShare: 小号列表维护已关闭。" );
			end
		elseif ( param == "on" ) then
			FriendShare_AutoAlts = true;
			FriendShare_ChatPrint( "FriendShare: 小号列表维护已开启。" );
		elseif ( param == "off" ) then
			FriendShare_AutoAlts = false;
			FriendShare_ChatPrint( "FriendShare: 小号列表维护已关闭。" );
		else
			FriendShare_ChatPrint( "FriendShare: /friendshare alts 参数未知。" );
		end

		-- If AutoAlts setting changed, then process the alts list
		if ( autoAlts ~= FriendShare_AutoAlts ) then
			local currentFriends = FriendShare_CurrentFriends();
			FriendShare_ProcessAlts( currentFriends );
		end

	end
	if (cmd == "removealts" ) then
		if ( param == "" ) then
			FriendShare_SetRemoveAlts( not FriendShare_RemoveAlts, true, false );
		elseif ( param == "on" ) then
			FriendShare_SetRemoveAlts( true, true, false );
		elseif ( param == "off" ) then
			FriendShare_SetRemoveAlts( false, true, false );
		else
			FriendShare_ChatPrint( "FriendShare: /friendshare removealts 参数未知。" );
		end
	end
	if ( cmd == "peer" ) then
		local k,l, subcmd, peer = string.find(param, "^([^ ]+) (.+)$");
		if ( not subcmd ) then subcmd = param; end
		if ( peer ) then peer = FriendShare_NormalizeName(peer); end
		if ( subcmd == "add" and peer ) then
			FriendShare_Peers[peer] = peer;
			FriendShare_CurrentAltTable()[peer] = peer;
			FriendShare_CurrentGlobalTable()[peer] = nil;
			FriendShare_CurrentRemovedTable()[peer] = nil;
			if ( FriendShare_RemoveAlts ) then
				FriendShare_ProcessAlts( FriendShare_CurrentFriends() );
			end
			FriendShare_ChatPrint( "FriendShare: 已添加同步角色 " .. peer .. "。" );
		elseif ( ( subcmd == "remove" or subcmd == "del" ) and peer ) then
			FriendShare_Peers[peer] = nil;
			FriendShare_ChatPrint( "FriendShare: 已移除同步角色 " .. peer .. "。" );
		else
			FriendShare_ChatPrint( "FriendShare: 用法：/fs peer add <name> 或 /fs peer remove <name>。" );
		end
	end
	if ( cmd == "peers" ) then
		if ( FriendShare_CountList( FriendShare_Peers ) == 0 ) then
			FriendShare_ChatPrint( "FriendShare: 尚未配置跨账号同步角色。" );
		else
			FriendShare_ChatPrint( "FriendShare: 同步角色：" .. FriendShare_ListToString( FriendShare_Peers ) );
		end
	end
	if ( cmd == "sync" ) then
		local peer = FriendShare_NormalizeName( param );
		if ( peer and peer ~= "" ) then
			FriendShare_RequestFullSync( peer );
			FriendShare_SendFullSync( peer );
		else
			for i, name in pairs( FriendShare_Peers ) do
				FriendShare_RequestFullSync( name );
				FriendShare_SendFullSync( name );
			end
		end
	end
end

function FriendShare_Import()
	local curFriends = FriendShare_CurrentFriends();
	local player = UnitName("player");
	local numFriends = GetNumFriends();
	local addedFriends = {};
	local removedFriends = {};

	-- Clear the list of importedGlobalFriends before trying to import again.
	importedGlobalFriends = {};

	-- Process alts before importing globals so alts are never imported as friends.
	FriendShare_ProcessAlts( curFriends );

	-- Remove local friends that have been removed globaly
	local globalRemoves = FriendShare_RemovedFriends[realmAndFaction];
	for i, name in pairs( globalRemoves ) do
		if ( name ~= player and curFriends[name] and
			not FriendShare_Alts[realmAndFaction][name] )
		then
			suppressFriendMessages = true;
			RemoveFriend( name );
			suppressFriendMessages = false;
			numFriends = numFriends - 1;
			curFriends[name] = nil;
			removedFriends[name] = name;
		end
	end

	-- Add global friends that are not currently in local friends list
	-- Make a copy of the table as we will modify the original in the loop
	local globalFriends = FriendShare_GlobalFriends[realmAndFaction];
	for i, name in pairs( globalFriends ) do
		if ( name ~= player and not curFriends[name] and
			not FriendShare_RemovedFriends[realmAndFaction][name] and
			not FriendShare_Alts[realmAndFaction][name] )
		then
			-- If we exceed 50 friends (the max) then import will fail
			-- We don't want to removed those players from the global list even though import failed!
			if ( numFriends < 50 ) then
				-- If this charater still exists, it will be added back to the global list
				-- when processing the generated FRIENDLIST_UPDATE event.
				FriendShare_GlobalFriends[realmAndFaction][name] = nil;
				importedGlobalFriends[name] = name;
			end
			-- numFriends is just a guess since we don't know if AddFriend will succeed or not.
			numFriends = numFriends + 1;
			suppressFriendMessages = true;
			AddFriend( name );
			suppressFriendMessages = false;
			curFriends[name] = name;
			addedFriends[name] = name;
		end
	end

	-- Catch any alt that slipped in through old saved data or a delayed sync update.
	FriendShare_ProcessAlts( curFriends );
	for i, altName in pairs( FriendShare_Alts[realmAndFaction] ) do
		if ( addedFriends[altName] and not curFriends[altName] ) then
			addedFriends[altName] = nil;
			removedFriends[altName] = altName;
		end
	end
	FriendShare_UpdateGlobalFriends( curFriends );

	if ( numFriends > 50 ) then
		FriendShare_ChatPrint( "FriendShare: 警告！好友数量已达到上限，无法导入全部全局好友。" );
	end
	FriendShare_ChatPrint( "FriendShare: 全局好友列表已导入。" );
	FriendShare_PrintChanged( "已添加", addedFriends );
	FriendShare_PrintChanged( "已删除", removedFriends );
end


function FriendShare_ProcessAlts( curFriends )
	local player = UnitName( "player" );
	for i, name in pairs( FriendShare_Alts[realmAndFaction] ) do
		local name = FriendShare_Alts[realmAndFaction][i]
		-- Alts are excluded from the normal friend list to save friend slots.
		if ( FriendShare_RemoveAlts and name ~= player and curFriends[name] ) then
			FriendShare_ChatPrint( "FriendShare: 正在从本地好友列表移除小号 " .. name .. "。" );
			suppressFriendMessages = true;
			RemoveFriend( name );
			suppressFriendMessages = false;
			curFriends[name] = nil;
		end
		-- Alts are not to be stored in the normal lists
		FriendShare_GlobalFriends[realmAndFaction][name] = nil;
		FriendShare_RemovedFriends[realmAndFaction][name] = nil;
	end
	-- Ensure this toon is in the alt list
	if ( not FriendShare_Alts[realmAndFaction][player] ) then
		FriendShare_ChatPrint( "FriendShare: 已将当前角色加入全局小号列表。" );
		FriendShare_Alts[realmAndFaction][player] = player;
	end
	FriendShare_GlobalFriends[realmAndFaction][player] = nil;
	FriendShare_RemovedFriends[realmAndFaction][player] = nil;
end

-- Keep a record of current friends for use when handling PLAYER_LEAVING_WORLD.
local savedCurrentFriends = {};
local savedPlayerName;

function FriendShare_OnEvent(event)

	if ( event == "PLAYER_ENTERING_WORLD" ) then
		-- Only do this stuff once.
		this:UnregisterEvent("PLAYER_ENTERING_WORLD");

		-- Can't init these values until the player is in the world...
		realmAndFaction = FriendShare_RealmAndFaction();
		savedPlayerName = UnitName( "player" );
		if ( RegisterAddonMessagePrefix ) then
			RegisterAddonMessagePrefix( addonPrefix );
		end


		if ( not FriendShare_GlobalFriends[realmAndFaction] ) then
			FriendShare_GlobalFriends[realmAndFaction] = {};
		end
		-- A client timing bug could have placed this bogus value in the list
		FriendShare_GlobalFriends[realmAndFaction][UNKNOWN] = nil;

		if ( not FriendShare_RemovedFriends[realmAndFaction] ) then
			FriendShare_RemovedFriends[realmAndFaction] = {};
		end
		-- A client timing bug could have placed this bogus value in the list
		FriendShare_RemovedFriends[realmAndFaction][UNKNOWN] = nil;


		if ( not FriendShare_Alts[realmAndFaction] ) then
			FriendShare_Alts[realmAndFaction] = {};
		end

		-- Player must be in the world before we start listening to these events
		-- so that the player's faction is know and its list of friends
		-- has been loaded.
		this:RegisterEvent("FRIENDLIST_UPDATE");

		-- Force a FRIENDLIST_UPDATE event so that we can initialize.
		ShowFriends();
	end

	if ( event == "CHAT_MSG_ADDON" ) then
		FriendShare_OnSyncMessage( arg2, arg4 );
	end

	if ( event == "CHAT_MSG_WHISPER" ) then
		if ( FriendShare_IsSyncWhisper( arg1 ) ) then
			local syncMessage = string.gsub( arg1, "^" .. whisperPrefix, "" );
			syncMessage = string.gsub( syncMessage, "~", "|" );
			FriendShare_OnSyncMessage( syncMessage, arg2 );
		end
	end

	if ( event == "FRIENDLIST_UPDATE" ) then
		if ( not initialized ) then
			initialized = true;
			-- Import the global friends list.
			FriendShare_Import();
			savedCurrentFriends = FriendShare_CurrentFriends();
			-- Import the global ignore list.
			IgnoreShare_Import();
		else	
			savedCurrentFriends = FriendShare_CurrentFriends();
			FriendShare_ProcessAlts( savedCurrentFriends );
			FriendShare_UpdateGlobalFriends( savedCurrentFriends );
		end
	end

	if ( event == "PLAYER_LEAVING_WORLD" ) then
		-- Only do this stuff once.
		this:UnregisterEvent("PLAYER_LEAVING_WORLD");

		-- Imported global friends that are not current friends either
		-- had errors on import (player not found) or have been deleted.
		-- Either way they should be removed from the global list.
		for i, name in pairs( importedGlobalFriends ) do
			if ( not savedCurrentFriends[name] and not FriendShare_Alts[realmAndFaction][name] ) then
				FriendShare_GlobalFriends[realmAndFaction][name] = nil;
			end
		end

		-- Check for deleted alts
		if ( FriendShare_AutoAlts ) then
			for i, name in pairs( FriendShare_Alts[realmAndFaction] ) do
				if ( not (name == savedPlayerName) and not savedCurrentFriends[name] ) then
					FriendShare_ChatPrint( "FriendShare: " .. name .. " 似乎是已删除的小号。" );
					FriendShare_ChatPrint( "FriendShare: 正在从全局小号列表移除 " .. name .. "。" );
					FriendShare_Alts[realmAndFaction][name] = nil;
				end
			end
		end

	end
end

function FriendShare_OnSyncMessage(message, sender)
	if ( not message or not sender ) then return; end
	sender = FriendShare_NormalizeName( sender );
	if ( not FriendShare_Peers[sender] ) then return; end
	local recentKey = sender .. "|" .. message;
	local now = 0;
	if ( GetTime ) then now = GetTime(); end
	if ( recentSyncMessages[recentKey] and ( now - recentSyncMessages[recentKey] < 2 ) ) then
		return;
	end
	recentSyncMessages[recentKey] = now;

	local i,j, command, key, name = string.find( message, "^([^|]+)|([^|]+)|(.+)$" );
	if ( not command ) then
		i,j, command, key = string.find( message, "^([^|]+)|([^|]+)$" );
	end
	if ( not command or key ~= realmAndFaction ) then return; end
	local names = name;
	if ( command ~= "ALTS" and command ~= "FRIENDS" and command ~= "REMOVES" and
		command ~= "SET_REMOVEALTS" )
	then
		name = FriendShare_NormalizeName( name );
	end

	local globalFriends = FriendShare_CurrentGlobalTable();
	local removedFriends = FriendShare_CurrentRemovedTable();
	local alts = FriendShare_CurrentAltTable();

	if ( command == "BEGIN" ) then
		receivingFullSync[sender] = true;
		FriendShare_ChatPrint( "FriendShare: 正在接收来自 " .. sender .. " 的同步数据。" );
		return;
	end
	if ( command == "END" ) then
		suppressPeerBroadcast = true;
		FriendShare_Import();
		suppressPeerBroadcast = false;
		receivingFullSync[sender] = nil;
		FriendShare_ChatPrint( "FriendShare: 已完成来自 " .. sender .. " 的同步。" );
		return;
	end
	if ( command == "REQ" ) then
		FriendShare_ChatPrint( "FriendShare: " .. sender .. " 请求同步数据。" );
		FriendShare_SendFullSync( sender );
		return;
	end
	if ( command == "SET_REMOVEALTS" ) then
		local setting = name;
		local version = nil;
		local k,l, parsedSetting, parsedVersion = string.find( name, "^([^,]+),(.+)$" );
		if ( parsedSetting ) then
			setting = parsedSetting;
			version = tonumber( parsedVersion );
		end
		if ( setting == "ON" ) then
			FriendShare_SetRemoveAlts( true, true, false, sender, version );
		elseif ( setting == "OFF" ) then
			FriendShare_SetRemoveAlts( false, true, false, sender, version );
		end
		return;
	end
	if ( not name or name == "" or name == UNKNOWN ) then return; end

	if ( command == "ALT" ) then
		alts[name] = name;
		globalFriends[name] = nil;
		removedFriends[name] = nil;
		if ( FriendShare_RemoveAlts ) then
			FriendShare_ProcessAlts( FriendShare_CurrentFriends() );
		end
		return;
	end
	if ( command == "ALTS" ) then
		local newAlts = {};
		FriendShare_AddNamesToList( newAlts, names );
		for i, altName in pairs( newAlts ) do
			alts[altName] = altName;
			globalFriends[altName] = nil;
			removedFriends[altName] = nil;
		end
		if ( FriendShare_RemoveAlts ) then
			FriendShare_ProcessAlts( FriendShare_CurrentFriends() );
		end
		return;
	end
	if ( command == "FRIENDS" ) then
		local newFriends = {};
		FriendShare_AddNamesToList( newFriends, names );
		local changed = false;
		for i, friendName in pairs( newFriends ) do
			if ( not alts[friendName] ) then
				globalFriends[friendName] = friendName;
				removedFriends[friendName] = nil;
				changed = true;
			end
		end
		if ( changed ) then
			suppressPeerBroadcast = true;
			FriendShare_Import();
			suppressPeerBroadcast = false;
		end
		return;
	end
	if ( command == "REMOVES" ) then
		local newRemoves = {};
		FriendShare_AddNamesToList( newRemoves, names );
		local changed = false;
		for i, removedName in pairs( newRemoves ) do
			globalFriends[removedName] = nil;
			if ( not alts[removedName] ) then
				removedFriends[removedName] = removedName;
				changed = true;
			end
		end
		if ( changed ) then
			suppressPeerBroadcast = true;
			FriendShare_Import();
			suppressPeerBroadcast = false;
		end
		return;
	end
	if ( command == "ADD" ) then
		if ( not alts[name] ) then
			globalFriends[name] = name;
			removedFriends[name] = nil;
			if ( not receivingFullSync[sender] ) then
				suppressPeerBroadcast = true;
				FriendShare_Import();
				suppressPeerBroadcast = false;
			end
		end
		return;
	end
	if ( command == "DEL" ) then
		globalFriends[name] = nil;
		if ( not alts[name] ) then
			removedFriends[name] = name;
			if ( not receivingFullSync[sender] ) then
				suppressPeerBroadcast = true;
				FriendShare_Import();
				suppressPeerBroadcast = false;
			end
		end
		return;
	end
end

-- Ensure all friends in the given list are in the global friends list
function FriendShare_UpdateGlobalFriends(friendsList)
	for i, name in pairs( friendsList ) do
		if ( not FriendShare_GlobalFriends[realmAndFaction][name] and
			not FriendShare_RemovedFriends[realmAndFaction][name] and
			not FriendShare_Alts[realmAndFaction][name] )
		then
			FriendShare_ChatPrint( "FriendShare: 正在添加全局好友 " .. name );
			FriendShare_GlobalFriends[realmAndFaction][name] = name;
		end
	end
end

function FriendShare_AddFriend(name)
	if ( not name ) then return; end

	-- Ensure the first letter and only the first letter is capitalized
	name = FriendShare_NormalizeName(name);

	Saved_AddFriend(name);
	-- Friend will be added to the global list on next FRIENDLIST_UPDATE event if needed
	FriendShare_RemovedFriends[realmAndFaction][name] = nil;
	if ( FriendShare_RemoveAlts and FriendShare_Alts[realmAndFaction][name] ) then
		suppressFriendMessages = true;
		RemoveFriend( name );
		suppressFriendMessages = false;
		FriendShare_ChatPrint( "FriendShare: " .. name .. " 是已记录的小号，已从好友列表移除。" );
		return;
	end
	if ( not FriendShare_Alts[realmAndFaction][name] ) then
		FriendShare_BroadcastToPeers( "ADD|" .. realmAndFaction .. "|" .. name );
	end
	if ( not suppressFriendMessages ) then
		FriendShare_ChatPrint( "FriendShare: 已添加好友 " .. name .. "。" );
	end
end

function FriendShare_RemoveFriend(nameOrIndex)
	local name, level, class, area, connected;
	if ( type(nameOrIndex) == "string" ) then
		name = nameOrIndex;
	else
		name, level, class, area, connected = GetFriendInfo(nameOrIndex);
	end

	if ( not name ) then return; end

	-- Ensure the first letter and only the first letter is capitalized
	name = FriendShare_NormalizeName(name);

	Saved_RemoveFriend(name);
	FriendShare_GlobalFriends[realmAndFaction][name] = nil;
	-- Don't put alts on the removed friends list
	if ( not FriendShare_Alts[realmAndFaction][name] ) then
		FriendShare_RemovedFriends[realmAndFaction][name] = name;
		FriendShare_BroadcastToPeers( "DEL|" .. realmAndFaction .. "|" .. name );
	end
	if ( not suppressFriendMessages ) then
		FriendShare_ChatPrint( "FriendShare: 已删除好友 " .. name .. "。" );
	end
end

