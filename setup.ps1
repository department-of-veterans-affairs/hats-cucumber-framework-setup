
# Set the target directory and URLs
$targetDir = "$HOME\HATS"
$7zipUrl = "https://www.7-zip.org/a/7zr.exe"
$gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.1/PortableGit-2.47.0-64-bit.7z.exe"
$downloads = @{
    "java"   = "https://corretto.aws/downloads/resources/11.0.25.9.1/amazon-corretto-11.0.25.9.1-windows-x64-jdk.zip.sig"
    "maven"  = "https://downloads.apache.org/maven/maven-3/3.8.8/binaries/apache-maven-3.8.8-bin.zip"
    "eclipse"= "https://download.eclipse.org/technology/epp/downloads/release/2024-06/R/eclipse-jee-2024-06-R-win32-x86_64.zip"
}

# Function to download a file
function Download-File-And-Extract {
    param (
        [string]$url,
        [string]$path,
        [string]$app
    )

    if (Test-Path $path) {
        $overwrite = Read-Host "File $path already exists. Overwrite? (Y/N)"
        if ($overwrite -ne 'Y') {
            Write-Host "Skipping download of $url"
            return
        }
    }
    
    Write-Host "Downloading $url..."
    Invoke-WebRequest -Uri $url -OutFile $path
    Write-Host "Extracting $filePath..."
    Unzip-File -zipPath $filePath -extractPath "$targetDir\$app"
}

# Function to unzip files
function Unzip-File {
    param (
        [string]$zipPath,
        [string]$extractPath
    )
    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Write-Host "Unzipped: $zipPath to $extractPath"
    } catch {
        Write-Host "Failed to unzip: $zipPath"
    }
}

# Function to unzip files
function Add-To-Path-From-Filename {
    param (
        [string]$searchDirectory,
        [string]$filename
    )

    # Find all directories containing the specified file
    $directories = Get-ChildItem -Path $searchDirectory -Recurse -Filter $fileName | Select-Object -ExpandProperty DirectoryName -Unique

    foreach ($directory in $directories) {
        # Get the current user PATH
        $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        # Check if the directory is already in PATH
        if (!($currentPath -contains $directory)) {
            # Add the directory to PATH
            $newPath = "$currentPath;$directory"
            #[System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$directory", [EnvironmentVariableTarget]::User)
            #Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newpath
            Write-Host "Added $directory to user PATH."
        } else {
            Write-Host "$directory is already in user PATH."
        }
    }

    if (-not $directories) {
        Write-Host "No directories found containing the file '$fileName'."
    }
}

# Check the length of the PATH variable before starting. Soft max is 2047 characters, we are very unlikely to use more than 350
if ([System.Environment]::GetEnvironmentVariable("PATH").Length -gt 1700) {
    throw "Error: The PATH variable exceeds 1800 characters. Please contact your IT to reduce the size of your PATH variable or reduce it yourself: https://stackoverflow.com/questions/34491244/environment-variable-is-too-large-on-windows-10"
}

# Create target directory if it doesn't exist
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir
}

# Download/Extract the portable (zipped) applications
foreach ($app in $downloads.Keys) {
    $filePath = Join-Path -Path $targetDir -ChildPath "$app.zip"
    Download-File-And-Extract -url $downloads[$app] -app $app -path $filePath
}

# Download 7-Zip if it's not already installed
$sevenZipPath = "$HOME\HATS\7zr.exe"
if (-not (Test-Path $sevenZipPath)) {
    Write-Host "Downloading portable 7-Zip (only good for 7z files)..."
    Invoke-WebRequest -Uri $7zipUrl -OutFile "$HOME\HATS\7zr.exe"
} else {
    Write-Host "7zr.exe already downloaded"
}

if (!(Test-Path "$targetDir\git.zip")) {
    Write-Host "Downloading $gitUrl..."
    Invoke-WebRequest -Uri $gitUrl -OutFile (Join-Path -Path $targetDir -ChildPath "git.zip")
    #Unzip git
    & "$sevenZipPath" x "$HOME\HATS\git.zip" -o"$HOME\HATS\git" -y
} else {
    Write-Host "Git already downloaded. Skipping.."
}

