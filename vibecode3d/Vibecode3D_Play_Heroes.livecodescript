######################################################################################
## CARD SCRIPT: "Play.Heroes"   PROMPT & GLAZE  (11 12 2026)
## Third person in a vector maze. PROMPT (cyan) and GLAZE (magenta) are minimal stick
## figures driven by LIB_MOCAP clips. You play one; the other follows you through the
## maze on its own (LIB_MAP path finding). TAB swaps who you play. Bring both to the
## gold beacon in the far corner and a new maze is built.
## CONTROLS  W / up arrow  walk        S / down arrow  step back     Shift  hurry
##           A D / left right arrows   turn                TAB  switch hero
## SKILLS    PROMPT gets the job done no matter what; GLAZE: barter, charm, influence.
##           Shown on screen, not used yet.
## NEEDS     ../LIB_BIT, ../LIB_MAP and ../LIB_MOCAP/library (proc_walk and an idle clip).
######################################################################################

global gObjectTransforms, gSceneObjects
global gCameraYaw, gCameraPitch
global gViewLeft, gViewTop, gViewRight, gViewBottom
global bPaused, bPlaying

constant kM = 30              -- engine units a metre: the heroes are about 48 tall
constant kCell = 64           -- maze cell, engine units (about 2 m corridors)
constant kWallH = 44          -- wall height
constant kRooms = 6           -- maze size in rooms (the grid is 2 * kRooms + 1 square)
constant kTurn = 0.06         -- radians a step
constant kGap = 46            -- the follower stops this far behind
constant kCamBack = 105       -- camera distance behind the hero
constant kCamUp = 70          -- camera height
constant kIdleClip = "Video_To_Mocap_Example_1"
constant kPromptColor = "#40E0FF"
constant kGlazeColor = "#FF60D0"

local sStepMS = 33, sTicks = 0
local sGrid, sCols, sRows, sLeft, sTop, sSeed
local sClip          -- [walk|idle][frames|fps|travel]
local sHero          -- [PROMPT|GLAZE][key|x|z|yaw|anim|frame|color|path|pathTo|skills]
local sActive        -- "PROMPT" or "GLAZE"
local sKeyWas, sTestKeys, sError
local sCamX, sCamY, sCamZ, sBeacon, sExitCell, sNextMazeAt, sMsgUntil

-------------------------------------------------------------------- engine hooks

on Game.OnStart
   Engine.ResetCamera
   put Engine.Info("stepMS") into sStepMS
   if sStepMS is not a number then put 33 into sStepMS
   Scene.ClearAll
   Particles.Clear
   HUD.Clear
   Collision.ClearRules
   put 0 into sTicks
   put empty into sError
   put empty into sTestKeys
   put 1 into sSeed
   Heroes.LoadLibraries
   if sError is empty then Heroes.LoadClips
   if sError is not empty then
      HUD.Set "Heroes.Err", sError, gViewLeft + 20, gViewTop + 20, 14
      exit Game.OnStart
   end if
   Heroes.NewMaze
end Game.OnStart

on Game.OnUpdate
   if sError is not empty then exit Game.OnUpdate
   add 1 to sTicks
   if sNextMazeAt is not empty and sTicks >= sNextMazeAt then
      add 1 to sSeed
      Heroes.NewMaze
      exit Game.OnUpdate
   end if
   Heroes.Controls
   Heroes.Follow
   Heroes.Animate "PROMPT"
   Heroes.Animate "GLAZE"
   Heroes.Camera false
   Heroes.CheckExit
   Heroes.ShowHUD
end Game.OnUpdate

on Game.OnClick pX,pY,pButton
end Game.OnClick

on Game.OnKill pKey,pX,pY,pZ
end Game.OnKill

on Game.OnPause
end Game.OnPause

on Game.OnResume
end Game.OnResume

on Game.OnStop
   HUD.Clear
end Game.OnStop

on Collision.Hit pA,pB
end Collision.Hit

