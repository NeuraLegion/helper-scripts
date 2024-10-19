<#
.SYNOPSIS
    Script checks for all runing Scans (Legacy, Modern and Discovery) and provides information in the console and optionally stores them in the CSV file
.DESCRIPTION
    Script will retrieve all Projects, then iterate through each project and retrieve all active Discovery Scans. 
    After that the script will retrieve all active Scans
    If Results parameter is specified the script will store retrieved info in a CSV file at designated location
    otherwise the script will just output results in the console
.PARAMETER BaseUri
    Specifies the cluster target Organization is hosted on default: "https://app.brightsec.com/"
.PARAMETER Token
    Specifies the Token on the target organization
.PARAMETER Results
    Specifies the path to the CSV file results file will be stored. NOTE: Results CSV file will be overwritten on each run.
    Specified results path must be only a Filename example "AllRunningScans.csv" or a valid path including the Filename, example: "C:\Users\Support201\AllRunningScans.csv""
.EXAMPLE
    GetAllRunningScans.ps1 -Token "xxxxx.xxxx.xxxxxxxxxxxxxxxxxx"
.EXAMPLE
    GetAllRunningScans.ps1 -Token "xxxxx.xxxx.xxxxxxxxxxxxxxxxxx" -Results "C:\Users\Support201\AllRunningScans.csv"
.EXAMPLE
    GetAllRunningScans.ps1 -BaseUri "eu.brightsec.com" -Token "xxxxx.xxxx.xxxxxxxxxxxxxxxxxx" -Results "AllRunningScans.csv"
.NOTES
    Developed by Mahir Mujkanovic @BrightSec.com 14.10.2024 v1.1 
.LINK
    Official guides on how to retrieve tokens:
    https://docs.brightsec.com/docs/manage-your-personal-account#managing-your-personal-api-keys-authentication-tokens
    https://docs.brightsec.com/docs/manage-your-organization#manage-organization-apicli-authentication-tokens
#>

param
(
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$BaseUri="https://app.brightsec.com/",
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Token,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][System.IO.FileInfo]$Results
)
###Define Constants
$Limit = 100
$baseUri = $BaseUri
$GetAllProjectsQry = "$baseUri/api/v2/projects?limit=$Limit"
$GetAllScansQry = "$baseUri/api/v2/scans?limit=$Limit"
$GetAllDiscoveriesBaseQry = "$baseUri/api/v2/projects"

$AllScansPropertiesList = "name,id,projectID,status,startTime,endTime,startedById,organizationId,repeater,createdAt"

$token = $Token
$Headers = @{
    'accept' = 'application/json'
    'Authorization' = "Api-Key $token"
}

### Get all projects from the target organisation

 # Set projectsOffset for initial query
$projectsOffset = 0

$ListOfAllProjects =  New-Object System.Collections.Generic.List[System.Object]
 # Query first set of Projects
$listOfProjects = (Invoke-RestMethod -Headers $Headers $($GetAllProjectsQry)).items | Select-Object -Property name,id

while($listOfProjects.Count -gt 0)
{
    foreach($project in $listOfProjects)
    {
        #$projectCsv = (ConvertTo-Csv -InputObject $project -NoTypeInformation)[1]
        $ListOfAllProjects.Add($project)
    }
    
    $projectsOffset += $Limit
    $listOfProjects = (Invoke-RestMethod -Headers $Headers $("$GetAllProjectsQry&offset=$projectsOffset")).items | Select-Object -Property name,id
}

### Get All Running Scans

$ListOfAllActiveScans =  New-Object System.Collections.Generic.List[System.Object]
$ListOfAllActiveScans.Add($AllScansPropertiesList)

### Get all Running Discovery Scans
foreach($project in $ListOfAllProjects)
{
    $runningDiscoveryScan = ((Invoke-RestMethod -Headers $Headers "$GetAllDiscoveriesBaseQry/$($project.id)/discoveries?limit=$Limit&moveTo=next&status[]=pending&status[]=searching").items | Select-Object -Property name,id,projectID,status,startTime,endTime,startedById,organizationId,repeater,createdAt)

    foreach($discovery in $runningDiscoveryScan)
    {
        $activeDiscovery = (ConvertTo-Csv -InputObject $discovery -NoTypeInformation)[1]
        $ListOfAllActiveScans.Add($activeDiscovery)
    }
   
}

### Get all running Scans
$TargetAllScansList = ((Invoke-RestMethod -Headers $Headers "$GetAllScansQry&moveTo=next&status[]=pending&status[]=running").items | Select-Object -Property name,id,projectID,status,startTime,endTime,startedById,organizationId,repeater,createdAt)

foreach($scan in $TargetAllScansList)
{
    $activeScan = (ConvertTo-Csv -InputObject $scan -NoTypeInformation)[1]
    $ListOfAllActiveScans.Add($activeScan)
}

### Provide results
Write-Host $ListOfAllActiveScans

if(-not ([string]::IsNullOrEmpty($Results)))
{
    $AllScansCSVPath = $Results 

    if($Results -match '\\' -or $Results -match '/' )
    {
        if(Test-Path $(Split-Path -Path $Results -Parent))
        {
            Set-Content -Value $ListOfAllActiveScans -Path $AllScansCSVPath
        }
        else
        {
            Write-Host "Specified results path does not exist. Please specifiy a full file path, example: ""C:\Users\Support201\AllRunningScans.csv""\n ^
            Or remove the '\' or '/' from the Results path to indicate only a file name was set"
            Return
        }
    }
    else
    {
        Set-Content -Value $ListOfAllActiveScans -Path $AllScansCSVPath
    }
}