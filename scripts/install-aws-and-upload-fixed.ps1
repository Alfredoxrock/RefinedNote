# AWS CLI Installation and EXE Upload Script
# This script will:
# 1. Install AWS CLI v2 (if not already installed)
# 2. Configure AWS credentials (if not already configured)
# 3. Upload the extracted installer EXE to S3
# 4. Generate both public and presigned URLs for Partner Center

param(
    [string]$LocalExePath = 'C:\Temp\NotesInspect\Refined Notes Setup 1.0.0.exe',
    [string]$Bucket = 'notes-app-alfredoxrock-2025',
    [string]$Key = 'releases/Refined-Notes-1.0.0-x64.exe',
    [int]$PresignExpireHours = 24
)

Write-Host "=== AWS CLI Installation and EXE Upload Script ===" -ForegroundColor Green
Write-Host ""

# Step 1: Check if AWS CLI is installed
Write-Host "Step 1: Checking AWS CLI installation..." -ForegroundColor Yellow
try {
    $awsVersion = aws --version 2>$null
    if ($awsVersion) {
        Write-Host "[OK] AWS CLI already installed: $awsVersion" -ForegroundColor Green
    } else {
        throw "AWS CLI not found"
    }
} catch {
    Write-Host "AWS CLI not found. Installing..." -ForegroundColor Yellow
    
    # Check if running as Administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if (-not $isAdmin) {
        Write-Host "[WARNING] For best results, run this script as Administrator to install AWS CLI system-wide." -ForegroundColor Yellow
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            Write-Host "Please restart PowerShell as Administrator and run this script again." -ForegroundColor Red
            exit 1
        }
    }
    
    try {
        Write-Host "Downloading AWS CLI v2..." -ForegroundColor Yellow
        $msiPath = "$env:TEMP\AWSCLIV2.msi"
        Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msiPath -UseBasicParsing
        
        Write-Host "Installing AWS CLI v2..." -ForegroundColor Yellow
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $msiPath, "/quiet" -Wait
        
        # Refresh PATH for current session
        $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        $env:PATH = $machinePath + ";" + $userPath
        
        # Test installation
        Start-Sleep 2
        $awsVersion = aws --version 2>$null
        if ($awsVersion) {
            Write-Host "[OK] AWS CLI installed successfully: $awsVersion" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] AWS CLI installation failed or not in PATH. You may need to restart PowerShell." -ForegroundColor Red
            Write-Host "Try closing and reopening PowerShell, or add AWS CLI to PATH manually." -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-Host "[ERROR] Failed to install AWS CLI: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 2: Check AWS configuration
Write-Host "Step 2: Checking AWS configuration..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    if ($identity) {
        Write-Host "[OK] AWS credentials configured. Using account: $($identity.Account), user/role: $($identity.Arn)" -ForegroundColor Green
    } else {
        throw "No valid AWS credentials"
    }
} catch {
    Write-Host "AWS credentials not configured. Starting configuration..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You'll need your AWS Access Key ID and Secret Access Key." -ForegroundColor Cyan
    Write-Host "These should have permissions for s3:PutObject, s3:GetObject on bucket: $Bucket" -ForegroundColor Cyan
    Write-Host ""
    
    aws configure
    
    # Verify configuration
    try {
        $identity = aws sts get-caller-identity | ConvertFrom-Json
        Write-Host "[OK] AWS credentials configured successfully. Account: $($identity.Account)" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] AWS configuration failed. Please check your credentials." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 3: Check if the EXE file exists
Write-Host "Step 3: Checking installer file..." -ForegroundColor Yellow
if (-not (Test-Path $LocalExePath)) {
    Write-Host "[ERROR] Installer file not found at: $LocalExePath" -ForegroundColor Red
    Write-Host "Please make sure you've extracted the ZIP and the installer is at the expected location." -ForegroundColor Yellow
    exit 1
}

$fileSize = (Get-Item $LocalExePath).Length
Write-Host "[OK] Found installer: $LocalExePath ($([math]::Round($fileSize / 1MB, 2)) MB)" -ForegroundColor Green

Write-Host ""

# Step 4: Upload to S3
Write-Host "Step 4: Uploading to S3..." -ForegroundColor Yellow
Write-Host "Uploading to: s3://$Bucket/$Key" -ForegroundColor Cyan

try {
    # Upload with public-read ACL (if allowed)
    Write-Host "Attempting public upload..." -ForegroundColor Yellow
    aws s3 cp $LocalExePath "s3://$Bucket/$Key" --content-type 'application/octet-stream' --acl public-read
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Upload successful (public)" -ForegroundColor Green
        $uploadedPublic = $true
    } else {
        Write-Host "[WARNING] Public upload failed (possibly due to account restrictions). Trying private upload..." -ForegroundColor Yellow
        # Try private upload
        aws s3 cp $LocalExePath "s3://$Bucket/$Key" --content-type 'application/octet-stream'
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Upload successful (private)" -ForegroundColor Green
            $uploadedPublic = $false
        } else {
            Write-Host "[ERROR] Upload failed" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "[ERROR] Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Generate URLs
Write-Host "Step 5: Generating URLs..." -ForegroundColor Yellow

$publicUrl = "https://$Bucket.s3.amazonaws.com/$Key"

# Test public URL (if uploaded as public)
if ($uploadedPublic) {
    try {
        $response = Invoke-WebRequest -Uri $publicUrl -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-Host "[OK] Public URL accessible (HTTP $($response.StatusCode))" -ForegroundColor Green
        $publicAccessible = $true
    } catch {
        Write-Host "[WARNING] Public URL not accessible: $($_.Exception.Message)" -ForegroundColor Yellow
        $publicAccessible = $false
    }
} else {
    $publicAccessible = $false
}

# Generate presigned URL
try {
    $presignedUrl = aws s3 presign "s3://$Bucket/$Key" --expires-in $($PresignExpireHours * 3600)
    if ($presignedUrl -and $LASTEXITCODE -eq 0) {
        Write-Host "[OK] Presigned URL generated (valid for $PresignExpireHours hours)" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Presigned URL generation failed" -ForegroundColor Yellow
        $presignedUrl = $null
    }
} catch {
    Write-Host "[WARNING] Presigned URL generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    $presignedUrl = $null
}

Write-Host ""

# Step 6: Display results
Write-Host "=== RESULTS FOR PARTNER CENTER ===" -ForegroundColor Green
Write-Host ""

if ($publicAccessible) {
    Write-Host "SUCCESS: USE THIS PUBLIC URL IN PARTNER CENTER:" -ForegroundColor Green
    Write-Host $publicUrl -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This URL is publicly accessible and can be used directly in Partner Center." -ForegroundColor White
} elseif ($presignedUrl) {
    Write-Host "SUCCESS: USE THIS PRESIGNED URL IN PARTNER CENTER:" -ForegroundColor Green
    Write-Host $presignedUrl -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This presigned URL is valid for $PresignExpireHours hours and bypasses public access restrictions." -ForegroundColor White
} else {
    Write-Host "[ERROR] No accessible URL available. Check your bucket policies and permissions." -ForegroundColor Red
}

if ($presignedUrl -and $publicAccessible) {
    Write-Host ""
    Write-Host "ALTERNATIVE PRESIGNED URL (if needed):" -ForegroundColor Yellow
    Write-Host $presignedUrl -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== ADDITIONAL INFO ===" -ForegroundColor Yellow
Write-Host "• Package Architecture: Select 'x64' in Partner Center (or 'neutral' if it supports all architectures)" -ForegroundColor White
Write-Host "• App Type: Select 'EXE' in Partner Center" -ForegroundColor White
Write-Host "• File uploaded to: s3://$Bucket/$Key" -ForegroundColor White
Write-Host "• Local file: $LocalExePath" -ForegroundColor White

Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Green
Write-Host "1. Copy the URL above and paste it into Partner Center's Package URL field" -ForegroundColor White
Write-Host "2. Set Architecture to 'x64' (or appropriate architecture)" -ForegroundColor White
Write-Host "3. Set App Type to 'EXE'" -ForegroundColor White
Write-Host "4. Configure installer parameters and return codes as needed" -ForegroundColor White

Write-Host ""
Write-Host "Script completed successfully!" -ForegroundColor Green