-------------------------------------------------------------------- loading

on Heroes.LoadLibraries
   local tLib, tName
   repeat for each item tName in "LIB_BIT/livecode/lib_bit.livecodescript,LIB_MAP/livecode/lib_map.livecodescript"
      put Heroes.FindFile(tName) into tLib
      if tLib is empty then
         put "HEROES: NOT FOUND " & toUpper(tName) into sError
         exit Heroes.LoadLibraries
      end if
      start using stack tLib
   end repeat
end Heroes.LoadLibraries

-- walk and idle stick clips from LIB_MOCAP; one engine mesh per frame
on Heroes.LoadClips
   local tWhich, tFile
   put empty into sClip
   repeat for each item tWhich in "walk,idle"
      if tWhich is "walk" then
         put Heroes.FindFile("LIB_MOCAP/library/proc_walk/proc_walk_stick.txt") into tFile
      else
         put Heroes.FindFile("LIB_MOCAP/library/" & kIdleClip & "/" & kIdleClip & "_stick.txt") into tFile
      end if
      if tFile is empty then
         put "HEROES: NO " & toUpper(tWhich) & " CLIP IN LIB_MOCAP/LIBRARY" into sError
         exit Heroes.LoadClips
      end if
      Heroes.LoadClip tWhich, URL ("file:" & tFile)
   end repeat
end Heroes.LoadClips

on Heroes.LoadClip pWhich, pText
   local tLine, tEdges, tFrames, tM, tV, i, tJoints, tE, tA, tB
   put 0 into tFrames
   repeat for each line tLine in pText
      if tLine is empty or char 1 of tLine is "#" then next repeat
      set the itemDel to comma
      switch item 1 of tLine
         case "fps"
            put item 2 of tLine into sClip[pWhich]["fps"]
            break
         case "travel"
            put item 2 of tLine into sClip[pWhich]["travel"]
            break
         case "joints"
            put item 2 of tLine into tJoints
            break
         case "edges"
            put item 2 of tLine into tEdges
            break
         default
            if char 1 of tLine is "-" or char 1 of tLine is a number then
               add 1 to tFrames
               put tLine into tV
               split tV by comma
               put Mesh.New() into tM
               repeat with i = 0 to tJoints - 1
                  Mesh.AddVertex tM, tV[3 * i + 1] * kM, -tV[3 * i + 2] * kM, tV[3 * i + 3] * kM
               end repeat
               repeat for each word tE in tEdges
                  set the itemDel to "-"
                  put item 1 of tE + 1 into tA
                  put item 2 of tE + 1 into tB
                  set the itemDel to comma
                  Mesh.AddLine tM, tA, tB
               end repeat
               Mesh.Define "Heroes." & pWhich & tFrames, tM
            end if
      end switch
   end repeat
   put tFrames into sClip[pWhich]["frames"]
   if sClip[pWhich]["fps"] is not a number then put 30 into sClip[pWhich]["fps"]
end Heroes.LoadClip

-------------------------------------------------------------------- the maze

