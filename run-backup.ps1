# Define variables
$gitlabApiUrl = "https://gitlab.com/api/v4"
$gitlabToken = "<your_gitlab_token>"  # Replace with your GitLab Personal Access Token
$backupRootDir = "C:\gitlab-full-backups"  # Root backup directory
$dateTime = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")

# Create backup structure
$backupDir = Join-Path -Path $backupRootDir -ChildPath $dateTime

# Ensure the root backup directory exists
if (!(Test-Path -Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

# Define a different log directory
$logDirectory = "C:\gitlab-backup-logs"  # Change this to your desired log directory

# Ensure the log directory exists
if (!(Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}

# Define the log file path
$logFilePath = Join-Path -Path $logDirectory -ChildPath "backup-log-$dateTime.txt"

# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $logEntry = "$timestamp - $message"
    Write-Output $logEntry
    Add-Content -Path $logFilePath -Value $logEntry
}

# Define the GitLab API request headers
$headers = @{
    "Private-Token" = $gitlabToken
}

# Step 1: Backup all repositories
Log-Message "Backing up all repositories..."
$projects = Invoke-RestMethod -Uri "$gitlabApiUrl/projects?membership=true&per_page=100" -Method Get -Headers $headers

# Loop through all projects
foreach ($project in $projects) {
    $projectId = $project.id
    $projectName = $project.name -replace '[\/:*?"<>|]', '_'  # Sanitize project name for folder
    $projectBackupDir = Join-Path -Path $backupDir -ChildPath $projectName

    # Create a directory for the project backups
    if (!(Test-Path -Path $projectBackupDir)) {
        New-Item -ItemType Directory -Path $projectBackupDir | Out-Null
    }

    # Get all branches for the project
    $branches = Invoke-RestMethod -Uri "$gitlabApiUrl/projects/$projectId/repository/branches" -Method Get -Headers $headers

    # Loop through all branches
    foreach ($branch in $branches) {
        $branchName = $branch.name -replace '[\/:*?"<>|]', '_'  # Sanitize branch name for file name
        $backupFileName = "$projectName-$branchName-$dateTime.tar.gz"
        $backupFilePath = Join-Path -Path $projectBackupDir -ChildPath $backupFileName

        # Backup the repository archive for the branch
        $archiveUrl = "$gitlabApiUrl/projects/$projectId/repository/archive.tar.gz?sha=$branchName"
        Log-Message "Downloading repository archive for project: $projectName (Branch: $branchName)"
        
        # Try to download the archive and catch 404 errors
        try {
            Invoke-RestMethod -Uri $archiveUrl -Method Get -Headers $headers -OutFile $backupFilePath
            if (Test-Path -Path $backupFilePath) {
                Log-Message "Repository archive downloaded successfully: $backupFilePath"
            }
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 404) {
                Log-Message "404 Error: Repository archive not found for $projectName (Branch: $branchName)."
            } else {
                Log-Message "Error downloading repository archive for $projectName (Branch: $branchName): $_"
            }
        }
    }

    # Backup tags for the project
    $tags = Invoke-RestMethod -Uri "$gitlabApiUrl/projects/$projectId/repository/tags" -Method Get -Headers $headers

    # Loop through all tags
    foreach ($tag in $tags) {
        $tagName = $tag.name -replace '[\/:*?"<>|]', '_'  # Sanitize tag name for file name
        $backupFileName = "$projectName-$tagName-$dateTime.tar.gz"
        $backupFilePath = Join-Path -Path $projectBackupDir -ChildPath $backupFileName

        # Backup the repository archive for the tag
        $archiveUrl = "$gitlabApiUrl/projects/$projectId/repository/archive.tar.gz?sha=$tagName"
        Log-Message "Downloading repository archive for project: $projectName (Tag: $tagName)"
        
        # Try to download the archive and catch 404 errors
        try {
            Invoke-RestMethod -Uri $archiveUrl -Method Get -Headers $headers -OutFile $backupFilePath
            if (Test-Path -Path $backupFilePath) {
                Log-Message "Repository archive downloaded successfully: $backupFilePath"
            }
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 404) {
                Log-Message "404 Error: Repository archive not found for $projectName (Tag: $tagName)."
            } else {
                Log-Message "Error downloading repository archive for $projectName (Tag: $tagName): $_"
            }
        }
    }

    # Backup issues
    $issues = Invoke-RestMethod -Uri "$gitlabApiUrl/projects/$projectId/issues" -Method Get -Headers $headers
    $issuesFilePath = Join-Path -Path $projectBackupDir -ChildPath "$projectName-issues.json"
    Log-Message "Backing up issues for project: $projectName"
    $issues | ConvertTo-Json | Out-File -FilePath $issuesFilePath -Encoding utf8
    Log-Message "Issues for project $projectName backed up successfully to $issuesFilePath."

    # Backup CI/CD pipelines
    $pipelines = Invoke-RestMethod -Uri "$gitlabApiUrl/projects/$projectId/pipelines" -Method Get -Headers $headers
    $pipelinesFilePath = Join-Path -Path $projectBackupDir -ChildPath "$projectName-pipelines.json"
    Log-Message "Backing up CI/CD pipelines for project: $projectName"
    $pipelines | ConvertTo-Json | Out-File -FilePath $pipelinesFilePath -Encoding utf8
    Log-Message "CI/CD pipelines for project $projectName backed up successfully to $pipelinesFilePath."

    # Backup project settings
    $projectSettings = Invoke-RestMethod -Uri "$gitlabApiUrl/projects/$projectId" -Method Get -Headers $headers
    $settingsFilePath = Join-Path -Path $projectBackupDir -ChildPath "$projectName-settings.json"
    Log-Message "Backing up settings for project: $projectName"
    $projectSettings | ConvertTo-Json | Out-File -FilePath $settingsFilePath -Encoding utf8
    Log-Message "Settings for project $projectName backed up successfully to $settingsFilePath."
}

Log-Message "Backup of all projects completed. All files saved in $backupDir."
