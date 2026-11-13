######################################################################################
## CARD SCRIPT: "Play.Companions"   PROMPT & GLAZE, third-person companions  (11 12 2026)
## Third person in a vector maze. PROMPT (cyan) and GLAZE (magenta) are minimal stick
## figures driven by LIB_MOCAP clips. You play one; the other follows you through the
## maze on its own (LIB_MAP path finding). TAB swaps who you play. Bring both to the
## gold beacon in the far corner and a new maze is built. Each hero has its own captured
## walk and idle (LIB_MOCAP library); Shift runs (a captured jog).
## CONTROLS  W / up arrow  walk        S / down arrow  step back     Shift  run
##           A D / left right arrows   turn                TAB  switch hero
## SKILLS    PROMPT gets the job done no matter what; GLAZE: barter, charm, influence.
##           Shown on screen, not used yet.
## NEEDS     ../LIB_BIT, ../LIB_MAP and ../LIB_MOCAP/library (the clips named below).
######################################################################################

global gObjectTransforms, gSceneObjects
global gCameraYaw, gCameraPitch
global gViewLeft, gViewTop, gViewRight, gViewBottom
global bPaused, bPlaying

constant kM = 30              -- engine units a metre: the heroes are about 48 tall
constant kCell = 76           -- maze cell, engine units (about 2.5 m corridors)
constant kWallH = 58          -- wall height (the heroes are about 52 tall)
constant kRooms = 6           -- maze size in rooms (the grid is 2 * kRooms + 1 square)
constant kTurn = 0.06         -- radians a step
constant kGap = 46            -- the follower stops this far behind
constant kCamBack = 105       -- camera distance behind the hero
constant kCamUp = 88          -- camera height
-- LIB_MOCAP clips (library/<name>/<name>_stick.txt); walks and runs loop their "cycle"
constant kPromptWalk = "Animazoo_gangster_walk"
constant kPromptIdle = "Animazoo_hands_on_hips"
constant kGlazeWalk = "Animazoo_walking_waving"
constant kGlazeIdle = "Animazoo_talking_gesturing"
constant kRun = "Animazoo_Running_-_Jog"
constant kMaxIdleFrames = 300   -- longer idles are cut to their first 10 seconds
constant kPromptColor = "#40E0FF"
constant kGlazeColor = "#FF60D0"

local sStepMS = 33, sTicks = 0
local sGrid, sCols, sRows, sLeft, sTop, sSeed
local sClip          -- [clip name][frames|fps|travel]; meshes "Companions.<clip>.<n>"
local sHero          -- [PROMPT|GLAZE][key|x|z|yaw|anim|frame|speed|color|path|pathTo|skills|walk|idle|run]
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
   Companions.LoadLibraries
   if sError is empty then Companions.LoadClips
   if sError is not empty then
      HUD.Set "Companions.Err", sError, gViewLeft + 20, gViewTop + 20, 14
      exit Game.OnStart
   end if
   Companions.NewMaze
end Game.OnStart

on Game.OnUpdate
   if sError is not empty then exit Game.OnUpdate
   add 1 to sTicks
   if sNextMazeAt is not empty and sTicks >= sNextMazeAt then
      add 1 to sSeed
      Companions.NewMaze
      exit Game.OnUpdate
   end if
   Companions.Controls
   Companions.Follow
   Companions.Animate "PROMPT"
   Companions.Animate "GLAZE"
   Companions.Camera false
   Companions.CheckExit
   Companions.ShowHUD
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

on Companions.LoadLibraries
   local tLib, tName
   repeat for each item tName in "LIB_BIT/livecode/lib_bit.livecodescript,LIB_MAP/livecode/lib_map.livecodescript"
      put Companions.FindFile(tName) into tLib
      if tLib is empty then
         put "COMPANIONS: NOT FOUND " & toUpper(tName) into sError
         exit Companions.LoadLibraries
      end if
      start using stack tLib
   end repeat
end Companions.LoadLibraries