on Heroes.NewMaze
   local tSegs, tName, tC, tR
   Scene.ClearAll
   HUD.Clear
   put empty into sNextMazeAt
   put empty into sMsgUntil
   put Bit.Maze(kRooms, kRooms, sSeed) into sGrid
   put the number of chars of line 1 of sGrid into sCols
   put the number of lines of sGrid into sRows
   put -sCols * kCell / 2 into sLeft
   put sRows * kCell / 2 into sTop
   Mesh.Define "Heroes.Walls", Heroes.SegmentsToMesh(Map.BlockEdges(sGrid, kCell, kWallH, false))
   Mesh.Define "Heroes.Floor", Heroes.SegmentsToMesh(Map.BlockEdges(Bit.Blank(sCols, sRows), kCell, 0, true))
   get Entity.Spawn("Heroes.Floor", 0, 0, 0, "#1F4A5A")
   get Entity.Spawn("Heroes.Walls", 0, 0, 0, "#7FA8FF")
   -- the beacon: far corner room
   put (2 * kRooms) & comma & (2 * kRooms) into sExitCell
   Mesh.Define "Heroes.Beacon", Heroes.BeaconMesh()
   put Entity.Spawn("Heroes.Beacon", Heroes.CellX(2 * kRooms), 0, Heroes.CellZ(2 * kRooms), "#FFD040") into sBeacon
   SetObjectRotationSpeed sBeacon, 0, 0.05, 0
   -- the heroes, side by side in the first room, facing down the first corridor
   Heroes.Spawn "PROMPT", kPromptColor, Heroes.CellX(2) - 12, Heroes.CellZ(2)
   Heroes.Spawn "GLAZE", kGlazeColor, Heroes.CellX(2) + 12, Heroes.CellZ(2) - 20
   put "PROMPT" into sActive
   put Heroes.FirstHeading() into sHero["PROMPT"]["yaw"]
   put sHero["PROMPT"]["yaw"] into sHero["GLAZE"]["yaw"]
   Heroes.Camera true
end Heroes.NewMaze

-- facing the open neighbour of the first room
function Heroes.FirstHeading
   if Heroes.Open(3, 2) then return pi / 2       -- east (+X)
   return 0                                       -- south (+Z)
end Heroes.FirstHeading

function Heroes.CellX pCol
   return sLeft + (pCol - 0.5) * kCell
end Heroes.CellX

function Heroes.CellZ pRow
   return -sTop + (pRow - 0.5) * kCell
end Heroes.CellZ

function Heroes.CellAt pX, pZ
   return (trunc((pX - sLeft) / kCell) + 1) & comma & (trunc((pZ + sTop) / kCell) + 1)
end Heroes.CellAt

function Heroes.Open pCol, pRow
   if pCol < 1 or pRow < 1 or pCol > sCols or pRow > sRows then return false
   return char pCol of line pRow of sGrid is "0"
end Heroes.Open

-- a hero (a circle of radius 12) fits at x,z
function Heroes.Fits pX, pZ
   local dx, dz, tCell
   repeat for each item dx in "-12,12"
      repeat for each item dz in "-12,12"
         put Heroes.CellAt(pX + dx, pZ + dz) into tCell
         if not Heroes.Open(item 1 of tCell, item 2 of tCell) then return false
      end repeat
   end repeat
   return true
end Heroes.Fits

-- move a hero by dx,dz, sliding along walls; returns the distance moved
function Heroes.TryMove pName, pDX, pDZ
   local tX, tZ, tMoved
   put sHero[pName]["x"] into tX
   put sHero[pName]["z"] into tZ
   if Heroes.Fits(tX + pDX, tZ + pDZ) then
      add pDX to tX
      add pDZ to tZ
   else if Heroes.Fits(tX + pDX, tZ) then
      add pDX to tX
   else if Heroes.Fits(tX, tZ + pDZ) then
      add pDZ to tZ
   end if
   put sqrt((tX - sHero[pName]["x"]) ^ 2 + (tZ - sHero[pName]["z"]) ^ 2) into tMoved
   put tX into sHero[pName]["x"]
   put tZ into sHero[pName]["z"]
   return tMoved
end Heroes.TryMove

-------------------------------------------------------------------- heroes

on Heroes.Spawn pName, pColor, pX, pZ
   put Entity.Spawn("Heroes.idle1", pX, 0, pZ, pColor) into sHero[pName]["key"]
   put pX into sHero[pName]["x"]
   put pZ into sHero[pName]["z"]
   put 0 into sHero[pName]["yaw"]
   put "idle" into sHero[pName]["anim"]
   put random(sClip["idle"]["frames"]) into sHero[pName]["frame"]
   put 0 into sHero[pName]["speed"]
   put pColor into sHero[pName]["color"]
   put empty into sHero[pName]["path"]
   if pName is "PROMPT" then
      put "GETS THE JOB DONE NO MATTER WHAT" into sHero[pName]["skills"]
   else
      put "BARTER 9  CHARM 9  INFLUENCE 9" into sHero[pName]["skills"]
   end if
