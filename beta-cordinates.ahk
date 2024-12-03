#Requires AutoHotkey v2.0

; Global variables
global isRunning := false
global defaultInterval := 5000  ; 5000 ms = 5 seconds
global defaultCommand := "cx"  ; Default command without "/"
global defaultEatInterval := 300000  ; 300000 ms = 5 minutes
global defaultInventoryInterval := 60000  ; 60000 ms = 1 minute
global defaultAnvilInterval := 10000  ; 10000 ms = 10 seconds
global defaultAnvilChecked := true  ; Default checkbox state
global intervalEdit := ""
global commandEdit := ""
global eatIntervalEdit := ""
global inventoryIntervalEdit := ""
global anvilRepairCheckbox := ""
global anvilIntervalEdit := ""
global statusText := ""
global MyGui := ""
global windowList := ""
global selectedWindow := ""
global invPositions := []
global loggedPositions := []  ; Tablica do przechowywania pozycji
global positionsListBox := "" ; Do wyświetlania pozycji w GUI

; Initialize inventory positions (calculated for 1280x720 resolution)
InitializeInventoryPositions() {
    startX := 523  ; Starting X coordinate for first slot
    startY := 365  ; Starting Y coordinate for first row
    slotWidth := 36   ; Width between slots
    slotHeight := 36  ; Height between rows
    
    for row in [0, 1, 2] {
        y := startY + (row * slotHeight)
        for col in [0, 1, 2, 3, 4, 5, 6, 7, 8] {
            x := startX + (col * slotWidth)
            invPositions.Push({x: x, y: y})
        }
    }
}

; Initialize positions on startup
InitializeInventoryPositions()

; Show GUI immediately on script start
ShowGui()

; Assign + key to start script
NumpadAdd::
{
    Start()
}

; Assign - key to stop script
NumpadSub::
{
    Stop()
}

; Function to find Minecraft/BlazingPack windows
FindMinecraftWindows() {
    windows := []
    windowTitles := []
    DetectHiddenWindows(true)
    
    windows := WinGetList("ahk_exe javaw.exe")
    windows2 := WinGetList("BlazingPack")
    
    for window in windows2
        windows.Push(window)
    
    if !windows.Length {
        windowTitles.Push("No Minecraft/BlazingPack windows found - Start game first")
        return windowTitles
    }
    
    for window in windows {
        title := WinGetTitle(window)
        procName := WinGetProcessName(window)
        
        if (InStr(title, "Minecraft") || InStr(title, "BlazingPack") 
            || InStr(procName, "java") || InStr(procName, "BlazingPack")) {
            windowTitles.Push(title)
        }
    }
    
    if !windowTitles.Length
        windowTitles.Push("No Minecraft/BlazingPack windows found - Start game first")
    return windowTitles
}