-- walk and idle stick clips from LIB_MOCAP; one engine mesh per frame
-- every clip the heroes use, from LIB_MOCAP; one engine mesh per frame
on Companions.LoadClips
   local tName, tFile
   put empty into sClip
   repeat for each item tName in kPromptWalk & comma & kPromptIdle & comma & kGlazeWalk & comma & kGlazeIdle & comma & kRun
      if sClip[tName]["frames"] is a number then next repeat
      put Companions.FindFile("LIB_MOCAP/library/" & tName & "/" & tName & "_stick.txt") into tFile
      if tFile is empty then
         put "COMPANIONS: NO CLIP " & toUpper(tName) & " IN LIB_MOCAP/LIBRARY" into sError
         exit Companions.LoadClips
      end if
      Companions.LoadClip tName, URL ("file:" & tFile)
   end repeat
end Companions.LoadClips

-- a stick clip: only its cycle when it has one (walks, runs), else up to kMaxIdleFrames
on Companions.LoadClip pName, pText
   local tLine, tEdges, tFrame, tKept, tM, tV, i, tJoints, tE, tA, tB, tFrom, tTo
   put 0 into tFrame
   put 0 into tKept
   put 1 into tFrom
   put kMaxIdleFrames into tTo
   repeat for each line tLine in pText
      if tLine is empty or char 1 of tLine is "#" then next repeat
      set the itemDel to comma
      switch item 1 of tLine
         case "fps"
            put item 2 of tLine into sClip[pName]["fps"]
            break
         case "travel"
            if sClip[pName]["travel"] is empty then put item 2 of tLine into sClip[pName]["travel"]
            break
         case "cycle"
            put item 2 of tLine into tFrom
            put item 3 of tLine into tTo
            break
         case "cycle_travel"
            put item 2 of tLine into sClip[pName]["travel"]
            break
         case "joints"
            put item 2 of tLine into tJoints
            break
         case "edges"
            put item 2 of tLine into tEdges
            break
         default
            if char 1 of tLine is "-" or char 1 of tLine is a number then
               add 1 to tFrame
               if tFrame < tFrom or tFrame > tTo then next repeat
               add 1 to tKept
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
               Mesh.Define "Companions." & pName & "." & tKept, tM
            end if
      end switch
   end repeat
   put tKept into sClip[pName]["frames"]
   if sClip[pName]["fps"] is not a number then put 30 into sClip[pName]["fps"]
   if sClip[pName]["travel"] is not a number then put 0 into sClip[pName]["travel"]
end Companions.LoadClip

-------------------------------------------------------------------- the maze

on Companions.NewMaze
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
   Mesh.Define "Companions.Walls", Companions.SegmentsToMesh(Map.BlockEdges(sGrid, kCell, kWallH, false))
   Mesh.Define "Companions.Floor", Companions.SegmentsToMesh(Map.BlockEdges(Bit.Blank(sCols, sRows), kCell, 0, true))
   get Entity.Spawn("Companions.Floor", 0, 0, 0, "#1F4A5A")
   get Entity.Spawn("Companions.Walls", 0, 0, 0, "#7FA8FF")
   -- the beacon: far corner room
   put (2 * kRooms) & comma & (2 * kRooms) into sExitCell
   Mesh.Define "Companions.Beacon", Companions.BeaconMesh()
   put Entity.Spawn("Companions.Beacon", Companions.CellX(2 * kRooms), 0, Companions.CellZ(2 * kRooms), "#FFD040") into sBeacon
   SetObjectRotationSpeed sBeacon, 0, 0.05, 0
   -- the heroes, side by side in the first room, facing down the first corridor
   Companions.Spawn "PROMPT", kPromptColor, Companions.CellX(2) - 12, Companions.CellZ(2)
   Companions.Spawn "GLAZE", kGlazeColor, Companions.CellX(2) + 12, Companions.CellZ(2) - 20
   put "PROMPT" into sActive
   put Companions.FirstHeading() into sHero["PROMPT"]["yaw"]
   put sHero["PROMPT"]["yaw"] into sHero["GLAZE"]["yaw"]
   Companions.Camera true