end Heroes.Spawn

-- the walking speed the clip's feet were made for, in engine units a step
function Heroes.WalkStep
   return sClip["walk"]["travel"] * kM * sStepMS / 1000
end Heroes.WalkStep

on Heroes.Controls
   local tKeys, tF, tTurn, tName, tDX, tDZ, tStep
   put Heroes.Keys() into tKeys
   -- TAB, once per press
   if 65289 is among the items of tKeys or 9 is among the items of tKeys then
      if sKeyWas["tab"] is not true then Heroes.Switch
      put true into sKeyWas["tab"]
   else
      put false into sKeyWas["tab"]
   end if
   put sActive into tName
   put 0 into tF
   put 0 into tTurn
   if 119 is among the items of tKeys or 87 is among the items of tKeys or 65362 is among the items of tKeys then add 1 to tF
   if 115 is among the items of tKeys or 83 is among the items of tKeys or 65364 is among the items of tKeys then subtract 0.5 from tF
   if 97 is among the items of tKeys or 65 is among the items of tKeys or 65361 is among the items of tKeys then subtract kTurn from tTurn
   if 100 is among the items of tKeys or 68 is among the items of tKeys or 65363 is among the items of tKeys then add kTurn to tTurn
   add tTurn to sHero[tName]["yaw"]
   -- Shift: hurry (the walk clip plays faster too, so the feet still match the ground)
   if 65505 is among the items of tKeys or 65506 is among the items of tKeys then put tF * 1.8 into tF
   put Heroes.WalkStep() * tF into tStep
   put sin(sHero[tName]["yaw"]) * tStep into tDX
   put cos(sHero[tName]["yaw"]) * tStep into tDZ
   put Heroes.TryMove(tName, tDX, tDZ) into sHero[tName]["speed"]
   if tF < 0 then put -sHero[tName]["speed"] into sHero[tName]["speed"]
end Heroes.Controls

on Heroes.Switch
   if sActive is "PROMPT" then
      put "GLAZE" into sActive
   else
      put "PROMPT" into sActive
   end if
   put empty into sHero["PROMPT"]["path"]
   put empty into sHero["GLAZE"]["path"]
   put sTicks + 45 into sMsgUntil
end Heroes.Switch

-- the hero you are not playing walks after the one you are: along a LIB_MAP path when
-- it is more than a room away, straight at you when close
on Heroes.Follow
   local tMe, tLead, dx, dz, tDist, tMyCell, tLeadCell, tNext, tTX, tTZ, tStep, tMoved
   if sActive is "PROMPT" then
      put "GLAZE" into tMe
   else
      put "PROMPT" into tMe
   end if
   put sActive into tLead
   put sHero[tLead]["x"] - sHero[tMe]["x"] into dx
   put sHero[tLead]["z"] - sHero[tMe]["z"] into dz
   put sqrt(dx * dx + dz * dz) into tDist
   if tDist <= kGap then
      put 0 into sHero[tMe]["speed"]
      exit Heroes.Follow
   end if
   put Heroes.CellAt(sHero[tMe]["x"], sHero[tMe]["z"]) into tMyCell
   put Heroes.CellAt(sHero[tLead]["x"], sHero[tLead]["z"]) into tLeadCell
   put sHero[tLead]["x"] into tTX
   put sHero[tLead]["z"] into tTZ
   if tMyCell is not tLeadCell and not Heroes.Neighbours(tMyCell, tLeadCell) then
      if sHero[tMe]["pathTo"] is not tLeadCell or tMyCell is not among the lines of sHero[tMe]["path"] then
         put Map.FindPath(sGrid, tMyCell, tLeadCell, false) into sHero[tMe]["path"]
         put tLeadCell into sHero[tMe]["pathTo"]
      end if
      put lineOffset(tMyCell, sHero[tMe]["path"]) into tNext
      if tNext > 0 and tNext < the number of lines of sHero[tMe]["path"] then
         put line tNext + 1 of sHero[tMe]["path"] into tNext
         put Heroes.CellX(item 1 of tNext) into tTX
         put Heroes.CellZ(item 2 of tNext) into tTZ
      end if
      put tTX - sHero[tMe]["x"] into dx
      put tTZ - sHero[tMe]["z"] into dz
      put sqrt(dx * dx + dz * dz) into tDist
   end if
   if tDist < 0.01 then exit Heroes.Follow
   -- a little faster than walking, and hurrying when more than two rooms behind
   if sqrt((sHero[tLead]["x"] - sHero[tMe]["x"]) ^ 2 + (sHero[tLead]["z"] - sHero[tMe]["z"]) ^ 2) > 2 * kCell then
      put Heroes.WalkStep() * 1.9 into tStep
   else
      put Heroes.WalkStep() * 1.15 into tStep
   end if
   put min(tStep, tDist) into tStep
   put Heroes.TryMove(tMe, dx / tDist * tStep, dz / tDist * tStep) into tMoved
   put tMoved into sHero[tMe]["speed"]
   if tMoved > 0.1 then put Heroes.TurnToward(sHero[tMe]["yaw"], atan2(dx, dz), 0.25) into sHero[tMe]["yaw"]
