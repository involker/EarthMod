--[[
Title: Earth Mod
Author(s):  big
Date: 2017/1/24
Desc: Earth Mod
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/main.lua");
local EarthMod = commonlib.gettable("Mod.EarthMod");
------------------------------------------------------------
]]
NPL.load("(gl)Mod/EarthMod/EarthSceneContext.lua");
NPL.load("(gl)Mod/EarthMod/gisCommand.lua");
NPL.load("(gl)Mod/EarthMod/ItemEarth.lua");
NPL.load("(gl)Mod/EarthMod/gisToBlocksTask.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
NPL.load("(gl)script/apps/WebServer/WebServer.lua");
NPL.load("(gl)Mod/EarthMod/TileManager.lua");
NPL.load("(gl)Mod/EarthMod/MapBlock.lua");
NPL.load("(gl)Mod/EarthMod/DBStore.lua");

local EarthMod       = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.EarthMod"));
local gisCommand     = commonlib.gettable("Mod.EarthMod.gisCommand");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local TileManager 	  = commonlib.gettable("Mod.EarthMod.TileManager");
local MapBlock = commonlib.gettable("Mod.EarthMod.MapBlock");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");
local gisToBlocks = commonlib.gettable("MyCompany.Aries.Game.Tasks.gisToBlocks");
--LOG.SetLogLevel("DEBUG");
EarthMod:Property({"Name", "EarthMod"});

function EarthMod:ctor()
end

-- virtual function get mod name

function EarthMod:GetName()
	return "EarthMod"
end

-- virtual function get mod description 

function EarthMod:GetDesc()
	return "EarthMod is a plugin in paracraft"
end

function EarthMod:init()
	LOG.std(nil, "info", "EarthMod", "plugin initialized");

	-- register a new block item, id < 10513 is internal items, which is not recommended to modify. 
	GameLogic.GetFilters():add_filter("block_types", function(xmlRoot)
		local blocks = commonlib.XPath.selectNode(xmlRoot, "/blocks/");

		if(blocks) then
			blocks[#blocks+1] = {name="block", attr = {name="Earth",
				id = 10513, item_class="ItemEarth", text="NPL Earth",
				icon = "Mod/EarthMod/textures/icon.png",
			}}
			LOG.std(nil, "info", "Earth", "Earth block is registered");
		end

		return xmlRoot;
	end);

	-- add block to category list to be displayed in builder window (E key)
	GameLogic.GetFilters():add_filter("block_list", function(xmlRoot)
		for node in commonlib.XPath.eachNode(xmlRoot, "/blocklist/category") do
			if(node.attr.name == "tool") then
				node[#node+1] = {name="block", attr={name="Earth"} };
			end
		end
		return xmlRoot;
	end)
	MapBlock:init()
end

function EarthMod:OnLogin()
end

-- called when a new world is loaded. 

function EarthMod:OnWorldLoad()
	LOG.std(nil, "info", "EarthMod", "OnNewWorld");

	CommandManager:RunCommand("/take 10513");

	if(EarthMod:GetWorldData("alreadyBlock")) then
		-- CommandManager:RunCommand("/take 10513");
	end
	
	MapBlock:OnWorldLoad();

	TileManager:new() -- 初始化并加载数据
	-- 检测是否是读取存档
	-- local dbPath = DBStore.GetInstance().dbPath .. "/Config.db"
	if EarthMod:GetWorldData("alreadyBlock") and EarthMod:GetWorldData("coordinate") then

		TileManager.GetInstance():Load() -- 加载配置
		local coordinate = EarthMod:GetWorldData("coordinate");
		gisToBlocks.minlat = coordinate.minlat
		gisToBlocks.minlon = coordinate.minlon
		gisToBlocks.maxlat = coordinate.maxlat
		gisToBlocks.maxlon = coordinate.maxlon

		-- 从文件读取学校名称,由于字符串数据自带双引号,所以需要替换掉
		local schoolName = EarthMod:GetWorldData("schoolName");
		schoolName = string.gsub(schoolName, "\"", "");
		-- echo("school name is : "..schoolName)
		-- 根据学校名称调用getSchoolByName接口,请求最新的经纬度范围信息,如果信息不一致,则更新文件中已有数据
		System.os.GetUrl({url = "http://192.168.1.160:8098/api/wiki/models/school/getSchoolByName", form = {name=schoolName,} }, function(err, msg, res)
			if(res and res.error and res.data and res.data ~= {} and res.error.id == 0) then
                -- 获取经纬度信息,如果获取到的经纬度信息不存在,需要提示用户
                -- echo("getSchoolByName by name : ")
                -- echo(res.data)
                local areaInfo = res.data[1];
                -- 如果查询到的最新的经纬度范围不等于原有的范围,则更新已有tileManager信息
                -- echo(areaInfo.southWestLng .. " , " .. areaInfo.southWestLat .. " , " .. areaInfo.northEastLng .. " , " .. areaInfo.northEastLat)
                -- echo(tostring(areaInfo.southWestLng ~= coordinate.minlon) .. " , " .. tostring(areaInfo.southWestLat ~= coordinate.minlat) .. " , " .. tostring(areaInfo.northEastLng ~= coordinate.maxlon) .. " , " .. tostring(areaInfo.northEastLat ~= coordinate.maxlat))
                if areaInfo.southWestLng and areaInfo.southWestLat and areaInfo.northEastLng and areaInfo.northEastLat 
                	and (areaInfo.southWestLng ~= coordinate.minlon or areaInfo.southWestLat ~= coordinate.minlat 
                	or areaInfo.northEastLng ~= coordinate.maxlon or areaInfo.northEastLat ~= coordinate.maxlat) then
                	gisToBlocks.minlat = areaInfo.southWestLat
					gisToBlocks.minlon = areaInfo.southWestLng
					gisToBlocks.maxlat = areaInfo.northEastLat
					gisToBlocks.maxlon = areaInfo.northEastLng
					echo("call reInitWorld")
					-- 更新原有坐标信息
					EarthMod:SetWorldData("coordinate",{minlat=tostring(gisToBlocks.minlat),minlon=tostring(gisToBlocks.minlon),maxlat=tostring(gisToBlocks.maxlat),maxlon=tostring(gisToBlocks.maxlon)});
					EarthMod:SaveWorldData();
                	gisToBlocks:reInitWorld()
                else
                	echo("call initworld")
                	gisToBlocks:initWorld()
                end
            else
            	gisToBlocks:initWorld()
            end
		end);

	end
end
-- called when a world is unloaded. 

function EarthMod:OnLeaveWorld()
	if TileManager.GetInstance() then
		if gisToBlocks.timerGet then gisToBlocks.timerGet:Change();gisToBlocks.timerGet = nil end
		MapBlock:OnLeaveWorld()
	end
end

function EarthMod:OnDestroy()
end