end Companions.NewMaze

-- facing the open neighbour of the first room
function Companions.FirstHeading
   if Companions.Open(3, 2) then return pi / 2       -- east (+X)
   return 0                                       -- south (+Z)
end Companions.FirstHeading

function Companions.CellX pCol
   return sLeft + (pCol - 0.5) * kCell
end Companions.CellX

function Companions.CellZ pRow
   return -sTop + (pRow - 0.5) * kCell
end Companions.CellZ

function Companions.CellAt pX, pZ
   return (trunc((pX - sLeft) / kCell) + 1) & comma & (trunc((pZ + sTop) / kCell) + 1)
end Companions.CellAt

function Companions.Open pCol, pRow
   if pCol < 1 or pRow < 1 or pCol > sCols or pRow > sRows then return false
   return char pCol of line pRow of sGrid is "0"
end Companions.Open

-- a hero (a circle of radius 12) fits at x,z
function Companions.Fits pX, pZ
   local dx, dz, tCell
   repeat for each item dx in "-12,12"
      repeat for each item dz in "-12,12"
         put Companions.CellAt(pX + dx, pZ + dz) into tCell
         if not Companions.Open(item 1 of tCell, item 2 of tCell) then return false
      end repeat
   end repeat
   return true
end Companions.Fits

-- move a hero by dx,dz, sliding along walls; returns the distance moved
function Companions.TryMove pName, pDX, pDZ
   local tX, tZ, tMoved
   put sHero[pName]["x"] into tX
   put sHero[pName]["z"] into tZ
   if Companions.Fits(tX + pDX, tZ + pDZ) then
      add pDX to tX
      add pDZ to tZ
   else if Companions.Fits(tX + pDX, tZ) then
      add pDX to tX
   else if Companions.Fits(tX, tZ + pDZ) then
      add pDZ to tZ
   end if
   put sqrt((tX - sHero[pName]["x"]) ^ 2 + (tZ - sHero[pName]["z"]) ^ 2) into tMoved
   put tX into sHero[pName]["x"]
   put tZ into sHero[pName]["z"]
   return tMoved
end Companions.TryMove

-------------------------------------------------------------------- heroes

on Companions.Spawn pName, pColor, pX, pZ
   if pName is "PROMPT" then
      put kPromptWalk into sHero[pName]["walk"]
      put kPromptIdle into sHero[pName]["idle"]
      put "GETS THE JOB DONE NO MATTER WHAT" into sHero[pName]["skills"]
   else
      put kGlazeWalk into sHero[pName]["walk"]
      put kGlazeIdle into sHero[pName]["idle"]
      put "BARTER 9  CHARM 9  INFLUENCE 9" into sHero[pName]["skills"]
   end if
   put kRun into sHero[pName]["run"]
   put Entity.Spawn("Companions." & sHero[pName]["idle"] & ".1", pX, 0, pZ, pColor) into sHero[pName]["key"]
   put pX into sHero[pName]["x"]
   put pZ into sHero[pName]["z"]
   put 0 into sHero[pName]["yaw"]
   put "idle" into sHero[pName]["anim"]
   put random(sClip[sHero[pName]["idle"]]["frames"]) into sHero[pName]["frame"]
   put 0 into sHero[pName]["speed"]
   put pColor into sHero[pName]["color"]
   put empty into sHero[pName]["path"]
end Companions.Spawn

-- the walking speed the clip's feet were made for, in engine units a step
-- how far a hero's clip moves in one step, engine units (pWhich: walk or run)
function Companions.WalkStep pName, pWhich
   if pWhich is empty then put "walk" into pWhich
   return sClip[sHero[pName][pWhich]]["travel"] * kM * sStepMS / 1000
end Companions.WalkStep