Add-To-Path-From-Filename -searchDirectory "$HOME\HATS\java" -filename "java.exe"
Add-To-Path-From-Filename -searchDirectory "$HOME\HATS\maven" -filename "mvn"
Add-To-Path-From-Filename -searchDirectory "$HOME\HATS\git" -filename "git.exe"

#use the LATEST directory inside the java folder. Hacky but it'll work..
$JavaHome = Get-ChildItem -Path "$HOME\HATS\java" -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1

[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $JavaHome, "User")
[Environment]::SetEnvironmentVariable("JAVA_HOME", $JavaHome.FullName, [EnvironmentVariableTarget]::User)
Write-Host "Added $JavaHome as JAVA_HOME."

# Keep the PowerShell window open
Write-Host "All software installation tasks completed. Press Enter to continue..."
[void][System.Console]::ReadLine()

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
$env:JAVA_HOME = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", [System.EnvironmentVariableTarget]::User)

#TODO - add cacerts to JDK installation

$overwrite = Read-Host "If you use the VA VPN, public certs are required to interact with certain resources. Download and install? (Y/N)"
if ($overwrite -eq 'Y') {
    Write-Host "Downloading VA Cert..."
    Invoke-WebRequest -Uri "https://department-of-veterans-affairs.github.io/github-handbook/guides/security/VA-Internal-S2-RCA1-v1.pem" -OutFile "$targetDir\VA-Internal-S2-RCA1-v1.pem"
    Write-Host "Adding CA cert to cacerts files..."
    # Find all directories containing the specified file
    $cacertsFiles = Get-ChildItem -Path $targetDir -Recurse -Filter "cacerts" | Select-Object -ExpandProperty DirectoryName -Unique
    foreach ($cacertFile in $cacertsFiles) {
        Write-Host "Adding cert to $cacertFile"
        keytool.exe -import -alias va-certificate-authority -file "$targetDir\VA-Internal-S2-RCA1-v1.pem" -keystore $cacertFile -storepass changeit -noprompt
    }
}


    # Check if the file already exists
    if (Test-Path $filePath) {
        $overwrite = $false
        
        # Ask for confirmation to overwrite
        $overwrite = Read-Host "The file already exists. Do you want to overwrite it? (y/n)"
        
        if ($overwrite -ne 'y') {
            Write-Host "Download canceled."
            return
        }
    }

$settingsPath = "$HOME\.m2\settings.xml"
$settingsDownload = Read-Host "Download and place settings.xml to your user .m2 folder (so that you can find/pull VA HATS dependencies)? (Y/N)"
if ($settingsDownload -eq 'Y') {
    if (Test-Path $settingsPath) {
        $overwrite = Read-Host "The file already exists. Do you want to overwrite it? (y/n)"
        if ($overwrite -ne 'y') {
            Write-Host "Download canceled."
            return
        } else {
            Write-Host "Downloading settings.xml..."
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/department-of-veterans-affairs/hats-cucumber-framework-setup/refs/heads/main/settings.xml" -OutFile "$settingsPath"
        }
    }
    else {
        Write-Host "Downloading settings.xml..."
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/department-of-veterans-affairs/hats-cucumber-framework-setup/refs/heads/main/settings.xml" -OutFile "$settingsPath"
    }
}

mvn -v
git -v

$enterGithubCredentials = Read-Host "Enter Github Credentials? (Y/N)"
if ($enterGithubCredentials -eq 'Y') {
    $GithubToken = Read-Host -AsSecureString -Prompt "Please navigate to https://github.com/settings/tokens  and generate a new Classic Token with 'repo' and 'write:packages' scopes. Paste the generated key here"
    $GithubUsername = Read-Host -Prompt "Enter your Github Username (Typically your email)"

    Write-Host "Adding Github Username/Password to environmental variables."
    [Environment]::SetEnvironmentVariable("GITHUB_USR", $GithubUsername, [EnvironmentVariableTarget]::User)
    [Environment]::SetEnvironmentVariable("GITHUB_PSW", $GithubToken, [EnvironmentVariableTarget]::User)
}
# Keep the PowerShell window open
[void][System.Console]::ReadLine()

cd $targetDir

git clone https://github.com/department-of-veterans-affairs/hats-cucumber-framework.git
