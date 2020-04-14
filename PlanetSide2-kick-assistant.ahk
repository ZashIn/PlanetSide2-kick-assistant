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
scrollHotkeyName = Mouse-Forward
messageHotkeyName = Mouse-Back
pasteClipHotkeyName = Ctrl+V
guiStyle = white ; dark/white
fontSize := 10
; #####

global ScriptTitle, version
version = 0.1
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
	Gui +Resize +hwndhGUI +MinSize410x320
	Gui, Font, S%fontSize%
	if (guiStyle = "dark") {
		Gui, Font, cFFFFFF
		Gui, Color, 333333, 333333
	}
	local w := 800
	Gui, Add, Text, w%w% vInfoText, Set PlanetSide to window mode, sort Outfit member list (including offline) by name ascending, go to bottom of the list, click the uppermost entry.
	
	Gui, Add, Text, Section vImsgText, Ingame message:
	GuiControlGet, ImsgText, Pos
	local wEdit := w - ImsgTextW - 5
	Gui, Add, Edit, ys-2 x+5 w%wEdit% r1 vingameMsg, %ingameMsgDefault%
	
	Gui, Add, Text, xm Section, Members inactive / all:
	Gui, Add, Text, ys x+5 w100 Left vCounterText, 0 / 0
	
	Gui, Add, ListView, xm w%w% r%nListViewRowsVisible% Grid vListView hwndhListView, %listViewHeaders%|Index
	
	Gui, Add, Button, w120 vPasteClipButton gPasteClip, &Paste Clipboard (Ctrl+V)
	
	Gui, Add, Button, wp vJumpToNextInactiveButton gJumpToNextInactive, &Jump (fast)
	
	;~ Gui, Add, GroupBox, xm
	Gui, Add, Button, xm wp Default Section vScrollToNextInactiveButton gScrollToNextInactive, Delete && &Scroll (%scrollHotkeyName%)
	Gui, Add, Button, ys wp vIngameMessageButton gPostIngameMessage, &Ingame Message (%messageHotkeyName%)
	
	local rightX := w - 110
	Gui, Add, Button, ys x%rightX% wp vCancelButton gGuiClose wp, &Cancel
	
	LV_ModifyCol(LV_GetCount("Col"), "Integer")
	GuiControl, Focus, ScrollToNextInactiveButton
	guiCreated := true
	
	; For GuiSize - excluding listview
	fullWidthControls := ["InfoText", "IngameMsg"]
	bottomButtons := ["PasteClipButton", "JumpToNextInactiveButton", "ScrollToNextInactiveButton", "IngameMessageButton"]
}

; Expand or shrink the ListView in response to the user's resizing of the window.
GuiSize() {
	global
	if A_EventInfo = 1  ; The window has been minimized.  No action needed.
		return
	
	AutoXYWH("wh", "ListView")
	AutoXYWH("w*", fullWidthControls*)
	AutoXYWH("y", bottomButtons*)
	AutoXYWH("xy", "CancelButton")
}

ShowGui() {
	; Autosize all columns including header
	Loop % LV_GetCount()
		  LV_ModifyCol(A_Index, "AutoHdr")
	;~ LV_ModifyCol(2, "Sort")
	Gui, +AlwaysOnTop
	Gui, Show, AutoSize, %ScriptTitle%
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
	MsgBox, 0x40010,, %ingameMsg%
	return
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
