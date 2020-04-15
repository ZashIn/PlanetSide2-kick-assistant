/*!
	PlanetSide 2 kick assistant
	
	Scroll through the Outfit member list in PlanetSide 2, to find and kick inactive members.
	
	- Parse a list / table of Outfit members, with the inactive ones marked in a column
	- Synchronous scrolling through GUI- and ingame-list (using PgUp & Up) to find row
	- Option to post ingagme message to notify about the cleanup process
	
	Author: Zash
	License: LGPL v3
*/
#SingleInstance force

#Include <AutoXYWH>
#include <GroupBox>

; # Settings
targetWindow = ahk_exe PlanetSide2_x64.exe
nListViewRowsVisible := 17 ; Set to same as in PlanetSide
ingameMsgDefault = /o Outfit Cleanup in progress: kicking long inactive members
scrollDelay := 50  ; Delay when scrolling one line at a time
fastScrollDelay := 150  ; Delay when scrolling multiple lines / one page
iChatDelay := 100  ; Delay for chat messages
listViewHeaders := "Inactive?|Character Name|Last Login|Battle Rank (Prestige Level)|Trident Site Account?"
inactiveColumn := 1
inactiveMark := "x"  ; In the first column ("Inactive?")
;  Hotkeys: to be changed in the Hotkeys function below, accordingly
scrollHotkeyName = Forward
messageHotkeyName = Back
pasteClipHotkeyName = Ctrl+V
guiStyle = white ; dark/white
fontSize := 0 ; 0 = default, 8-10 ok
alwaysOnTop := true ; Can be toggled via menu
; #####

global ScriptTitle, version
version = 0.2
ScriptTitle = PlanetSide 2 kick assistant v%version%

Init()
return

HotKeys() {
	global targetWindow, scrollHotkeyCode, messageHotkeyCode, hGUI
	
	Hotkey, IfWinActive, ahk_id %hGUI%
	; GUI only
	Hotkey, ^V, PasteClip  ; pasteClipHotkeyName
	
	GroupAdd, GameAndGui, %targetWindow%
	GroupAdd, GameAndGui, ahk_id %hGUI%
	Hotkey, IfWinActive, ahk_group GameAndGui
	; GUI and game
	Hotkey, XButton2, ScrollToNextInactive  ; scrollHotkeyName
	Hotkey, XButton1, PostIngameMessage  ; messageHotkeyName
}


Init() {
	global
	nInactive := 0
	nKicks := 0
	guiCreated := false
	CreateGUI()
	HotKeys()
	ShowGui()
}


; # GUI