ShowGui() {
    global intervalEdit, commandEdit, eatIntervalEdit, inventoryIntervalEdit, anvilRepairCheckbox, anvilIntervalEdit, statusText, MyGui, windowList, positionsListBox
    MyGui := Gui()
    MyGui.SetFont("s10")
    
    ; Make GUI bigger and add padding
    MyGui.MarginX := 20
    MyGui.MarginY := 20
    
    ; Add title
    MyGui.Add("Text", "w1000 Center", "Minecraft/BlazingPack Auto Clicker")
    MyGui.Add("Text", "w1000 h2 0x10")
    
    ; Left Column - Settings
    MyGui.Add("Text", "xm y+20 Section", "Select game window:")
    windowList := MyGui.Add("DropDownList", "xs y+5 w450 vSelectedWindow", FindMinecraftWindows())
    MyGui.Add("Button", "x+5 w40", "↻").OnEvent("Click", RefreshWindowList)
    
    ; Command settings section
    MyGui.Add("GroupBox", "xs y+20 w480 h85", "Command Settings")
    MyGui.Add("Text", "xm+10 yp+20", "Command interval (milliseconds):")
    intervalEdit := MyGui.Add("Edit", "w150 vIntervalEdit", defaultInterval)
    timeText1 := MyGui.Add("Text", "x+10", "= " . Round(defaultInterval/1000, 1) . " seconds")
    intervalEdit.OnEvent("Change", (*) => timeText1.Value := "= " . Round(Integer(intervalEdit.Value)/1000, 1) . " seconds")
    MyGui.Add("Text", "xm+10 y+10", "Command to send:")
    commandEdit := MyGui.Add("Edit", "w150", defaultCommand)
    
    ; Eating settings section
    MyGui.Add("GroupBox", "xs y+20 w480 h60", "Auto-Eat Settings")
    MyGui.Add("Text", "xm+10 yp+20", "Auto-eat interval (milliseconds):")
    eatIntervalEdit := MyGui.Add("Edit", "w150 vEatIntervalEdit", defaultEatInterval)
    timeText2 := MyGui.Add("Text", "x+10", "= " . Round(defaultEatInterval/60000, 1) . " minutes")
    eatIntervalEdit.OnEvent("Change", (*) => timeText2.Value := "= " . Round(Integer(eatIntervalEdit.Value)/60000, 1) . " minutes")
    
    ; Inventory check settings
    MyGui.Add("GroupBox", "xs y+20 w480 h60", "Inventory Check Settings")
    MyGui.Add("Text", "xm+10 yp+20", "Inventory check interval (milliseconds):")
    inventoryIntervalEdit := MyGui.Add("Edit", "w150 vInventoryIntervalEdit", defaultInventoryInterval)
    timeText3 := MyGui.Add("Text", "x+10", "= " . Round(defaultInventoryInterval/60000, 1) . " minutes")
    inventoryIntervalEdit.OnEvent("Change", (*) => timeText3.Value := "= " . Round(Integer(inventoryIntervalEdit.Value)/60000, 1) . " minutes")
    
    ; Anvil repair section
    MyGui.Add("GroupBox", "xs y+20 w480 h85", "Anvil Repair Settings")
    anvilRepairCheckbox := MyGui.Add("Checkbox", "xm+10 yp+20 Checked", "Enable anvil repair (automatically repairs pickaxe)")
    MyGui.Add("Text", "xm+10 y+10", "Anvil repair interval (milliseconds):")
    anvilIntervalEdit := MyGui.Add("Edit", "w150 vAnvilIntervalEdit", defaultAnvilInterval)
    timeText4 := MyGui.Add("Text", "x+10", "= " . Round(defaultAnvilInterval/60000, 1) . " minutes")
    anvilIntervalEdit.OnEvent("Change", (*) => timeText4.Value := "= " . Round(Integer(anvilIntervalEdit.Value)/60000, 1) . " minutes")
    
    ; Status at bottom of left column
    MyGui.Add("Text", "xs y+20 w480 h2 0x10")
    statusText := MyGui.Add("Text", "xs y+10 w480 Center", "Status: Waiting to start...")
    
    ; Right Column - Logged Positions
    MyGui.Add("GroupBox", "x+40 ys w480 h680", "Logged Mouse Positions (F8 to log)")
    
    ; Add button to clear positions
    MyGui.Add("Button", "xp+10 yp+25 w100", "Clear List").OnEvent("Click", ClearPositions)
    
    ; Add ListBox for positions
    positionsListBox := MyGui.Add("ListBox", "xp y+10 w460 h620", loggedPositions)
    
    ; Make GUI stay on top
    MyGui.Opt("+AlwaysOnTop")
    
    ; Show GUI window
    MyGui.Show("w1050 h800")
}

RefreshWindowList(*) {
    global windowList
    windowList.Delete()
    windowList.Add(FindMinecraftWindows())
}

; Function to check if pixel is black
IsBlackPixel(x, y) {
    color := PixelGetColor(x, y)
    r := (color & 0xFF0000) >> 16
    g := (color & 0x00FF00) >> 8
    b := color & 0x0000FF
    return (r < 30 && g < 30 && b < 30)
}

; Function to check inventory and drop black items
CheckInventory() {
    global isRunning, selectedWindow, invPositions
    if !isRunning
        return
        
    if WinExist(selectedWindow) {
        ; Stop mining
        SendInput("{LButton up}")
        Sleep(200)
        
        ; Open inventory
        SendInput("e")
        Sleep(500)
        
        ; Check each slot
        for pos in invPositions {
            if (IsBlackPixel(pos.x, pos.y)) {
                MouseMove(pos.x, pos.y)
                Sleep(50)
                SendInput("{LShift down}")
                Sleep(50)
                SendInput("q")
                Sleep(50)
                SendInput("{LShift up}")
                Sleep(50)
            }
        }
        
        ; Close inventory
        SendInput("e")
        Sleep(200)
        
        ; Resume mining if still running
        if (isRunning)
            SendInput("{LButton down}")
    }
}

