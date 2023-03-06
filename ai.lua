-- CONFIG
local CONFIG = {
	ROUTE = workspace:WaitForChild("Folder"), -- Optional, An array of VECTOR3 or Basepart. Can also be a folder that contains the parts,
	WALKING_RANGE = { -- The RANDOM walking distance
		MIN = 10,
		MAX = 50
	},
	PATHFINDING_CONFIGURATION = { -- The Pathfinding Configuration
		RADIUS = 2,
		HEIGHT = 5,
		CAN_JUMP = true,
		CAN_CLIMB = true
	},
	MANIAC = false, -- Wethere this AI should kill everyone on its path
	TASTE = "ALL", -- Decides on what the AI should prioritize in killing. Options are: "NEUTRAL","ALL","WEAK","STRONG"
	DETECTION_DISTANCE = 100 -- How long the AI can see
	DAMAGE = 5, -- The amount of damage it deals to an "enemy"
}

-- Services
local PathfindingService = game:GetService("PathfindingService")

-- Variables
local character:Model = script.Parent
	local HRP:BasePart = character:WaitForChild("HumanoidRootPart")
		HRP:SetNetworkOwner(nil)
	local humanoid:Humanoid = character:WaitForChild("Humanoid")

-- Functions

local function negativeOrPositive()
	local res = 1
	
	if (math.random()>0.5) then
		res = -1
	end
	return res
end

local function computePath(destination:Vector3)
	local Path:Path
	
	Path = PathfindingService:CreatePath({
		["AgentRadius"] = CONFIG.PATHFINDING_CONFIGURATION.RADIUS,
		["AgentHeight"] = CONFIG.PATHFINDING_CONFIGURATION.HEIGHT,
		["AgentCanJump"] = CONFIG.PATHFINDING_CONFIGURATION.CAN_JUMP,
		["AgentCanClimb"] = CONFIG.PATHFINDING_CONFIGURATION.CAN_CLIMB
	})
	Path:ComputeAsync(HRP.Position,destination)
	
	return Path
end

local function getHumanoids()
	local humanoids = {}
	for _,h:Humanoid in ipairs(workspace:GetDescendants()) do
		if (not h:IsA("Humanoid") or h.Parent==character) then continue end
		table.insert(humanoids,h.Parent)
	end
	return humanoids
end

local function doSomethingWithTarget(target:Model)
	local h:Humanoid = target:WaitForChild("Humanoid")
	local hrp:BasePart = target:WaitForChild("HumanoidRootPart")
	
	local d = (HRP.Position - hrp.Position).Magnitude
	
	if (d<8) then
		if (CONFIG.MANIAC==true) then
			h:TakeDamage(CONFIG.DAMAGE)
			task.wait(1)
		end
	else
		humanoid:MoveTo(hrp.Position)
	end
end

local function findTarget()
	if (CONFIG.TASTE=="NEUTRAL") then return end
	
	local distance = CONFIG.DETECTION_DISTANCE
	local finalTarget:Model
	
	local lowestHealthPercent = 0
		local lowestHealthPercentTarget:Model
	local highestHealthPercent = 0
		local highestHealthPercentTarget:Model
	
	for _,target:Model in ipairs(getHumanoids()) do
		local h:Humanoid = target:WaitForChild("Humanoid")
			local percentHealth = (h.Health/h.MaxHealth)
		local hrp:BasePart = target:WaitForChild("HumanoidRootPart")
		
		local d = (HRP.Position - hrp.Position).Magnitude
		
		if (d<distance) then
			if (lowestHealthPercent>percentHealth) then
				lowestHealthPercent = percentHealth
				lowestHealthPercentTarget = target
			elseif (highestHealthPercent<percentHealth) then
				highestHealthPercent = percentHealth
				highestHealthPercentTarget = target
			end
			
			distance = d
			finalTarget = target
		end
	end
	
	if (CONFIG.TASTE=="WEAK") then
		return lowestHealthPercentTarget
	elseif (CONFIG.TASTE=="STRONG") then
		return highestHealthPercentTarget
	elseif (CONFIG.TASTE=="ALL") then
		return finalTarget
	end
end

local function findRoute()
	local position:Vector3
	local usePathfinding = false
	local path:Path
	
	if (not CONFIG.ROUTE or (typeof(CONFIG.ROUTE)=="table" and #CONFIG.ROUTE==0)) then
		-- Will walk randomly
		position = HRP.Position+Vector3.new(
			math.random(CONFIG.WALKING_RANGE.MIN,CONFIG.WALKING_RANGE.MAX)*negativeOrPositive(),
			0,
			math.random(CONFIG.WALKING_RANGE.MIN,CONFIG.WALKING_RANGE.MAX)*negativeOrPositive()
		)
	else
		-- Will walk a specified route
		usePathfinding = true
		position = nil
		
		local chosenPath:Vector3
		
		if (CONFIG.ROUTE:IsA("Folder")) then
			local parts = CONFIG.ROUTE:GetChildren()
			chosenPath = parts[math.random(1,#parts)]
			chosenPath = chosenPath.Position
		else
			chosenPath = CONFIG.ROUTE[math.random(1,#CONFIG.ROUTE)]
			if (chosenPath:IsA("BasePart")) then
				chosenPath = chosenPath.Position
			end
		end
		
		path = computePath(chosenPath)
	end
	
	return position, usePathfinding, path
end

local function move()
	local position, usePathfinding, path, endPos = findRoute()
	
	if (usePathfinding and path) then
		-- Use PathfindingService to walk
		
		local disconnect = false
		path.Blocked:Connect(function()
			disconnect = true
		end)
		
		for _,w in ipairs(path:GetWaypoints()) do
			if (disconnect==true) then break end
			
			local target = findTarget()
			
			if (target) then
				doSomethingWithTarget(target)
				break
			end
			
			humanoid:MoveTo(w.Position)
			humanoid.MoveToFinished:Wait()
		end
	else
		humanoid:MoveTo(position)
		humanoid.MoveToFinished:Wait()
	end
end

while true do
	move()
	task.wait(1)
end
