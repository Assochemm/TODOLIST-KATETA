# Install-ToDoListApp.ps1
$modulePath = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules\ToDoListApp'
if (-Not (Test-Path $modulePath)) {
    New-Item -ItemType Directory -Path $modulePath -Force
}

$url = "https://github.com/Assochemm/TODOLIST-KATETA/archive/refs/heads/main.zip"
$zipPath = Join-Path $env:TEMP 'TodoList.zip'
Invoke-WebRequest -Uri $url -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $modulePath -Force

Move-Item -Path (Join-Path $modulePath 'TODOLIST-KATETA-main\*') -Destination $modulePath -Force
Remove-Item -Path (Join-Path $modulePath 'TODOLIST-KATETA-main') -Recurse -Force
Remove-Item -Path $zipPath -Force

Write-Output "ToDoListApp installed successfully." -Foreground-color Green
