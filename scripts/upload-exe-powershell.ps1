# AWS EXE Upload - PowerShell Modules Method
# Alternative to AWS CLI - uses AWS PowerShell modules

param(
    [string]$LocalExePath = 'C:\Temp\NotesInspect\Refined Notes Setup 1.0.0.exe',
    [string]$Bucket = 'notes-app-alfredoxrock-2025',
    [string]$Key = 'releases/Refined-Notes-1.0.0-x64.exe',
    [int]$PresignExpireHours = 24
)

Write-Host "=== AWS EXE Upload - PowerShell Modules Method ===" -ForegroundColor Green
Write-Host ""

# Step 1: Install AWS PowerShell modules
Write-Host "Step 1: Installing AWS PowerShell modules..." -ForegroundColor Yellow

# Check if modules are already installed
$awsModule = Get-Module -ListAvailable -Name AWS.Tools.S3
if ($awsModule) {
    Write-Host "[OK] AWS.Tools.S3 module already installed" -ForegroundColor Green
} else {
    try {
        # Install NuGet provider if needed
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-Host "Installing NuGet provider..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
        }
        
        # Set PSGallery as trusted
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        
        Write-Host "Installing AWS.Tools.S3 module..." -ForegroundColor Yellow
        Install-Module -Name AWS.Tools.S3 -Scope CurrentUser -Force
        
        Write-Host "[OK] AWS PowerShell modules installed" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to install AWS modules: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Import modules
Import-Module AWS.Tools.S3 -Force

Write-Host ""

# Step 2: Configure AWS credentials
Write-Host "Step 2: Configuring AWS credentials..." -ForegroundColor Yellow

# Check if credentials are available
try {
    $identity = Get-STSCallerIdentity -ErrorAction Stop
    Write-Host "[OK] AWS credentials configured. Account: $($identity.Account), User: $($identity.Arn)" -ForegroundColor Green
} catch {
    Write-Host "AWS credentials not configured. Please provide your credentials:" -ForegroundColor Yellow
    
    $accessKey = Read-Host "AWS Access Key ID"
    $secretKey = Read-Host "AWS Secret Access Key" -AsSecureString
    $region = Read-Host "Default region (e.g., us-east-2)"
    
    # Convert SecureString to plain text for AWS cmdlets
    $secretKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretKey))
    
    # Set credentials for this session
    Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKeyPlain -StoreAs 'default'
    Set-DefaultAWSRegion -Region $region
    
    # Test credentials
    try {
        $identity = Get-STSCallerIdentity
        Write-Host "[OK] AWS credentials configured successfully. Account: $($identity.Account)" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Invalid AWS credentials. Please check and try again." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 3: Check installer file
Write-Host "Step 3: Checking installer file..." -ForegroundColor Yellow
if (-not (Test-Path $LocalExePath)) {
    Write-Host "[ERROR] Installer file not found at: $LocalExePath" -ForegroundColor Red
    exit 1
}

$fileSize = (Get-Item $LocalExePath).Length
Write-Host "[OK] Found installer: $LocalExePath ($([math]::Round($fileSize / 1MB, 2)) MB)" -ForegroundColor Green

Write-Host ""

# Step 4: Upload to S3
Write-Host "Step 4: Uploading to S3..." -ForegroundColor Yellow
Write-Host "Uploading to: s3://$Bucket/$Key" -ForegroundColor Cyan

try {
    # Try public upload first
    Write-Host "Attempting public upload..." -ForegroundColor Yellow
    Write-S3Object -BucketName $Bucket -Key $Key -File $LocalExePath -ContentType 'application/octet-stream' -CannedACLName 'public-read' -ErrorAction Stop
    Write-Host "[OK] Upload successful (public)" -ForegroundColor Green
    $uploadedPublic = $true
} catch {
    Write-Host "[WARNING] Public upload failed: $($_.Exception.Message)" -ForegroundColor Yellow
    try {
        # Try private upload
        Write-Host "Attempting private upload..." -ForegroundColor Yellow
        Write-S3Object -BucketName $Bucket -Key $Key -File $LocalExePath -ContentType 'application/octet-stream' -ErrorAction Stop
        Write-Host "[OK] Upload successful (private)" -ForegroundColor Green
        $uploadedPublic = $false
    } catch {
        Write-Host "[ERROR] Upload failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 5: Generate URLs
Write-Host "Step 5: Generating URLs..." -ForegroundColor Yellow

$publicUrl = "https://$Bucket.s3.amazonaws.com/$Key"

# Test public URL
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
    $presignedUrl = Get-S3PreSignedURL -BucketName $Bucket -Key $Key -Expire (Get-Date).AddHours($PresignExpireHours) -Verb GET
    Write-Host "[OK] Presigned URL generated (valid for $PresignExpireHours hours)" -ForegroundColor Green
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
} elseif ($presignedUrl) {
    Write-Host "SUCCESS: USE THIS PRESIGNED URL IN PARTNER CENTER:" -ForegroundColor Green
    Write-Host $presignedUrl -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This presigned URL is valid for $PresignExpireHours hours." -ForegroundColor White
} else {
    Write-Host "[ERROR] No accessible URL available." -ForegroundColor Red
}

if ($presignedUrl -and $publicAccessible) {
    Write-Host "ALTERNATIVE PRESIGNED URL:" -ForegroundColor Yellow
    Write-Host $presignedUrl -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Green
Write-Host "1. Copy the URL above and paste it into Partner Center's Package URL field" -ForegroundColor White
Write-Host "2. Set Architecture to 'x64'" -ForegroundColor White
Write-Host "3. Set App Type to 'EXE'" -ForegroundColor White

Write-Host ""
Write-Host "Script completed successfully!" -ForegroundColor Green