on Companions.Controls
   local tKeys, tF, tTurn, tName, tDX, tDZ, tStep
   put Companions.Keys() into tKeys
   -- TAB, once per press
   if 65289 is among the items of tKeys or 9 is among the items of tKeys then
      if sKeyWas["tab"] is not true then Companions.Switch
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
   -- Shift runs (forward only)
   if tF > 0 and (65505 is among the items of tKeys or 65506 is among the items of tKeys) then
      put Companions.WalkStep(tName, "run") * tF into tStep
   else
      put Companions.WalkStep(tName, "walk") * tF into tStep
   end if
   put sin(sHero[tName]["yaw"]) * tStep into tDX
   put cos(sHero[tName]["yaw"]) * tStep into tDZ
   put Companions.TryMove(tName, tDX, tDZ) into sHero[tName]["speed"]
   if tF < 0 then put -sHero[tName]["speed"] into sHero[tName]["speed"]
end Companions.Controls

on Companions.Switch
   if sActive is "PROMPT" then
      put "GLAZE" into sActive
   else
      put "PROMPT" into sActive
   end if
   put empty into sHero["PROMPT"]["path"]
   put empty into sHero["GLAZE"]["path"]
   put sTicks + 45 into sMsgUntil
end Companions.Switch

-- the hero you are not playing walks after the one you are: along a LIB_MAP path when
-- it is more than a room away, straight at you when close
on Companions.Follow
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
      exit Companions.Follow
   end if
   put Companions.CellAt(sHero[tMe]["x"], sHero[tMe]["z"]) into tMyCell
   put Companions.CellAt(sHero[tLead]["x"], sHero[tLead]["z"]) into tLeadCell
   put sHero[tLead]["x"] into tTX
   put sHero[tLead]["z"] into tTZ
   if tMyCell is not tLeadCell and not Companions.Neighbours(tMyCell, tLeadCell) then
      if sHero[tMe]["pathTo"] is not tLeadCell or tMyCell is not among the lines of sHero[tMe]["path"] then
         put Map.FindPath(sGrid, tMyCell, tLeadCell, false) into sHero[tMe]["path"]
         put tLeadCell into sHero[tMe]["pathTo"]
      end if
      put lineOffset(tMyCell, sHero[tMe]["path"]) into tNext
      if tNext > 0 and tNext < the number of lines of sHero[tMe]["path"] then
         put line tNext + 1 of sHero[tMe]["path"] into tNext
         put Companions.CellX(item 1 of tNext) into tTX
         put Companions.CellZ(item 2 of tNext) into tTZ
      end if
      put tTX - sHero[tMe]["x"] into dx
      put tTZ - sHero[tMe]["z"] into dz
      put sqrt(dx * dx + dz * dz) into tDist
   end if
   if tDist < 0.01 then exit Companions.Follow
   -- walking, a little faster than the leader walks; running when more than two rooms behind
   if sqrt((sHero[tLead]["x"] - sHero[tMe]["x"]) ^ 2 + (sHero[tLead]["z"] - sHero[tMe]["z"]) ^ 2) > 2 * kCell then
      put Companions.WalkStep(tMe, "run") into tStep
   else
      put max(Companions.WalkStep(tMe, "walk"), Companions.WalkStep(tLead, "walk") * 1.1) into tStep
   end if
   put min(tStep, tDist) into tStep
   put Companions.TryMove(tMe, dx / tDist * tStep, dz / tDist * tStep) into tMoved
   put tMoved into sHero[tMe]["speed"]
   if tMoved > 0.1 then put Companions.TurnToward(sHero[tMe]["yaw"], atan2(dx, dz), 0.25) into sHero[tMe]["yaw"]
end Companions.Follow

function Companions.Neighbours pA, pB
   return abs(item 1 of pA - item 1 of pB) + abs(item 2 of pA - item 2 of pB) is 1
end Companions.Neighbours

function Companions.TurnToward pFrom, pTo, pRate
   local d
   put pTo - pFrom into d
   repeat while d > pi
      subtract 2 * pi from d
   end repeat
   repeat while d < -pi
      add 2 * pi to d
   end repeat
   return pFrom + d * pRate
end Companions.TurnToward