CreateGUI() {
	global
	if guiCreated
		return
	Gui +Resize +hwndhGUI +MinSize420x320
	if (fontSize)
		Gui, Font, S%fontSize%
	if (guiStyle = "dark") {
		Gui, Font, cFFFFFF
		Gui, Color, 333333, 333333
	}
	
	; For GuiSize (resizing)
	resizeControls := {w: [], wh: [], y: [], xy: []}
	
	local fullWidth := 650
	Gui, Add, Text, w%fullWidth% vInfoText, Set PlanetSide to window mode, sort Outfit member list (including offline) by name ascending, go to bottom of the list, click the uppermost entry.`nUse the button Delete && Scroll (%scrollHotkeyName%) below to delete the selected row (if marked as inactive) and scroll synchronously here and ingame to the next one.
	
	Gui, Add, Text, vImsgText, Ingame message:
	GuiControlGet, ImsgText, Pos
	local wEdit := fullWidth - ImsgTextW - 25
	Gui, Add, Edit, yp-2 x+5 w%wEdit% r1 vingameMsg, %ingameMsgDefault%
	
	;~ GroupBox("SettingsGroup", "Settings", 20, 10, "ImsgText|ingameMsg")
	
	Gui, Add, Text, xm Section, Members inactive / all:
	Gui, Add, Text, ys x+5 w100 Left vCounterText, 0 / 0
	
	; ListView
	Gui, Add, ListView, xm w%fullWidth% r%nListViewRowsVisible% Grid vListView hwndhListView, %listViewHeaders%|Index
	resizeControls.wh.Push("ListView")
	
	local buttonWidth := 100 + fontSize
	local rightX := fullWidth - 110
	;~ local textWidth := fullWidth - 2*(ButtonWidth +10)
	
	; Paste
	Gui, Add, Button,  w%buttonWidth% Default vPasteClipButton gPasteClip, &Paste Clipboard (%pasteClipHotkeyName%)
	resizeControls.y.Push("PasteClipButton")
	Menu, ListMenu, Add, Paste list from clipboard `t %pasteClipHotkeyName%, PasteClip
	;~ Gui, Add, Text, x+m w%textWidth% vPasteClipText, Copy the list with all members (including active) and paste it here.
	
	; Jump
	Gui, Add, Button, x+m w%buttonWidth% vJumpToNextInactiveButton gJumpToNextInactive, &Jump to next
	resizeControls.y.Push("JumpToNextInactiveButton")
	Menu, ListMenu, Add, &Jump to next inactive, JumpToNextInactive
	;~ Gui, Add, Text, x+m w%textWidth% vJumpToNextInactiveText, Jump to next inactive member in the list (only here)
	
	; Delte & scroll
	Gui, Add, Button, xm w%buttonWidth% vScrollToNextInactiveButton gScrollToNextInactive, &Delete && Scroll (%scrollHotkeyName%)
	resizeControls.y.Push("ScrollToNextInactiveButton")
	Menu, PlanetSideMenu, Add, &Delete sel. inactive && scroll to next`t%scrollHotkeyName%, ScrollToNextInactive
	;~ Gui, Add, Text, x+m w%textWidth% vScrollToNextInactiveText, Deletes the selected row (if inactive) and scrolls synchronized with ingame list to the next one.
	
	;  Ingame message
	Gui, Add, Button, x+m Section w%ButtonWidth% vIngameMessageButton gPostIngameMessage, &Ingame Message (%messageHotkeyName%)
	resizeControls.y.Push("IngameMessageButton")
	Menu, PlanetSideMenu, Add, Post &Ingame Message`t%messageHotkeyName%, PostIngameMessage
	
	GroupBox("PS2GroupBox", "Planetside 2", 20, 10, "ScrollToNextInactiveButton|IngameMessageButton")
	resizeControls.y.Push("PS2GroupBox")
	
	; Cancel
	GuiControlGet, ScrollToNextInactiveButton, Pos
	local rightY := ScrollToNextInactiveButtonY + ScrollToNextInactiveButtonH - 29
	Gui, Add, Button, x%rightX% y%rightY% w%buttonWidth% vCancelButton gGuiClose, &Cancel
	resizeControls.xy.Push("CancelButton")
	
	LV_ModifyCol(LV_GetCount("Col"), "Integer")
	GuiControl, Focus, ScrollToNextInactiveButton
	
	; Menu
	Menu, menuBar, Add, &List, :ListMenu
	Menu, menuBar, Add, &PlanetSide, :PlanetSideMenu
	
	Menu, ViewMenu, Add, &Always On Top, AlwaysOnTopToggle
	alwaysOnTop := !alwaysOnTop 
	AlwaysOnTopToggle()
	
	Menu, menuBar, Add, &View, :ViewMenu
	Gui, Menu, menuBar
	
	guiCreated := true
}

; Expand or shrink the ListView in response to the user's resizing of the window.
GuiSize() {
	global resizeControls
	if A_EventInfo = 1  ; The window has been minimized.  No action needed.
		return
	
	AutoXYWH("w*", resizeControls.w*)
	AutoXYWH("wh", resizeControls.wh*)
	AutoXYWH("y*", resizeControls.y*)
	AutoXYWH("xy", resizeControls.xy*)
}

ShowGui() {
	; Autosize all columns including header
	Loop % LV_GetCount()
		  LV_ModifyCol(A_Index, "AutoHdr")
	;~ LV_ModifyCol(2, "Sort")
	Gui, Show, AutoSize, %ScriptTitle%
}

AlwaysOnTopToggle() {
	global alwaysOnTop
	if (alwaysOnTop) {
		Menu, ViewMenu, UnCheck, &Always On Top
		Gui, -AlwaysOnTop
		alwaysOnTop := false
	} else {
		Menu, ViewMenu, Check, &Always On Top
		Gui, +AlwaysOnTop
		alwaysOnTop := true
	}
	Gui, Show
}

; # Buttons

GuiClose() {
	Gui, Cancel
	ExitApp
}

PasteClip() {
	UpdateListViewFromClip()
}

; Jump to next inactive member, in gui only
JumpToNextInactive() {
	Gui, Submit, NoHide
	i := FindNextInactive()
	if (i > 0) {
		LV_Modify(0, "-Select")
		LV_Modify(i, "Focus Select Vis")
	}
}