end Heroes.Follow

function Heroes.Neighbours pA, pB
   return abs(item 1 of pA - item 1 of pB) + abs(item 2 of pA - item 2 of pB) is 1
end Heroes.Neighbours

function Heroes.TurnToward pFrom, pTo, pRate
   local d
   put pTo - pFrom into d
   repeat while d > pi
      subtract 2 * pi from d
   end repeat
   repeat while d < -pi
      add 2 * pi to d
   end repeat
   return pFrom + d * pRate
end Heroes.TurnToward

-- walking plays the walk clip at the speed the hero really moves (no skating);
-- standing plays the idle clip
on Heroes.Animate pName
   local tSpeed, tClip, tN, tF, tKey, tE
   put sHero[pName]["speed"] into tSpeed
   if abs(tSpeed) > 0.2 then
      put "walk" into tClip
   else
      put "idle" into tClip
   end if
   if tClip is not sHero[pName]["anim"] then
      put tClip into sHero[pName]["anim"]
      if tClip is "walk" then put 1 into sHero[pName]["frame"]
   end if
   put sClip[tClip]["frames"] into tN
   if tClip is "walk" then
      add tSpeed / Heroes.WalkStep() * sClip["walk"]["fps"] * sStepMS / 1000 to sHero[pName]["frame"]
   else
      add sClip["idle"]["fps"] * sStepMS / 1000 to sHero[pName]["frame"]
   end if
   repeat while sHero[pName]["frame"] >= tN + 1
      subtract tN from sHero[pName]["frame"]
   end repeat
   repeat while sHero[pName]["frame"] < 1
      add tN to sHero[pName]["frame"]
   end repeat
   put sHero[pName]["key"] into tKey
   Heroes.SetMesh tKey, "Heroes." & tClip & trunc(sHero[pName]["frame"])
   SetObjectPosition tKey, sHero[pName]["x"], 0, sHero[pName]["z"]
   put Heroes.Euler(sHero[pName]["yaw"], 0) into tE
   SetObjectRotation tKey, item 1 of tE, item 2 of tE, item 3 of tE
end Heroes.Animate

-------------------------------------------------------------------- camera, beacon, HUD

