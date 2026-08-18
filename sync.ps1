git add .

$message = "Auto-commit: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

git commit -m "$message"

if ($LASTEXITCODE -eq 0) {
    git push origin main
}