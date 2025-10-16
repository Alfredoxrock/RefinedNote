<#
inspect-zip-and-upload.ps1

Usage examples:
# 1) Download a ZIP from S3 URL and list entries:
#    .\scripts\inspect-zip-and-upload.ps1 -S3Url 'https://bucket.s3.amazonaws.com/releases/Refined-Notes-1.0.0.zip'

# 2) Inspect a local ZIP:
#    .\scripts\inspect-zip-and-upload.ps1 -LocalZip 'C:\path\to\Refined-Notes-1.0.0.zip'

# 3) Recreate a correct ZIP from a local installer and optionally upload to S3:
#    .\scripts\inspect-zip-and-upload.ps1 -InstallerPath 'C:\path\to\Setup.exe' -Version '1.0.0' -Upload -S3Bucket 'notes-app-alfredoxrock-2025'

# Notes:
# - This script prefers the AWS PowerShell module (AWS.Tools). If that is not available it will try Invoke-WebRequest to download the S3 URL.
# - When uploading it uses Write-S3Object (AWS.Tools). Ensure your credentials are configured (env vars or profile).
# - Do NOT commit credentials. Delete this script after use if it contains sensitive values.
#>

param(
  [string]$S3Url,
  [string]$LocalZip,
  [string]$InstallerPath,
  [switch]$Upload,
  [string]$S3Bucket,
  [string]$Version = '1.0.0'
)

function Write-Log($s){ Write-Output $s }

# helper to compute sha256
function Get-SHA256([string]$path){
  if (-not (Test-Path $path)) { throw "File not found: $path" }
  return (Get-FileHash -Path $path -Algorithm SHA256).Hash
}

# download S3 URL to temp file using AWSPowerShell if available, else Invoke-WebRequest
function Download-S3UrlToTemp([string]$url){
  $tmp = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName() + '.zip')
  Write-Log "Downloading $url -> $tmp"
  # try to parse s3 url
  try{
    if ($url -match '^https?://([^./]+)\.s3[.-]([^.]+)\.(amazonaws\.com)/(.+)$'){
      # fallthrough to generic
    }
  } catch {}
  # prefer Read-S3Object if available
  if (Get-Command -Name Read-S3Object -ErrorAction SilentlyContinue){
    # try parse bucket/key from s3:// or https URL
    if ($url -match '^s3://([^/]+)/(.+)$'){
      $bucket = $matches[1]; $key = $matches[2]
      Write-Log "Using Read-S3Object for s3:// URL"
      Read-S3Object -BucketName $bucket -Key $key -File $tmp -ErrorAction Stop
      return $tmp
    } else {
      # try to parse https://bucket.s3.amazonaws.com/key
      if ($url -match '^https?://([^./]+)\.s3[.-]([^.]+)\.(amazonaws\.com)/(.*)$'){
        $bucket = $matches[1]; $key = $matches[4]
        Write-Log "Using Read-S3Object for https S3 URL (bucket=$bucket)"
        Read-S3Object -BucketName $bucket -Key $key -File $tmp -ErrorAction Stop
        return $tmp
      }
    }
  }
  # fallback to Invoke-WebRequest
  try{
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
    return $tmp
  } catch {
    throw "Failed to download $url : $($_.Exception.Message)"
  }
}

function List-ZipEntries([string]$zipPath){
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $z = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try{
    $entries = $z.Entries | Select-Object FullName, Length
    return $entries
  } finally {
    $z.Dispose()
  }
}

function HasTopLevelInstaller([array]$entries){
  foreach ($e in $entries){
    $name = $e.FullName
    if ($name -notmatch '/'){ # top-level (no slash)
      if ($name -match '\.(exe|msi)$' -or $name -match '\.msix$' -or $name -match '\.appx$'){
        return $true, $name
      }
    }
  }
  return $false, $null
}

# main
try{
  $zipPath = $null
  if ($S3Url){
    $zipPath = Download-S3UrlToTemp -url $S3Url
  } elseif ($LocalZip){
    if (-not (Test-Path $LocalZip)) { throw "Local ZIP not found: $LocalZip" }
    $zipPath = $LocalZip
  } else {
    Write-Log "No source ZIP specified. If you want to create a correct ZIP from a local installer, pass -InstallerPath and -Upload -S3Bucket."
  }

  if ($zipPath){
    Write-Log "Inspecting ZIP: $zipPath"
    $entries = List-ZipEntries -zipPath $zipPath
    $entries | Format-Table FullName, Length -AutoSize
    $has, $installerName = HasTopLevelInstaller -entries $entries
    if ($has){
      Write-Log "Found top-level installer in ZIP: $installerName"
      $sha = Get-SHA256 $zipPath
      Write-Log "ZIP_SHA256=$sha"
      Write-Log "If this is the file you submitted to Partner Center, use the ZIP URL and this SHA256."
      return
    } else {
      Write-Log "No top-level installer found inside the ZIP. Partner Center expects the installer at the ZIP root (e.g. MyApp-Setup.exe)."
      Write-Log "You can recreate a correct ZIP from your installer and upload it. Pass -InstallerPath and -Upload -S3Bucket to do that."
    }
  }

  if ($InstallerPath){
    if (-not (Test-Path $InstallerPath)) { throw "Installer path not found: $InstallerPath" }
  $zipOut = Join-Path $env:TEMP ("Refined-Notes-$Version.zip")
    Write-Log "Creating ZIP $zipOut containing $InstallerPath (at root)"
    if (Test-Path $zipOut){ Remove-Item $zipOut -Force }
    Compress-Archive -Path $InstallerPath -DestinationPath $zipOut -Force
    Write-Log "ZIP created: $zipOut"
    $entries = List-ZipEntries -zipPath $zipOut
    $entries | Format-Table FullName, Length -AutoSize
    $sha = Get-SHA256 $zipOut
    Write-Log "ZIP_SHA256=$sha"

    if ($Upload){
      if (-not $S3Bucket){ throw "To upload, specify -S3Bucket <bucket-name>" }
      Write-Log "Uploading $zipOut to s3://$S3Bucket/releases/Refined-Notes-$Version.zip"
        if (Get-Command -Name Write-S3Object -ErrorAction SilentlyContinue){
          Write-S3Object -BucketName $S3Bucket -Key "releases/Refined-Notes-$Version.zip" -File $zipOut -ErrorAction Stop
          $url = "https://$S3Bucket.s3.amazonaws.com/releases/Refined-Notes-$Version.zip"
        Write-Log "Uploaded to: $url"
        Write-Log "ZIP_SHA256=$sha"
      } else {
        # fallback to aws cli
        if (Get-Command -Name aws -ErrorAction SilentlyContinue){
            aws s3 cp $zipOut "s3://$S3Bucket/releases/Refined-Notes-$Version.zip"
            $url = "https://$S3Bucket.s3.amazonaws.com/releases/Refined-Notes-$Version.zip"
          Write-Log "Uploaded to: $url"
          Write-Log "ZIP_SHA256=$sha"
        } else {
          throw "Cannot upload: neither Write-S3Object nor aws CLI found in PATH"
        }
      }
    }
  }

} catch {
  Write-Error $_.Exception.Message
  exit 1
}

Write-Log "Done."