; Function to repair pickaxe in anvil
RepairPickaxe() {
    global isRunning, selectedWindow, anvilRepairCheckbox
    if !isRunning || !anvilRepairCheckbox.Value
        return
        
    if WinExist(selectedWindow) {
        ; Stop mining
        SendInput("{LButton up}")
        Sleep(200)
        
        ; Move left to anvil
        SendInput("{a down}")
        Sleep(1000)
        SendInput("{a up}")
        Sleep(200)
        
        ; Right click anvil
        SendInput("{RButton}")
        Sleep(500)
        
        ; Place pickaxe
        SendInput("1")  ; Select pickaxe slot
        Sleep(200)
        MouseMove(523, 365)  ; First slot coordinates
        Sleep(200)
        SendInput("{LButton}")  ; Place pickaxe
        Sleep(200)
        
        ; Place diamonds
        SendInput("3")  ; Select diamond slot
        Sleep(200)
        MouseMove(595, 365)  ; Second slot coordinates
        Sleep(200)
        SendInput("{LButton}")  ; Place diamonds
        Sleep(200)
        
        ; Get repaired pickaxe
        MouseMove(667, 365)  ; Result slot coordinates
        Sleep(200)
        SendInput("{LButton}")  ; Take repaired pickaxe
        Sleep(200)
        
        ; Put pickaxe back to slot 1
        SendInput("1")
        Sleep(200)
        SendInput("{LButton}")
        Sleep(200)
        
        ; Put diamonds back to slot 3
        SendInput("3")
        Sleep(200)
        SendInput("{LButton}")
        Sleep(200)
        
        ; Close anvil
        SendInput("e")
        Sleep(200)
        
        ; Move right back to mining position
        SendInput("{d down}")
        Sleep(1000)
        SendInput("{d up}")
        Sleep(200)
        
        ; Resume mining if still running
        if (isRunning)
            SendInput("{LButton down}")
    }
}

; Function to eat food
Eat() {
    global isRunning, selectedWindow
    if !isRunning
        return
        
    if WinExist(selectedWindow) {
        SendInput("{LButton up}")
        Sleep(100)
        
        SendInput("2")
        Sleep(200)
        
        SendInput("{RButton down}")
        Sleep(5000)
        SendInput("{RButton up}")
        
        SendInput("1")
        Sleep(200)
        
        if (isRunning)
            SendInput("{LButton down}")
    }
}

; Function to send command
SendCommand() {
    global isRunning, commandEdit, selectedWindow
    if !isRunning
        return
        
    if WinExist(selectedWindow) {
        SendInput("{LButton up}")
        Sleep(100)
        
        WinActivate(selectedWindow)
        Sleep(200)
        
        SendInput("{T}")
        Sleep(200)
        
        SendInput("/" . commandEdit.Value)
        Sleep(200)
        
        SendInput("{Enter}")
        Sleep(200)
        
        if (isRunning)
            SendInput("{LButton down}")
    }
}

; Function to simulate digging
Click(action) {
    if action = "Down" {
        SendInput("{LButton down}")
    }
    else if action = "Up" {
        SendInput("{LButton up}")
        SendInput("{RButton up}")
        SendInput("{LShift up}")
    }
}

; Start function
Start(*) {
    global isRunning, intervalEdit, eatIntervalEdit, inventoryIntervalEdit, anvilIntervalEdit, statusText, windowList, commandEdit, selectedWindow, anvilRepairCheckbox
    if isRunning
        return
        
    selectedWindow := windowList.Text
    if (selectedWindow = "No Minecraft/BlazingPack windows found - Start game first") {
        MsgBox("Please start the game and refresh the window list!")
        return
    }
    
    interval := Integer(intervalEdit.Value)
    if (interval < 1000)
        interval := 1000
        
    eatInterval := Integer(eatIntervalEdit.Value)
    if (eatInterval < 10000)
        eatInterval := 10000
        
    inventoryInterval := Integer(inventoryIntervalEdit.Value)
    if (inventoryInterval < 10000)
        inventoryInterval := 10000
        
    isRunning := true
    
    Click("Down")
    
    SetTimer(SendCommand, interval)
    SetTimer(Eat, eatInterval)
    SetTimer(CheckInventory, inventoryInterval)
    
    statusText.Text := "Status: RUNNING - Press - to stop"
    TrayTip("Auto Clicker", "Script started! Command: " commandEdit.Value " every " interval/1000 " seconds", "Iconi")
}

; Stop function
Stop(*) {
    global isRunning, statusText
    if !isRunning
        return
        
    isRunning := false
    
    Click("Up")
    
    SetTimer(SendCommand, 0)
    SetTimer(Eat, 0)
    SetTimer(CheckInventory, 0)
    
    statusText.Text := "Status: STOPPED - Press + to start"
    TrayTip("Auto Clicker", "Script has been stopped!", "Iconi")
}

; Function to clear positions
ClearPositions(*) {
    global loggedPositions, positionsListBox
    loggedPositions := []
    positionsListBox.Delete()
}

; Function to log mouse position
F8::{
    global loggedPositions, positionsListBox
    MouseGetPos(&mouseX, &mouseY)
    timestamp := FormatTime("HH:mm:ss")
    newPosition := timestamp . " - X: " . mouseX . ", Y: " . mouseY
    loggedPositions.Push(newPosition)
    positionsListBox.Delete()
    positionsListBox.Add(loggedPositions)
}