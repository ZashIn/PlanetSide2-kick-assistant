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
#NoEnv

#Include <AutoXYWH>
#include <GroupBox>
#include <BinarySearch>

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
searchColumn := 2  ; 0 to disable
addIndexColumn := true  ; Add an index column to the table.
;  Hotkeys: to be changed in the Hotkeys function below, accordingly
scrollHotkeyName = Forward
messageHotkeyName = Back
pasteClipHotkeyName = Ctrl+V
guiStyle = white ; dark/white
fontSize := 0 ; 0 = default, 8-10 ok
alwaysOnTop := true ; Can be toggled via menu
; #####

global ScriptTitle, version
version = 0.4
ScriptTitle = PlanetSide 2 kick assistant v%version%

Init()
return

HotKeys() {
	global targetWindow, scrollHotkeyCode, messageHotkeyCode, hGUI
	
	Hotkey, IfWinActive, ahk_id %hGUI%
	; GUI only
	Hotkey, ^V, PasteClip  ; pasteClipHotkeyName
	Hotkey, ^F, ActivateSearch
	
	GroupAdd, GameAndGui, %targetWindow%
	GroupAdd, GameAndGui, ahk_id %hGUI%
	Hotkey, IfWinActive, ahk_group GameAndGui
	; GUI and game
	Hotkey, XButton2, ScrollToNextInactive  ; scrollHotkeyName
	Hotkey, XButton1, PostIngameMessage  ; messageHotkeyName
	HotKey, Esc, StopScroll
}


