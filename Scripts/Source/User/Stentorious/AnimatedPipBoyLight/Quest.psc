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
	; animations
	Idle Property PipBoyLight_Activate Auto Const Mandatory
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

	; Release Version
	if modVersion < 1.00
		Debug.Trace("Animated Pip-Boy Light: Init")
		self.RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
	endif
	modVersion = fModVersion

	RegisterEvents(true)

	; Disable vanilla Pip-Boy light activation
	GardenOfEden2.ExecuteConsoleCommand("SetINI \"fPipboyLightDelay:Controls\" 99999999")

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
	if Game.GetCameraState() != 0 || PlayerRef.IsInPowerArmor() || PlayerRef.GetSitState() != 0
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

	; Disable player controls
	inputLayer = InputEnableLayer.Create()
	inputLayer.DisablePlayerControls(abMovement = false, abFighting = true, abCamSwitch = true, abLooking = false, \
		abSneaking = false, abMenu = true, abActivate = true, abJournalTabs = true, abVATS = true, abFavorites = true, abRunning = false)

	StartTimer(fAnimKey_ToggleLight, iTimerID_ToggleLight)
	StartTimer(fAnimLength, iTimerID_IdleAnim)

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

	if Utility.IsInMenuMode()
		return
	endif

	if lightStage > 0 || PlayerRef.IsDead() || PlayerRef.IsInScene() != 0
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
