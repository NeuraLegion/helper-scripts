<#
.SYNOPSIS
    Script maps provided Issue IDs with Projects and save the results in a .CSV file.
.DESCRIPTION
    Script will retrieve all Projects, then iterate through each project and retrieve all issues and compare them to the provided list of Issue IDs
    When match is found it will be added to the CSV file
.PARAMETER BaseUri
    Specifies the cluster target Organization is hosted on. 
.PARAMETER Token
    Specifies the Token on the target organization
.PARAMETER IssuesIds
    Specifies the single Issue ID or Multiple Issue IDs separated by comma ( "issueIDxy,issueIDyxx,issueIDxyxyx") or path to the CSV file containing the list of the Issue IDs (comma separated no headers)
.PARAMETER Results
    Specifies the path to the CSV file in which the results will be stored. NOTE: Results CSV file will be overwritten on each run. Default value: "IssuesIdsMappedToProjects.csv"
.EXAMPLE
    MapIssuesIDsToProjects.ps1 -BaseUri "https://app.brightsec.com" -Token "xxxxx.xxxx.xxxxxxxxxxxxx" -IssuesIds "wxA8gWcdummyx7Pg8mDE" -Results "C:\Users\Support01\Downloads\IssuesIdsMappedToProjects.csv"
.EXAMPLE
    MapIssuesIDsToProjects.ps1 -BaseUri "https://app.brightsec.com" -Token "xxxxx.xxxx.xxxxxxxxxxxxx" -IssuesIds "wxA8gWcdummyx7Pg8mDE,frVpYSmeadummyiUNdC7y" -Results "C:\Users\Support01\Downloads\IssuesIdsMappedToProjects.csv"
.EXAMPLE
    MapIssuesIDsToProjects.ps1 -BaseUri "https://app.brightsec.com" -Token "xxxxx.xxxx.xxxxxxxxxxxxx" -IssuesIds "C:\Users\Support01\Downloads\test.csv"
.NOTES
    Developed by Mahir Mujkanovic @BrightSec.com 19.10.2024 v1.0 
.LINK
    Official guides on how to retrieve tokens:
    https://docs.brightsec.com/docs/manage-your-personal-account#managing-your-personal-api-keys-authentication-tokens
    https://docs.brightsec.com/docs/manage-your-organization#manage-organization-apicli-authentication-tokens
#>


param
(
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$BaseUri="https://app.brightsec.com",
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Token,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$IssuesIds,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][System.IO.FileInfo]$Results="IssuesIdsMappedToProjects.csv"
)
    
###Define Constants
$Limit = 100
$IssuesIdsMappedToProjectsHeader = "issue ID,project ID,issue URL"
   
   
Set-Content -Value $IssuesIdsMappedToProjectsHeader -Path $Results

if($IssuesIds -inotmatch ',' -and $IssuesIds -match '.csv')
{
    if((Test-Path -Path $IssuesIds))
    {
        $ScanIssuesTargetIdsArray = $(Get-Content -Path $IssuesIds).Split(',',[System.StringSplitOptions]::RemoveEmptyEntries)
    }
}
else
{
    $ScanIssuesTargetIdsArray = $IssuesIds -split ','
}

$numOfIssuesIDsMatched=0

$GetAllProjects ="$BaseUri/api/v2/projects?limit=$Limit"

$Headers = @{
    'accept' = 'application/json'
    'Authorization' = "Api-Key $Token"
}

$ScanIssuesFinal =  New-Object System.Collections.Generic.List[System.Object]

# Set projectsOffset for initial query
$projectsOffset = 0

# Query first set of Projects
$listOfProjects = (Invoke-RestMethod -Headers $Headers $($GetAllProjects)).items

while($listOfProjects.Count -gt 0)
{
    foreach($project in $listOfProjects)
    {
        $projectIssues = (Invoke-RestMethod -Headers $Headers $("$BaseUri/api/v2/projects/$($project.id)/issues?limit=$Limit&moveTo=next&certainty=true")).items

        while($projectIssues.Count -gt 0)
        {
            foreach($issue in $projectIssues)
            {
                foreach($targetIssueId in $ScanIssuesTargetIdsArray)
                {
                    if($targetIssueId -ceq $issue.id)
                    {
                        $issueEntry = "$($targetIssueId),$($issue.projectId),$("$BaseUri/projects/$($issue.projectId)/issues/$($issue.id)")"
                        Add-Content -Value $issueEntry -Path $Results
                        $numOfIssuesIDsMatched++
                        if($numOfIssuesIDsMatched -ge $ScanIssuesTargetIdsArray.Count){return}
                    }
                }
            }

                
            $projectIssues = (Invoke-RestMethod -Headers $Headers $("$BaseUri/api/v2/projects/$($project.id)/issues?limit=$Limit&moveTo=next&nextId=$($projectIssues[-1].id)&nextCreatedAt=$($projectIssues[-1].createdAt)&certainty=true")).items
        }
    }
    $projectsOffset += $Limit
    $listOfProjects = (Invoke-RestMethod -Headers $Headers $("$GetAllProjects&offset=$projectsOffset")).items    
}



#[uri]::EscapeDataString("2024-05-13T10:36:46.112Z")