-- behind and above the hero you play, looking at its chest; pSnap jumps there at once
on Heroes.Camera pSnap
   local tH, tX, tZ, tCX, tCY, tCZ, tK, tLY
   put sHero[sActive]["yaw"] into tH
   put sHero[sActive]["x"] into tX
   put sHero[sActive]["z"] into tZ
   put tX - sin(tH) * kCamBack into tCX
   put -kCamUp into tCY
   put tZ - cos(tH) * kCamBack into tCZ
   if pSnap or sCamX is not a number then
      put tCX into sCamX
      put tCY into sCamY
      put tCZ into sCamZ
   else
      put 0.12 into tK
      put sCamX + (tCX - sCamX) * tK into sCamX
      put sCamY + (tCY - sCamY) * tK into sCamY
      put sCamZ + (tCZ - sCamZ) * tK into sCamZ
   end if
   put -1.0 * kM into tLY        -- chest height (up is -Y)
   put atan2(tX - sCamX, tZ - sCamZ) into gCameraYaw
   put -atan2(tLY - sCamY, sqrt((tX - sCamX) ^ 2 + (tZ - sCamZ) ^ 2)) into gCameraPitch
   Engine.SetCam -sCamX, -sCamY, -sCamZ
end Heroes.Camera

on Heroes.CheckExit
   local tA, tB
   if sNextMazeAt is not empty then exit Heroes.CheckExit
   put Heroes.CellAt(sHero["PROMPT"]["x"], sHero["PROMPT"]["z"]) into tA
   put Heroes.CellAt(sHero["GLAZE"]["x"], sHero["GLAZE"]["z"]) into tB
   if tA is sExitCell and tB is sExitCell then
      put sTicks + round(2500 / sStepMS) into sNextMazeAt
      HUD.Set "Heroes.Msg", "MAZE CLEARED  NEW MAZE COMING", gViewLeft + 20, gViewTop + 130, 18
   end if
end Heroes.CheckExit

on Heroes.ShowHUD
   local tOther
   if sActive is "PROMPT" then
      put "GLAZE" into tOther
   else
      put "PROMPT" into tOther
   end if
   HUD.Set "Heroes.Who", "PLAYING " & sActive & "   (TAB: " & tOther & ")", gViewLeft + 20, gViewBottom - 78, 14
   HUD.Set "Heroes.Skills", sHero[sActive]["skills"], gViewLeft + 20, gViewBottom - 56, 11
   HUD.Set "Heroes.Help", "W S WALK   SHIFT HURRY   A D TURN   FIND THE GOLD BEACON", gViewLeft + 20, gViewBottom - 30, 11
   if sMsgUntil is a number and sTicks < sMsgUntil then
      HUD.Set "Heroes.Swap", sActive, gViewLeft + 20, gViewTop + 130, 24
   else
      HUD.Remove "Heroes.Swap"
   end if
end Heroes.ShowHUD

-------------------------------------------------------------------- helpers

-- the keys held down; Heroes.TestKeys lets a test drive the game without a keyboard
function Heroes.Keys
   if sTestKeys is not empty then return sTestKeys
   return the keysDown
end Heroes.Keys

on Heroes.TestKeys pKeys
   put pKeys into sTestKeys
end Heroes.TestKeys

-- tests: put the hero you play in room-grid cell pCol,pRow
on Heroes.TestPlace pCol, pRow
   put Heroes.CellX(pCol) into sHero[sActive]["x"]
   put Heroes.CellZ(pRow) into sHero[sActive]["z"]
end Heroes.TestPlace

function Heroes.State
   return sActive & "|" & round(sHero["PROMPT"]["x"]) & "," & round(sHero["PROMPT"]["z"]) & "|" & \
         round(sHero["GLAZE"]["x"]) & "," & round(sHero["GLAZE"]["z"]) & "|" & sHero["PROMPT"]["anim"] & "," & sHero["GLAZE"]["anim"] & \
         "|" & Heroes.CellAt(sHero["PROMPT"]["x"], sHero["PROMPT"]["z"]) & ";" & Heroes.CellAt(sHero["GLAZE"]["x"], sHero["GLAZE"]["z"])
end Heroes.State

