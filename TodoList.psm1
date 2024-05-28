# Define the base file path
$baseFilePath = "D:\"
$baseFileName = "todoList"

# Function to get the list of existing todo files
function Get-TodoFiles {
    Get-ChildItem -Path $baseFilePath -Filter "$baseFileName*.txt" | Sort-Object Name
}

# Function to create a new todo file
function Create-NewTodoFile {
    $files = Get-TodoFiles
    if ($files.Count -eq 0) {
        $newFileName = "$baseFilePath$baseFileName.txt"
    } else {
        $maxFileNumber = 0
        foreach ($file in $files) {
            if ($file.BaseName -match "$baseFileName#(\d+)") {
                $fileNumber = [int]$matches[1]
                if ($fileNumber -gt $maxFileNumber) {
                    $maxFileNumber = $fileNumber
                }
            }
        }
        $newFileNumber = $maxFileNumber + 1
        $newFileName = "$baseFilePath$baseFileName#$newFileNumber.txt"
    }
    New-Item -ItemType File -Path $newFileName -Force
    Start-Process notepad $newFileName -Wait
    return $newFileName
}

# Function to invoke the TodoList script
function Invoke-TodoList {
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'TodoList.psm1'
    & $scriptPath
}

# Main script logic
# Check if a todo file exists
$existingFiles = Get-TodoFiles

