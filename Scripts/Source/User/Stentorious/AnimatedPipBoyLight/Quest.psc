Scriptname Stentorious:AnimatedPipBoyLight:Quest extends Quest

; #### VARIABLES ####
bool controlDown = false
int scanCode
int lightStage = 0
; 0 = Waiting for input
; 1 = Holding down control
; 2 = Idle playing
; 3 = Idle finished playing + Holding down control
float modVersion = 0.0
InputEnableLayer inputLayer

; #### PROPERTIES ####

Group Base
	; actors
	Actor Property PlayerRef Auto Const Mandatory
EndGroup

Group Mod
	; formlists
	FormList Property AnimatedPipBoyLightFormList_ReplaceLight Auto Const Mandatory
	; animations
	Idle Property PipBoyLight_Activate Auto Const Mandatory
	; sound
	Sound Property AnimatedPipBoyLightFoley Auto Const Mandatory
EndGroup

Group Internal
	; mod version
	float property fModVersion = 1.00 autoReadOnly
	; timers
	int Property iTimerID_KeyPressDelay = 10 AutoReadOnly
	int Property iTimerID_IdleAnim = 20 AutoReadOnly
	int Property iTimerID_ToggleLight = 30 AutoReadOnly
	; anim parameters
	float Property fAnimLength = 1.65 AutoReadOnly
	float Property fAnimKey_ToggleLight = 0.7 AutoReadOnly
	float Property fPipboyLightDelay = 0.3 AutoReadOnly
EndGroup


; #### FUNCTIONS ####


Function OnGameLoad()

	; Check for requirements
	if F4SE.GetPluginVersion("GardenOfEdenPapyrusScriptExtender") < 369098752
		Var[] args = new Var[1]
		args[0] = "Animated Pip-Boy Light missing requirement.\nInstall latest Garden of Eden Papyrus Extender."
		Utility.CallGlobalFunction("Debug", "MessageBox", args)
		return
	endif

	; Release Version
	if modVersion < 1.00
		Debug.Trace("Animated Pip-Boy Light: Init")
		self.RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
	endif
	modVersion = fModVersion

	RegisterEvents(true)

	; Disable vanilla Pip-Boy light activation
	Var[] args = new Var[2]
	args[0] = "fPipboyLightDelay:Controls"
	args[1] = 99999999.0
	Utility.CallGlobalFunction("Utility", "SetINIFloat", args)

	; Reset input layer if active
	lightStage = 0
	RemoveInputLayer()
	CancelTimer(iTimerID_IdleAnim)

EndFunction

Function RegisterEvents(bool abRegister = true)
	if (abRegister)
		RegisterForControl("Pipboy")
	else
		UnregisterForControl("Pipboy")
	endif
EndFunction

; Handles toggling the Pip-Boy light and playing the idle animation
Function TogglePipBoyLight()

	; Register temporary key event
	controlDown = true
	scanCode = Input.GetMappedKey("Pipboy")
	RegisterForKey(scanCode)

	; Instantly toggle light
	if Game.GetCameraState() != 0 || PlayerRef.IsInPowerArmor() || PlayerRef.GetSitState() != 0 || IsPipBoyLightReplaced()
		lightStage = 3
		GardenOfEden3.TogglePipboyLight()

		; Disable player controls
		inputLayer = InputEnableLayer.Create()
		inputLayer.DisablePlayerControls(abMovement = false, abFighting = false, abCamSwitch = true, abLooking = false, \
			abSneaking = false, abMenu = true, abActivate = false, abJournalTabs = true, abVATS = true, abFavorites = false, abRunning = false)

		return
	endif

	; Play idle animation
	lightStage = 2
	PlayerRef.PlayIdle(PipBoyLight_Activate)
	AnimatedPipBoyLightFoley.Play(PlayerRef)

	; Disable player controls
	inputLayer = InputEnableLayer.Create()
	inputLayer.DisablePlayerControls(abMovement = false, abFighting = true, abCamSwitch = true, abLooking = false, \
		abSneaking = false, abMenu = true, abActivate = true, abJournalTabs = true, abVATS = true, abFavorites = true, abRunning = false)

	StartTimer(fAnimKey_ToggleLight, iTimerID_ToggleLight)
	StartTimer(fAnimLength, iTimerID_IdleAnim)

EndFunction

; Checks if the player is wearing any armor/weapon that replaces the Pip-Boy light
bool Function IsPipBoyLightReplaced()

	int iIndex
	int iSize = AnimatedPipBoyLightFormList_ReplaceLight.GetSize()
	while iIndex < iSize
		Keyword kKeyword = AnimatedPipBoyLightFormList_ReplaceLight.GetAt(iIndex) as Keyword
		if PlayerRef.WornHasKeyword(kKeyword)
			return true
		endif
		iIndex += 1
	endWhile

	return false

EndFunction

Function RemoveInputLayer()
	if (inputLayer != NONE)
		inputLayer.Reset()
		inputLayer.Delete()
		inputLayer = NONE
	endif
EndFunction


; #### EVENTS ####

Event OnQuestInit()
	OnGameLoad()
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
	OnGameLoad()
EndEvent

Event OnQuestShutdown()
	self.UnregisterForAllEvents()
	RegisterEvents(false)
EndEvent

Event OnControlDown(string control)

	; Get equipped Pip-Boy
	Actor:WornItem kPipBoy = PlayerRef.GetWornItem(30, true)

	; Check if player can currently toggle light
	if lightStage > 0 || Utility.IsInMenuMode() || PlayerRef.IsDead() || !kPipBoy.item; || PlayerRef.HasNode("ScreenGlowEffect01") == false ; || PlayerRef.IsInScene() != 0
		return
	endif
	lightStage = 1

	StartTimer(fPipboyLightDelay, iTimerID_KeyPressDelay)

EndEvent

Event OnControlUp(string control, float time)
	CancelTimer(iTimerID_KeyPressDelay)
	if lightStage == 1
		lightStage = 0
	endif
EndEvent

; Resets player controls after idle finishes
Event OnTimer(int aiTimerID)
	if (aiTimerID == iTimerID_KeyPressDelay)
		TogglePipBoyLight()
	elseif (aiTimerID == iTimerID_ToggleLight)
		GardenOfEden3.TogglePipboyLight()
	elseif (aiTimerID == iTimerID_IdleAnim)
		if controlDown == true
			lightStage = 3
		else
			lightStage = 0
			RemoveInputLayer()
			UnregisterForKey(scanCode)
		endif
	endif
EndEvent

Event OnKeyDown(int keyCode)
	controlDown = true
EndEvent

Event OnKeyUp(int keyCode, float time)
	controlDown = false
	if lightStage == 3
		lightStage = 0
		RemoveInputLayer()
		UnregisterForKey(keyCode)
	endif
EndEvent