-- swap the mesh an object is drawn with (from Antack)
on Heroes.SetMesh pKey, pMesh
   local tOut, tLine
   if gObjectTransforms[pKey]["mesh"] is pMesh then exit Heroes.SetMesh
   repeat for each line tLine in gSceneObjects
      if word 2 of tLine is pKey then put pMesh into word 1 of tLine
      put tLine & cr after tOut
   end repeat
   delete the last char of tOut
   put tOut into gSceneObjects
   put pMesh into gObjectTransforms[pKey]["mesh"]
end Heroes.SetMesh

-- engine rotation angles for a heading (from Antack.Euler; up is -Y)
function Heroes.Euler pYaw, pPitch
   local sy, cy, sp, cp
   put sin(pYaw) into sy
   put cos(pYaw) into cy
   put sin(pPitch) into sp
   put cos(pPitch) into cp
   return atan2(sp, cy * cp) & comma & asin(max(-1, min(1, sy * cp))) & comma & atan2(-sy * sp, cy)
end Heroes.Euler

-- LIB_MAP segments (x1,y1,z1,x2,y2,z2; the picture's y runs north, z is height) as an
-- engine wire mesh: x stays, height goes up (-Y), north goes away (-Z)
function Heroes.SegmentsToMesh pSegments
   local tMesh, tSeg, tIndex, tA, tB
   put Mesh.New() into tMesh
   set the itemDel to comma
   repeat for each line tSeg in pSegments
      if the number of items of tSeg < 6 then next repeat
      put Heroes.Vertex(tMesh, tIndex, item 1 of tSeg, item 2 of tSeg, item 3 of tSeg) into tA
      put Heroes.Vertex(tMesh, tIndex, item 4 of tSeg, item 5 of tSeg, item 6 of tSeg) into tB
      Mesh.AddLine tMesh, tA, tB
   end repeat
   return tMesh
end Heroes.SegmentsToMesh

function Heroes.Vertex @pMesh, @pIndex, pX, pY, pZ
   local tKey
   put pX & "," & pY & "," & pZ into tKey
   if pIndex[tKey] is empty then
      Mesh.AddVertex pMesh, pX, -pZ, -pY
      put the result into pIndex[tKey]
   end if
   return pIndex[tKey]
end Heroes.Vertex

-- a gold diamond standing on the floor
function Heroes.BeaconMesh
   local tM, tTop, tBot, tA, tB, tC, tD
   put Mesh.New() into tM
   Mesh.AddVertex tM, 0, -64, 0
   put the result into tTop
   Mesh.AddVertex tM, 0, -4, 0
   put the result into tBot
   Mesh.AddVertex tM, 12, -34, 0
   put the result into tA
   Mesh.AddVertex tM, 0, -34, 12
   put the result into tB
   Mesh.AddVertex tM, -12, -34, 0
   put the result into tC
   Mesh.AddVertex tM, 0, -34, -12
   put the result into tD
   Mesh.AddLine tM, tA, tB
   Mesh.AddLine tM, tB, tC
   Mesh.AddLine tM, tC, tD
   Mesh.AddLine tM, tD, tA
   repeat for each item tB in tA & "," & (tA + 1) & "," & (tA + 2) & "," & (tA + 3)
      Mesh.AddLine tM, tTop, tB
      Mesh.AddLine tM, tBot, tB
   end repeat
   return tM
end Heroes.BeaconMesh

-- looks for pRelPath in the folders above this stack, then in the WSL projects folder
function Heroes.FindFile pRelPath
   local tPath, tTry
   put the effective filename of this stack into tPath
   set the itemDel to "/"
   repeat 6 times
      delete item -1 of tPath
      if tPath is empty then exit repeat
      put tPath & "/" & pRelPath into tTry
      if there is a file tTry then return tTry
   end repeat
   put "//wsl$/Ubuntu/home/igame3d/projects/" & pRelPath into tTry
   if there is a file tTry then return tTry
   return empty
end Heroes.FindFile
