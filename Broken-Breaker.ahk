#Requires AutoHotkey v2.0

; Global variables
global isRunning := false
global defaultAnvilInterval := 840000  ; 14 minutes
global anvilIntervalEdit := ""
global anvilRepairCheckbox := ""
global statusText := ""
global detailedStatusText := ""
global coordText := ""
global MyGui := ""
global windowList := ""
global selectedWindow := ""
global defaultInterval := 150000  ; 2.5 minutes
global defaultCommand := "cx"  ; Default command without "/"
global defaultEatInterval := 500000  ; 8.3 minutes
global defaultInventoryInterval := 200000  ; 3.3 minutes
global intervalEdit := ""
global commandEdit := ""
global eatIntervalEdit := ""
global inventoryIntervalEdit := ""
global invPositions := []

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

; Assign F8 to log current mouse position
F8::
{
    LogMousePosition()
}

LogMousePosition() {
    MouseGetPos(&xpos, &ypos)
    coordText.Value := "Last Position: x=" . xpos . ", y=" . ypos
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

; Dodaj tę nową funkcję pomocniczą
FormatTime(ms) {
    if (ms < 60000) { ; mniej niż minuta
        return Round(ms/1000, 1) . " seconds"
    } else if (ms < 3600000) { ; mniej niż godzina
        return Round(ms/60000, 1) . " minutes"
    } else { ; godziny
        return Round(ms/3600000, 1) . " hours"
    }
}

ShowGui() {
    global anvilIntervalEdit, anvilRepairCheckbox, statusText, detailedStatusText, coordText, MyGui, windowList, intervalEdit, commandEdit, eatIntervalEdit, inventoryIntervalEdit
    MyGui := Gui()
    MyGui.SetFont("s10")
    
    ; Make GUI bigger and add padding
    MyGui.MarginX := 20
    MyGui.MarginY := 20
    
    ; Window selector at the top
    MyGui.Add("Text", "xm y+10 Section", "Select game window:")
    windowList := MyGui.Add("DropDownList", "xs y+5 w350 vSelectedWindow", FindMinecraftWindows())
    MyGui.Add("Button", "x+5 w40", "↻").OnEvent("Click", RefreshWindowList)
    
    ; First Row
    MyGui.Add("GroupBox", "xs y+20 Section w380 h85", "Anvil Repair Settings")
    anvilRepairCheckbox := MyGui.Add("Checkbox", "xp+10 yp+20 Checked", "Enable anvil repair")
    MyGui.Add("Text", "xp y+10", "Repair interval (milliseconds):")
    anvilIntervalEdit := MyGui.Add("Edit", "w150", defaultAnvilInterval)
    timeText := MyGui.Add("Text", "x+10", "= " . FormatTime(defaultAnvilInterval))
    anvilIntervalEdit.OnEvent("Change", (*) => timeText.Value := "= " . FormatTime(Integer(anvilIntervalEdit.Value)))
    
    ; Command settings section
    MyGui.Add("GroupBox", "x+40 ys w380 h85", "Command Settings")
    MyGui.Add("Text", "xp+10 yp+20", "Command interval (milliseconds):")
    intervalEdit := MyGui.Add("Edit", "w150", defaultInterval)
    timeText1 := MyGui.Add("Text", "x+10", "= " . FormatTime(defaultInterval))
    intervalEdit.OnEvent("Change", (*) => timeText1.Value := "= " . FormatTime(Integer(intervalEdit.Value)))
    MyGui.Add("Text", "xp y+10", "Command to send:")
    commandEdit := MyGui.Add("Edit", "w150", defaultCommand)
    
    ; Second Row
    MyGui.Add("GroupBox", "xs y+20 w380 h85", "Auto-Eat Settings")
    MyGui.Add("Text", "xp+10 yp+20", "Auto-eat interval (milliseconds):")
    eatIntervalEdit := MyGui.Add("Edit", "w150", defaultEatInterval)
    timeText2 := MyGui.Add("Text", "x+10", "= " . FormatTime(defaultEatInterval))
    eatIntervalEdit.OnEvent("Change", (*) => timeText2.Value := "= " . FormatTime(Integer(eatIntervalEdit.Value)))
    
    ; Inventory check settings
    MyGui.Add("GroupBox", "x+40 yp w380 h85", "Inventory Check Settings")
    MyGui.Add("Text", "xp+10 yp+20", "Inventory check interval (milliseconds):")
    inventoryIntervalEdit := MyGui.Add("Edit", "w150", defaultInventoryInterval)
    timeText3 := MyGui.Add("Text", "x+10", "= " . FormatTime(defaultInventoryInterval))
    inventoryIntervalEdit.OnEvent("Change", (*) => timeText3.Value := "= " . FormatTime(Integer(inventoryIntervalEdit.Value)))
    
    ; Status section at bottom
    MyGui.Add("Text", "xm y+40 w800 h2 0x10")
    statusText := MyGui.Add("Text", "xm y+10 w800 Center", "Status: Waiting to start...")
    detailedStatusText := MyGui.Add("Text", "xm y+10 w800 Center", "")
    
    ; Make GUI stay on top
    MyGui.Opt("+AlwaysOnTop")
    
    ; Show GUI window with new width
    MyGui.Show("w850 h400")
}

RefreshWindowList(*) {
    global windowList
    windowList.Delete()
    windowList.Add(FindMinecraftWindows())
}

RepairPickaxe() {
    global isRunning, selectedWindow, anvilRepairCheckbox, detailedStatusText
    if !isRunning || !anvilRepairCheckbox.Value
        return
        
    if WinExist(selectedWindow) {
        ; Stop mining
        detailedStatusText.Value := "Stopping mining..."
        SendInput("{LButton up}")
        Sleep(200)
        
        ; Move left
        detailedStatusText.Value := "Moving left..."
        SendInput("{a down}")
        Sleep(1000)
        SendInput("{a up}")
        Sleep(200)
        
        ; Open anvil with right click
        detailedStatusText.Value := "Opening anvil..."
        SendInput("{RButton}")
        Sleep(500)

        ; 1. Move to first position and shift+left click (kilof)
        detailedStatusText.Value := "Step 1: First shift-click..."
        MouseMove(491, 495)  ; Nowa pozycja kilofa
        Sleep(200)
        SendInput("{LShift down}")
        Sleep(100)
        SendInput("{LButton}")
        Sleep(100)
        SendInput("{LShift up}")
        Sleep(200)

        ; 2. Move to second position and shift+left click (diamenty)
        detailedStatusText.Value := "Step 2: Second shift-click..."
        MouseMove(567, 493)  ; Nowa pozycja diamentów
        Sleep(200)
        SendInput("{LShift down}")
        Sleep(100)
        SendInput("{LButton}")
        Sleep(100)
        SendInput("{LShift up}")
        Sleep(200)

        ; 3. Click at result position
        detailedStatusText.Value := "Step 3: Clicking result..."
        MouseMove(739, 296)  ; Pozostaje bez zmian
        Sleep(200)
        SendInput("{LButton}")
        Sleep(200)

        ; 4. Move back to first position and click (kilof)
        detailedStatusText.Value := "Step 4: Moving items back..."
        MouseMove(491, 495)  ; Nowa pozycja kilofa
        Sleep(200)
        SendInput("{LButton}")
        Sleep(200)

        ; 5. Move to anvil slot and click
        detailedStatusText.Value := "Step 5: Anvil slot click..."
        MouseMove(625, 293)  ; Pozostaje bez zmian
        Sleep(200)
        SendInput("{LButton}")
        Sleep(200)

        ; 6. Move to last position and click (diamenty)
        detailedStatusText.Value := "Step 6: Final click..."
        MouseMove(567, 493)  ; Nowa pozycja diamentów
        Sleep(200)
        SendInput("{LButton}")
        Sleep(200)

        ; 7. Close anvil
        detailedStatusText.Value := "Step 7: Closing anvil..."
        SendInput("e")
        Sleep(200)

        ; 8. Move right
        detailedStatusText.Value := "Step 8: Moving right..."
        SendInput("{d down}")
        Sleep(1000)
        SendInput("{d up}")
        Sleep(200)

        ; Resume mining
        detailedStatusText.Value := "Resuming mining..."
        if (isRunning)
            SendInput("{LButton down}")
    }
}

; Start function
Start(*) {
    global isRunning, anvilIntervalEdit, intervalEdit, eatIntervalEdit, inventoryIntervalEdit, statusText, windowList, commandEdit, selectedWindow
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
        
    anvilInterval := Integer(anvilIntervalEdit.Value)
    if (anvilInterval < 10000)
        anvilInterval := 10000
        
    isRunning := true
    
    SendInput("{LButton down}")
    SetTimer(SendCommand, interval)
    SetTimer(Eat, eatInterval)
    SetTimer(CheckInventory, inventoryInterval)
    SetTimer(RepairPickaxe, anvilInterval)
    
    statusText.Text := "Status: RUNNING - Press - to stop"
}

; Stop function
Stop(*) {
    global isRunning, statusText
    if !isRunning
        return
        
    isRunning := false
    
    SendInput("{LButton up}")
    SetTimer(SendCommand, 0)
    SetTimer(Eat, 0)
    SetTimer(CheckInventory, 0)
    SetTimer(RepairPickaxe, 0)
    
    statusText.Text := "Status: STOPPED - Press + to start"
}

IsBlackPixel(x, y) {
    color := PixelGetColor(x, y)
    r := (color & 0xFF0000) >> 16
    g := (color & 0x00FF00) >> 8
    b := color & 0x0000FF
    return (r < 30 && g < 30 && b < 30)
}

CheckInventory() {
    global isRunning, selectedWindow
    if !isRunning
        return
        
    if WinExist(selectedWindow) {
        ; Stop mining and open inventory
        SendInput("{LButton up}")
        Sleep(200)
        SendInput("e")
        Sleep(500)
        
        ; Define inventory area boundaries
        leftX := 499    ; Left boundary
        topY := 379     ; Top boundary
        rightX := 850   ; Right boundary - zwiększone z 782 na 850 aby objąć więcej slotów w prawo
        bottomY := 495  ; Bottom boundary
        stepSize := 36  ; Approximate size of inventory slot
        
        ; Scan inventory area
        y := topY
        while (y <= bottomY) {
            x := leftX
            while (x <= rightX) {
                if (IsBlackPixel(x, y)) {
                    ; Move to black item
                    MouseMove(x, y)
                    Sleep(50)
                    
                    ; Drop item (Ctrl + Q)
                    SendInput("{LControl down}")
                    Sleep(50)
                    SendInput("q")
                    Sleep(50)
                    SendInput("{LControl up}")
                    
                    ; Wait before next action
                    Sleep(250)
                }
                x += stepSize
            }
            y += stepSize
        }
        
        ; Close inventory and resume mining
        SendInput("e")
        Sleep(200)
        
        if (isRunning)
            SendInput("{LButton down}")
    }
}

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