-- walking plays the walk clip at the speed the hero really moves (no skating);
-- standing plays the idle clip
-- standing: the hero's idle clip. Moving: walk or run, whichever was made for the speed
-- the hero really moves, played at that speed so the feet don't skate
on Companions.Animate pName
   local tSpeed, tWhich, tClip, tN, tKey, tE, tWalk, tRun
   put abs(sHero[pName]["speed"]) into tSpeed
   put Companions.WalkStep(pName, "walk") into tWalk
   put Companions.WalkStep(pName, "run") into tRun
   if tSpeed <= 0.2 then
      put "idle" into tWhich
   else if tSpeed > (tWalk + tRun) / 2 then
      put "run" into tWhich
   else
      put "walk" into tWhich
   end if
   put sHero[pName][tWhich] into tClip
   if tWhich is not sHero[pName]["anim"] then
      put tWhich into sHero[pName]["anim"]
      put 1 into sHero[pName]["frame"]
   end if
   put sClip[tClip]["frames"] into tN
   if tWhich is "idle" then
      add sClip[tClip]["fps"] * sStepMS / 1000 to sHero[pName]["frame"]
   else
      add sHero[pName]["speed"] / Companions.WalkStep(pName, tWhich) * sClip[tClip]["fps"] * sStepMS / 1000 to sHero[pName]["frame"]
   end if
   repeat while sHero[pName]["frame"] >= tN + 1
      subtract tN from sHero[pName]["frame"]
   end repeat
   repeat while sHero[pName]["frame"] < 1
      add tN to sHero[pName]["frame"]
   end repeat
   put sHero[pName]["key"] into tKey
   Companions.SetMesh tKey, "Companions." & tClip & "." & trunc(sHero[pName]["frame"])
   SetObjectPosition tKey, sHero[pName]["x"], 0, sHero[pName]["z"]
   put Companions.Euler(sHero[pName]["yaw"], 0) into tE
   SetObjectRotation tKey, item 1 of tE, item 2 of tE, item 3 of tE
end Companions.Animate

-------------------------------------------------------------------- camera, beacon, HUD

-- behind and above the hero you play, looking at its chest; pSnap jumps there at once
on Companions.Camera pSnap
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
      put 0.22 into tK
      put sCamX + (tCX - sCamX) * tK into sCamX
      put sCamY + (tCY - sCamY) * tK into sCamY
      put sCamZ + (tCZ - sCamZ) * tK into sCamZ
   end if
   put -1.0 * kM into tLY        -- chest height (up is -Y)
   put atan2(tX - sCamX, tZ - sCamZ) into gCameraYaw
   put -atan2(tLY - sCamY, sqrt((tX - sCamX) ^ 2 + (tZ - sCamZ) ^ 2)) into gCameraPitch
   Engine.SetCam -sCamX, -sCamY, -sCamZ
end Companions.Camera

on Companions.CheckExit
   local tA, tB
   if sNextMazeAt is not empty then exit Companions.CheckExit
   put Companions.CellAt(sHero["PROMPT"]["x"], sHero["PROMPT"]["z"]) into tA
   put Companions.CellAt(sHero["GLAZE"]["x"], sHero["GLAZE"]["z"]) into tB
   if tA is sExitCell and tB is sExitCell then
      put sTicks + round(2500 / sStepMS) into sNextMazeAt
      HUD.Set "Companions.Msg", "MAZE CLEARED  NEW MAZE COMING", gViewLeft + 20, gViewTop + 130, 18
   end if
end Companions.CheckExit

on Companions.ShowHUD
   local tOther
   if sActive is "PROMPT" then
      put "GLAZE" into tOther
   else
      put "PROMPT" into tOther
   end if
   HUD.Set "Companions.Who", "PLAYING " & sActive & "   (TAB: " & tOther & ")", gViewLeft + 20, gViewBottom - 78, 14
   HUD.Set "Companions.Skills", sHero[sActive]["skills"], gViewLeft + 20, gViewBottom - 56, 11
   HUD.Set "Companions.Help", "W S WALK   SHIFT RUN   A D TURN   FIND THE GOLD BEACON", gViewLeft + 20, gViewBottom - 30, 11
   if sMsgUntil is a number and sTicks < sMsgUntil then
      HUD.Set "Companions.Swap", sActive, gViewLeft + 20, gViewTop + 130, 24
   else
      HUD.Remove "Companions.Swap"
   end if
