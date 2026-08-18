$folder = "D:\my_app\lib"

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $folder
$watcher.Filter = "*.dart"
$watcher.EnableRaisingEvents = $true
$watcher.IncludeSubdirectories = $true

Write-Host "Watching for changes..."

Register-ObjectEvent $watcher "Changed" -Action {
    Start-Sleep -Milliseconds 800
    Write-Host "Change detected, syncing..."
    powershell -ExecutionPolicy Bypass -File D:\my_app\sync.ps1
} | Out-Null

while ($true) {
    Wait-Event -Timeout 1 | Out-Null
}