if ($existingFiles.Count -eq 0) {
    # No existing file, create a new one
    $todoFile = Create-NewTodoFile
} else {
    Clear-Host
    Write-Host "`n`n THIS IS KATETA TECHNOLOGIES [THE LATESTS]" -ForegroundColor DarkYellow
    Write-Host "`n`t`t FILE ENTRY SYSTEM:" -ForegroundColor Magenta
    Write-Host "`t`t ------------------`n" -ForegroundColor Blue
    for ($i = 0; $i -lt $existingFiles.Count; $i++) {
        Write-Host "$($i + 1). $($existingFiles[$i].Name)`n" -ForegroundColor Green 
    }
    
    $choice = Read-Host "Do you want to continue with an existing file [n/y] or type file number >>"
    
    if ($choice -eq "no") {
        $todoFile = Create-NewTodoFile
    } elseif ($choice -eq "yes" -or [int]::TryParse($choice, [ref]$null)) {
        if ($choice -eq "yes") {
            $fileNumber = 1
        } else {
            $fileNumber = [int]$choice
        }
        if ($fileNumber -gt 0 -and $fileNumber -le $existingFiles.Count) {
            $todoFile = $existingFiles[$fileNumber - 1].FullName
        } else {
            Write-Host "Invalid choice. Exiting." -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "Invalid input. Exiting." -ForegroundColor Red
        exit
    }
}

function Show-Help {
    Write-Host "Usage: .\todo.ps1 [command] [task]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  add [task]        Add a new task"
    Write-Host "  list              List all tasks"
    Write-Host "  done [task number] Mark a task as done"
    Write-Host "  del [task number] Delete a task"
    Write-Host "  help              Show this help message"
    Write-Host "  >[number]         Show tasks under header number"
    Write-Host "  >>[number]        Show tasks under subheader number"
}

function Parse-TodoList {
    $rawTasks = Get-Content -Path $todoFile
    $parsedTasks = @()
    $headerNumber = 0
    $subHeaderNumber = 0
    $subSubHeaderNumber = 0
    $currentHeader = $null
    $currentSubHeader = $null
    $currentSubSubHeader = $null

    foreach ($line in $rawTasks) {
        if ($line -match "^>\s") {
            $headerNumber++
            $subHeaderNumber = 0
            $subSubHeaderNumber = 0
            $currentHeader = [PSCustomObject]@{ Type = 'Header'; Number = $headerNumber; Text = $line.Trim() }
            $parsedTasks += $currentHeader
        } elseif ($line -match "^>>\s") {
            $subHeaderNumber++
            $subSubHeaderNumber = 0
            $currentSubHeader = [PSCustomObject]@{ Type = 'SubHeader'; Number = $subHeaderNumber; Parent = $currentHeader.Number; Text = $line.Trim() }
            $parsedTasks += $currentSubHeader
        } elseif ($line -match "^>>>\s") {
            $subSubHeaderNumber++
            $currentSubSubHeader = [PSCustomObject]@{ Type = 'SubSubHeader'; Number = $subSubHeaderNumber; Parent = "$($currentHeader.Number).$($currentSubHeader.Number)"; Text = $line.Trim() }
            $parsedTasks += $currentSubSubHeader
        } else {
            $taskType = 'Task'
            if ($currentSubSubHeader) {
                $taskType = 'SubSubTask'
                $parent = "$($currentHeader.Number).$($currentSubHeader.Number).$($currentSubSubHeader.Number)"
            } elseif ($currentSubHeader) {
                $taskType = 'SubTask'
                $parent = "$($currentHeader.Number).$($currentSubHeader.Number)"
            } else {
                $parent = $currentHeader.Number
            }
            $parsedTasks += [PSCustomObject]@{ Type = $taskType; Parent = $parent; Text = $line.Trim() }
        }
    }

    return $parsedTasks
}

function List-Tasks {
    param (
        [Array]$visibleHeaders
    )
    $parsedTasks = Parse-TodoList
    $visibleHeaders = $visibleHeaders -join ','

    Write-Host "`n`t`t`tWELCOME BACK TO KATETA TODO-LIST CMD APP" -ForegroundColor Green
    Write-Host "`t`t`t==========================================" -ForegroundColor Cyan
    Write-Host "`n TO-DO TASKS LISTS: `n`n" -ForegroundColor DarkCyan 

    foreach ($task in $parsedTasks) {
        if ($task.Type -eq 'Header') {
            if ($visibleHeaders -match "\b$($task.Number)\b") {
                $headerText = "  >$($task.Text)"
                Write-Host $headerText
                Show-SubTasks -parent "$($task.Number)" -tasks $parsedTasks -visibleHeaders $visibleHeaders
                
                $headerTasks = $parsedTasks | Where-Object { $_.Parent -eq $task.Number -and $_.Type -eq 'Task' }
                $allTasksDone = $headerTasks -ne ($headerTasks | ForEach-Object { $_.Text -match "\[DONE\]" }) -contains $true
                if ($allTasksDone) {
                    $doneTimeStamp = Get-Date -Format "HH:mm:ss dd/MM/yyyy"
                    Write-Host "`t`t$t : $doneTimeStamp" -ForegroundColor cyan
                }
            } else {
                Write-Host "   $($task.Text)" -ForegroundColor DarkYellow
            }
        }
    }
    if ((Get-Content $todoFile).Count -eq 0) {
        Write-Host "No Task Found" -ForegroundColor Cyan
    }
}

function Show-SubTasks {
    param (
        [string]$parent,
        [Array]$tasks,
        [string]$visibleHeaders
    )

    $tasks | ForEach-Object {
        if ($_.Parent -eq $parent -and ($_.Type -eq 'SubHeader' -or $_.Type -eq 'Header')) {
            if ($visibleHeaders -match "\b$($parent).$($_.Number)\b") {
                $subHeaderText = "    `n`n$($_.Text)`n" 
                Write-Host $subHeaderText -ForegroundColor Cyan
                Show-SubTasks -parent "$($parent).$($_.Number)" -tasks $tasks -visibleHeaders $visibleHeaders
            } else {
                Write-Host "    `t`t $($_.Text)`n" ForegroundColor Yellow
            }
        } elseif ($_.Parent -eq $parent -and $_.Type -eq 'SubSubHeader') {
            if ($visibleHeaders -match "\b$parent.$($_.Number)\b") {
                $subSubHeaderText = "      `t`t`t $($_.Text)" 
                Write-Host $subSubHeaderText -ForegroundColor Cyan
                Show-SubTasks -parent "$parent.$($_.Number)" -tasks $tasks -visibleHeaders $visibleHeaders
            } else {
                Write-Host "      `t`t $($_.Text)`n" -ForegroundColor Yellow
            }
        } elseif ($_.Parent -eq $parent -and $_.Type -eq 'Task') {
            if ($_.Text -match "@done") {
                Write-Host "    `t`t`t$($_.Text)" -ForegroundColor Cyan
            } else {
                Write-Host "    `t`t$($_.Text)" -ForegroundColor Blue
            }
        } elseif ($_.Parent -eq $parent -and $_.Type -eq 'SubTask') {
            if ($_.Text -match "@done") {
                Write-Host "      `t`t`t$($_.Text)" -ForegroundColor Cyan
            } else {
                Write-Host "      $($_.Text)" -ForegroundColor Blue
            }
        } elseif ($_.Parent -eq $parent -and $_.Type -eq 'SubSubTask') {
            if ($_.Text -match "@done") {
                Write-Host "        `t`t`t$($_.Text)" -ForegroundColor Cyan
            } else {
                Write-Host "        `t`t`t`t$($_.Text)" -ForegroundColor Blue
            }
        }elseif ($_.Parent -eq $parent -and ($_.Type -eq 'Task' -or $_.Type -eq 'SubTask' -or $_.Type -eq 'SubSubTask')) {
            $taskText = "        $($_.Text)" 
            Write-Host $taskText -ForegroundColor Blue
        }
        
    }
}


function Mark-Done {
    param (
        [string]$TaskNumber
    )
    try {
        $intTaskNumber = [int]$TaskNumber
        $tasks = Get-Content -Path $todoFile
        if ($intTaskNumber -gt 0 -and $intTaskNumber -le $tasks.Length) {
            $tasks[$intTaskNumber - 1] = "$($tasks[$intTaskNumber - 1]) @done $(Get-Date -Format 'HH:mm:ss dd/MM/yyyy')"
            $tasks | Set-Content -Path $todoFile
            Write-Host "Task $intTaskNumber marked as done." -ForegroundColor Green
        } else {
            Write-Host "Invalid task number." -ForegroundColor Red
        }
    } catch {
        Write-Host "Failed to mark task as done: $_" -ForegroundColor Red
    }
}

function Delete-Task {
    param (
        [string]$TaskNumber
    )
    try {
        $intTaskNumber = [int]$TaskNumber
        $tasks = Get-Content -Path $todoFile
        if ($intTaskNumber -gt 0 -and $intTaskNumber -le $tasks.Length) {
            $tasks = $tasks | Where-Object { $_ -ne $tasks[$intTaskNumber - 1] }
            $tasks | Set-Content -Path $todoFile
            Write-Host "Task $intTaskNumber deleted." -ForegroundColor Yellow
        } else {
            Write-Host "Invalid task number." -ForegroundColor Red
        }
    } catch {
        Write-Host "Failed to delete task: $_" -ForegroundColor Red
    }
}

function WaitForFileClosure {
    $processName = (Get-Process | Where-Object { $_.MainWindowTitle -eq "$todoFile - Notepad" }).Name
    while ($processName -eq "notepad") {
        Start-Sleep -Seconds 3
        $processName = (Get-Process | Where-Object { $_.MainWindowTitle -eq "$todoFile - Notepad" }).Name
    }
}


$visibleHeaders = @()

do {
    WaitForFileClosure

    Clear-Host

    List-Tasks -visibleHeaders $visibleHeaders

    $input = Read-Host "`n Task Number "
    switch ($input.ToUpper()) {
        "EXIT" {
            Write-Host "`n`t Exiting the program... " -ForegroundColor DarkYellow
            Start-Sleep -Seconds 2
            return 
        }
        "ADD" {
            Write-Host "`n`t Write your new task in the opened $todoFile file." -ForegroundColor Cyan
            Start-Sleep -Seconds 3
            Start-Process notepad.exe $todoFile
        }
        "EDIT" {
            Write-Host "`n`t Edit the task in the opened $todoFile file." -ForegroundColor DarkCyan
            Start-Sleep -Seconds 3
            Start-Process notepad.exe $todoFile
        }
        "DELETE" {
            $taskNumber = Read-Host "`n`t Select the number you want to delete >> "
            Start-Sleep -Seconds 1
            Delete-Task -TaskNumber $taskNumber
        }
        default {
            if ($input -match "^>(>*)\d+$") {
                $visibleHeaders += $input.TrimStart('>')
            } elseif ([int]::TryParse($input, [ref]$null)) {
                Mark-Done -TaskNumber $input
            } else {
                Write-Host "Invalid input." -ForegroundColor Red
            }
        }
    }
} while ($true)


function Add-ToDoItem {
    param (
        [string]$Item
    )
    $ToDoList += $Item
    Write-Output "Added: $Item"
}

function Get-ToDoList {
    $ToDoList
}

Export-ModuleMember -Function *-ToDoItem