end Companions.ShowHUD

-------------------------------------------------------------------- helpers

-- the keys held down; Companions.TestKeys lets a test drive the game without a keyboard
function Companions.Keys
   if sTestKeys is not empty then return sTestKeys
   return the keysDown
end Companions.Keys

on Companions.TestKeys pKeys
   put pKeys into sTestKeys
end Companions.TestKeys

-- tests: put the hero you play in room-grid cell pCol,pRow
on Companions.TestPlace pCol, pRow
   put Companions.CellX(pCol) into sHero[sActive]["x"]
   put Companions.CellZ(pRow) into sHero[sActive]["z"]
end Companions.TestPlace

function Companions.State
   return sActive & "|" & round(sHero["PROMPT"]["x"]) & "," & round(sHero["PROMPT"]["z"]) & "|" & \
         round(sHero["GLAZE"]["x"]) & "," & round(sHero["GLAZE"]["z"]) & "|" & sHero["PROMPT"]["anim"] & "," & sHero["GLAZE"]["anim"] & \
         "|" & Companions.CellAt(sHero["PROMPT"]["x"], sHero["PROMPT"]["z"]) & ";" & Companions.CellAt(sHero["GLAZE"]["x"], sHero["GLAZE"]["z"])
end Companions.State

-- swap the mesh an object is drawn with (from Antack)
on Companions.SetMesh pKey, pMesh
   local tOut, tLine
   if gObjectTransforms[pKey]["mesh"] is pMesh then exit Companions.SetMesh
   repeat for each line tLine in gSceneObjects
      if word 2 of tLine is pKey then put pMesh into word 1 of tLine
      put tLine & cr after tOut
   end repeat
   delete the last char of tOut
   put tOut into gSceneObjects
   put pMesh into gObjectTransforms[pKey]["mesh"]
end Companions.SetMesh

-- engine rotation angles for a heading (from Antack.Euler; up is -Y)
function Companions.Euler pYaw, pPitch
   local sy, cy, sp, cp
   put sin(pYaw) into sy
   put cos(pYaw) into cy
   put sin(pPitch) into sp
   put cos(pPitch) into cp
   return atan2(sp, cy * cp) & comma & asin(max(-1, min(1, sy * cp))) & comma & atan2(-sy * sp, cy)
end Companions.Euler

-- LIB_MAP segments (x1,y1,z1,x2,y2,z2; the picture's y runs north, z is height) as an
-- engine wire mesh: x stays, height goes up (-Y), north goes away (-Z)
function Companions.SegmentsToMesh pSegments
   local tMesh, tSeg, tIndex, tA, tB
   put Mesh.New() into tMesh
   set the itemDel to comma
   repeat for each line tSeg in pSegments
      if the number of items of tSeg < 6 then next repeat
      put Companions.Vertex(tMesh, tIndex, item 1 of tSeg, item 2 of tSeg, item 3 of tSeg) into tA
      put Companions.Vertex(tMesh, tIndex, item 4 of tSeg, item 5 of tSeg, item 6 of tSeg) into tB
      Mesh.AddLine tMesh, tA, tB
   end repeat
   return tMesh
end Companions.SegmentsToMesh

function Companions.Vertex @pMesh, @pIndex, pX, pY, pZ
   local tKey
   put pX & "," & pY & "," & pZ into tKey
   if pIndex[tKey] is empty then
      Mesh.AddVertex pMesh, pX, -pZ, -pY
      put the result into pIndex[tKey]
   end if
   return pIndex[tKey]
end Companions.Vertex

-- a gold diamond standing on the floor
function Companions.BeaconMesh
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
end Companions.BeaconMesh

-- looks for pRelPath in the folders above this stack, then in the WSL projects folder
function Companions.FindFile pRelPath
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
end Companions.FindFile