; Scroll to next inactive member, in gui and game synchronously
ScrollToNextInactive() {
	global targetWindow, nListViewRowsVisible, fastScrollDelay, scrollDelay, hListView
	i := LV_GetNext()
	if (i < 2 || !WinExist(targetWindow))
		return
	
	if (DeleteSelectedInactive())
		LV_Modify(i, "Focus Select Vis")
	
	next := FindNextInactive()
	if (next < 1)
		return
	
	WinActivate, % targetWindow
	while (i > next) {
		IfWinNotActive, % targetWindow
			break
		
		; Move one line up
		; Source: https://www.autohotkey.com/boards/viewtopic.php?f=7&t=678
		;sendmessage, 0x115, 0, 0,, ahk_id %hListView%
		
		if (i - next >= nListViewRowsVisible) {
			; move one page up
			Sleep, % fastScrollDelay
			Send, {PgUp}  ; goes one page up (no overlap)
			ControlSend,, {PgUp}{Up}, ahk_id %hListView%  ; goes one page up (with 1 overlap) + 1 up
			i := LV_GetNext()
		} else {
			; move one line up
			Sleep, % scrollDelay
			Send, {Up}
			ControlSend,, {Up}, ahk_id %hListView%
			i--
		}
	}
	UpdateGuiCounter()
}

; Post the message in the ingame chat
PostIngameMessage() {
	global ingameMsg, targetWindow
	Gui, Submit, NoHide
	WinActivate, % targetWindow
	PlanetSideChatMessage(ingameMsg)
}


; # Functions

; Fill the ListView from clipboard
UpdateListViewFromClip() {
	global listViewHeaders
	list := ParseListFromClipBoard()
	if (list.Length() = 0) {
		MsgBox, 0x40010, Clipboard parsing, Could not parse the clipboard!
		return
	}
	firstLine := list[1]
	withHeaders := (Trim(firstLine) = listViewHeaders)
	FillListView(list, withHeaders)
	UpdateGuiCounter()
	ShowGui()
}

; Parse clipboard, lines into array, replacing tabs with "|"
ParseListFromClipBoard() {
	clip := Clipboard
	replaced := RegExReplace(clip, " *\t", "|", repCount)
	list := []
	if (repCount < 1)
		return list
	Loop, Parse, replaced, `n, `r
	{
		if (Trim(A_LoopField) == "")
			continue
		list.Push(A_LoopField)  ; StrSplit(A_LoopField, "|" )
	}
	return list
}

; Fill the ListView by the given Array, whith strings (rows, with columns separated by "|")
FillListView(list, withHeader := false) {
	global nListViewRowsVisible, inactiveColumn, inactiveMark, nInactive
		GuiControl, -Redraw, ListView
		LV_Delete()
	
	enum := list.NewEnum()
	offset := 0
	; Skip header
	if (withHeader) {
		enum.Next()
		offset := 1
	}
	inactiveIndices := []
	nInactive := 0
	
		While enum[i, row]
	{
		row := StrSplit(row, "|" )
		row.Push(i - offset)
		LV_Add("", row*)
		; Count inactive
		if (row[inactiveColumn] = inactiveMark)
			nInactive++
	}
	
	GuiControl, +Redraw, ListView
	LV_Modify(0, "-Select")
	rows := LV_GetCount()
	LV_Modify(rows - nListViewRowsVisible + 1, "Focus Select")
	LV_Modify(rows, "Vis") ; Jump to last row
}

; Update counters in GUI
UpdateGuiCounter() {
	global nInactive, nKicks
	GuiControl,, CounterText, % nInactive " / " LV_GetCount()
}

; Returns the index of the next inactive member row (or 0)
; Starts from the current selected row or optional at the given index.
FindNextInactive(i := 0) {
	global inactiveColumn, inactiveMark
	i := i > 0 ? i : LV_GetNext()
	while (--i > 1) {
		LV_GetText(text, i, inactiveColumn)
		if (text = inactiveMark)
			return i
	}
	return 0
}

; Delete the selected row, if marked as inactive member
DeleteSelectedInactive() {
	global inactiveColumn, inactiveMark, nInactive
	i := LV_GetNext()
	LV_GetText(text, i, inactiveColumn)
	if (text = inactiveMark) {
		LV_Delete(i)
		nInactive--
		nKicks++
		UpdateGuiCounter()
		return i
	}
	return 0
}

; Opens chat and posts message
PlanetSideChatMessage(msg) {
	global iChatDelay
	Sleep, %iChatDelay%
	Send, {ENTER}  ; Open console
	Sleep, %iChatDelay%
	Send, +{Home}  ; Clear chat
	Sleep, %iChatDelay%
	Send, %msg%{ENTER} ; Send command / chat text
}