Init() {
	global
	listViewHeadersArray := StrSplit(listViewHeaders, "|")
	nInactive := 0
	nKicks := 0
	table := []
	tableOffset := 0
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
	Gui, Add, Text, w%fullWidth% vInfoText, Set PlanetSide to window mode, sort Outfit member list (including offline) by name ascending, click the first name of the list.`nUse the button Delete && Scroll (%scrollHotkeyName%) below to delete the selected row (if marked as inactive) and scroll synchronously here and ingame to the next one.
	resizeControls.w.Push("InfoText")
	
	Gui, Add, Text, vImsgText, Ingame message:
	GuiControlGet, ImsgText, Pos
	local wEdit := fullWidth - ImsgTextW - 5
	Gui, Add, Edit, yp-2 x+5 w%wEdit% r1 vingameMsg, %ingameMsgDefault%
	resizeControls.w.Push("ingameMsg")
	
	;~ GroupBox("SettingsGroup", "Settings", 20, 10, "ImsgText|ingameMsg")
	
	Gui, Add, Text, xm Section, Members inactive / all:
	Gui, Add, Text, ys x+5 w100 Left vCounterText, 0 / 0
	
	; Search
	GuiControlGet, CounterText, Pos
	local searchWidth := fullWidth - CounterTextX - CounterTextW - 50
	Gui, Add, Edit, ys x+5 w%searchWidth% vSearchEdit WantReturn CGray, % "Find name (Ctrl+F)"
	Gui, Add, Button, ys x+5 w50 vSearchButton gSearch, &Find
	; Menu after Paste
	
	; ListView
	Gui, Add, ListView, xm w%fullWidth% r%nListViewRowsVisible% Grid vListView hwndhListView gListViewHandler +AltSubmit, % listViewHeaders . (addIndexColumn ?  "|Index" : "")
	if (addIndexColumn)
		LV_ModifyCol(LV_GetCount("Col"), "Integer")
	resizeControls.wh.Push("ListView")
	
	local buttonWidth := 100 + fontSize
	local rightX := fullWidth - 110
	;~ local textWidth := fullWidth - 2*(ButtonWidth +10)
	
	; Paste
	Gui, Add, Button,  w%buttonWidth% Default vPasteClipButton gPasteClip, &Paste Clipboard (%pasteClipHotkeyName%)
	resizeControls.y.Push("PasteClipButton")
	Menu, ListMenu, Add, &Paste list from clipboard `t %pasteClipHotkeyName%, PasteClip
	;~ Gui, Add, Text, x+m w%textWidth% vPasteClipText, Copy the list with all members (including active) and paste it here.
	; See above
	Menu, ListMenu, Add, &Find Name`tCtrl+F, ActivateSearch
	
	; Jump to next inactive
	Gui, Add, Button, x+m w%buttonWidth% r2 vJumpToNextInactiveButton gJumpToNextInactive, &Jump to next inactive
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
	
	GuiControl, Focus, ScrollToNextInactiveButton
	
	; Menu
	Menu, menuBar, Add, &List, :ListMenu
	Menu, menuBar, Add, &PlanetSide, :PlanetSideMenu
	
	Menu, ViewMenu, Add, &Always On Top, AlwaysOnTopToggle
	alwaysOnTop := !alwaysOnTop 
	AlwaysOnTopToggle()
	
	Menu, menuBar, Add, &View, :ViewMenu
	Gui, Menu, menuBar
	
	
	OnMessage(0x201, "HandleClick")
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

; ListView
ListViewHandler() {
	If (A_GuiEvent = "K" && A_EventInfo = 0x2E) {  ; Delete key
		DeleteSelectedInactive()
	}
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

HandleClick() {
	if (A_GuiControl = "SearchEdit")
		ActivateSearch()
}

ActivateSearch() {
	global searchEditCleared
	GuiControl, Focus, SearchEdit
	GuiControl,+Default, SearchButton
	if (!searchEditCleared) {
		GuiControl, Text, SearchEdit
		searchEditCleared := true
	}
}

Search() {
	global SearchEdit, table, tableOffset, searchColumn
	static binSearch
	Gui, Submit, NoHide
	; Search case insensitive
	if (!binSearch || table != binSearch.sortedArray || binSearch.pattern != SearchEdit) {
		binSearch := BinarySearch(table, SearchEdit, searchColumn, tableOffset, true)
	}
	; Get next or first item if no more found (circular).
	if (!binSearch.Next(i) && !((binSearch := binSearch._NewEnum()).Next(i))) {
		MsgBox, 0x40010, Search, %SearchEdit% not found!
		return
	}
	LV_Modify(0, "-Select")
	LV_Modify(i - tableOffset, "Focus Select Vis")
}

StopScroll() {
	global stopScroll
	stopScroll := true
}

; Scroll to next inactive member, in gui and game synchronously
ScrollToNextInactive() {
	global targetWindow, nListViewRowsVisible, fastScrollDelay, scrollDelay, hListView, fromTop, nInactive, stopScroll
	stopScroll := false
	
	if (!WinExist(targetWindow))
		return
	
	i := LV_GetNext()
	if (DeleteSelectedInactive()) {
		i := LV_GetNext()
	}
	
	next := FindNextInactive()
	if (next < 1) {
		MsgBox, 0x40010, Scroller, no more inactive members!
		return
	}
	
	WinActivate, % targetWindow
	; Find minimal distance from top / bottom or current position
	len := LV_GetCount()
	d := Abs(i - next)
	if (next - 1 < d) {
		; from start
		Sleep, % fastScrollDelay
		Send {Home}
		;~ ControlSend,, {Home}, ahk_id %hListView%
		LV_Modify(0, "-Select")
		LV_Modify(1, "Focus Select Vis")
	} else if (len - next < d) {
		; from end
		Sleep, % fastScrollDelay
		Send {End}
		;~ ControlSend,, {End}, ahk_id %hListView%
		LV_Modify(0, "-Select")
		LV_Modify(len, "Focus Select Vis")
	}
	i := LV_GetNext()
	if (i - next > 0) {
		; Move up
		aKey = Up
		pKey = PgUp
		step := -1
	} else {
		; Move down
		aKey = Down
		pKey = PgDn
		step := 1
	}
	
	while (i != next) {
		If(stopScroll || !WinActive(targetWindow))
			break
		
		; Move one line up
		; Source: https://www.autohotkey.com/boards/viewtopic.php?f=7&t=678
		;sendmessage, 0x115, 0, 0,, ahk_id %hListView%
		
		if (Abs(i - next) > nListViewRowsVisible + 1) {
			; move one page up
			Sleep, % fastScrollDelay
			Send, {%pKey%}  ; goes one page up (no overlap)
			;~ ControlSend,, {%pKey%}{%aKey%}, ahk_id %hListView%  ; goes one page up (with 1 overlap) + 1 up
			LV_Modify(0, "-Select")
			LV_Modify(i + step*nListViewRowsVisible, "Focus Select Vis")
		} else {
			; move one line up
			Sleep, % scrollDelay
			Send, {%aKey%}
			;~ ControlSend,, {%aKey%}, ahk_id %hListView%
			LV_Modify(0, "-Select")
			LV_Modify(i + step, "Focus Select Vis")
		}
		i := LV_GetNext()
	}
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
	global listViewHeaders, addIndexColumn
	table := ParseListFromClipBoard()
	if (table.Length() = 0) {
		MsgBox, 0x40010, Clipboard parsing, Could not parse the clipboard!
		return
	}
	; Check for header
	withHeader := false
	Loop, Parse, listViewHeaders, "|"
		if !(withHeader := table[1, A_Index] = A_LoopField)
			break
	FillListView(table, withHeader, addIndexColumn)
	UpdateGuiCounter()
	ShowGui()
}

; Parse clipboard, lines into array, replacing tabs with "|"
ParseListFromClipBoard() {
	clip := Clipboard
	replaced := RegExReplace(clip, " *\t *", "|", repCount)
	if (repCount < 1)
		return []
	list := []
	i := 0
	Loop, Parse, replaced, `n, `r
	{
		trimmed := Trim(A_LoopField)
		if (trimmed == "")
			continue
		list.Push(StrSplit(trimmed, "|" ))
		i++
	}
	return list
}

; Fill the ListView by the given 2d Array
; withHeader: the given array includes the headline => sets tableOffset := 1
; addRowIndex: adds a row index as last column
FillListView(arr, withHeader := false, addRowIndex := true) {
	global table, tableOffset, nListViewRowsVisible, inactiveColumn, inactiveMark, nInactive
	GuiControl, -Redraw, ListView
	LV_Delete()
	
	enum := arr.NewEnum()
	table := []
	tableOffset := 0
	
	; Skip header
	if (withHeader) {
		enum.Next(, head)
		if (addRowIndex)
			head.Push("Index")
		; Delete all columns
		nCols := LV_GetCount("Col")
		while (nCols > 0)
			LV_DeleteCol(nCols--)
		; Insert columns (names)
		for c, h in head
			LV_InsertCol(c,, h)
		if (addRowIndex)
			LV_ModifyCol(LV_GetCount("Col"), "Integer")
		table.Push(head)
		tableOffset := 1
	}
	inactiveIndices := []
	nInactive := 0
	
	While enum[i, row]
	{
		if (addRowIndex)
			row.Push(i - tableOffset)  ; Add row index.
		LV_Add("", row*)
		table.Push(row)
		; Count inactive
		if (row[inactiveColumn] = inactiveMark)
			nInactive++
	}
	
	LV_Modify(0, "-Select")
	rows := LV_GetCount()
	;~ LV_Modify(rows - nListViewRowsVisible + 1, "Focus Select")
	;~ LV_Modify(rows, "Vis") ; Jump to last row
	LV_Modify(1, "Vis Focus Select") ; Jump to first row
	GuiControl, +Redraw, ListView
}

; Update counters in GUI
UpdateGuiCounter() {
	global nInactive, nKicks
	GuiControl,, CounterText, % nInactive " / " LV_GetCount()
}

; Returns the index of the next inactive member row (or 0)
; Starts from the current selected row or optional at the given index.
FindNextInactive(i := 0) {
	global inactiveColumn, inactiveMark, nInactive
	if (!nInactive)
		return 0
	i := i > 0 ? i : LV_GetNext()
	while (--i > 1) {
		LV_GetText(text, i, inactiveColumn)
		if (text = inactiveMark)
			return i
	}
	return FindNextInactive(LV_GetCount())
}

; Delete the selected row, if marked as inactive member
DeleteSelectedInactive() {
	global inactiveColumn, inactiveMark, nInactive, table, tableOffset
	i := LV_GetNext()
	LV_GetText(text, i, inactiveColumn)
	if (text = inactiveMark) {
		table.RemoveAt(tableOffset + i)
		LV_Delete(i)
		nInactive--
		;~ nKicks++
		UpdateGuiCounter()
		LV_Modify(i, "Focus Select Vis")
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
