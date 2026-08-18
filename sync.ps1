git add .

$message = Read-Host "Enter commit message"

if ([string]::IsNullOrWhiteSpace($message)) {
    Write-Host "Commit message cannot be empty."
    exit 1
}

git commit -m "$message"

if ($LASTEXITCODE -eq 0) {
    git push origin main
}