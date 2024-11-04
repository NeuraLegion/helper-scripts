<#
.SYNOPSIS
    Script can update Authentication Object (AO) on all Entrypoints (EP) in specified Project. 
    It can either Remove the AO or Apply a new one
.DESCRIPTION
    If [-RemoveAo] Switch is active, script will remove AO from all EPs in target Project.
    If [-RemoveAo] Switch is not specified, you must specify [-AoId] (Authentication Object ID) you wish to apply to all EPs in target Project
    By default script will collect and save all Duplicate Entrypoints to DuplicateEpsList.csv file.
    Note: Duplicate EPs cannot be updated - you will have to handle them manually.
.PARAMETER BaseUri
    Specifies the cluster target Organization is hosted on default: "https://app.brightsec.com/"
.PARAMETER Token
    Specifies the Token on the target organization
.PARAMETER Results
    Specifies the path to the CSV file where list of Duplicate EntryPoints found will be stored in. 
    Deafult value is "DuplicateEpsList.csv"
    NOTE: Duplicate EPs CSV file will be overwritten on each run.
    Specified Duplicate EPs path must be only a Filename example: "DuplicateEpsList.csv" or a valid path including the Filename, example: "C:\Users\Support201\DuplicateEpsList.csv""
.EXAMPLE
    UpdateEpAo.ps1 -Token "xxxxx.xxxx.xxxxxxxxxxxxxxxxxx" -ProjectId "xxxxxxxxxxxxxxxxxxxxxx" -RemoveAo
.EXAMPLE
    UpdateEpAo.ps1 -BaseUri "eu.brightsec.com" -Token "xxxxx.xxxx.xxxxxxxxxxxxxxxxxx"  -ProjectId "xxxxxxxxxxxxxxxxxxxxxx" -RemoveAo -DuplicateEps "ListOfDuplicateEpsFound.csv"
.EXAMPLE
    UpdateEpAo.ps1 -Token "xxxxx.xxxx.xxxxxxxxxxxxxxxxxx" -ProjectId "xxxxxxxxxxxxxxxxxxxxxx" -AoId "xxxxxxxxxxxxxxxxxxxxxx" -DuplicateEps "C:\Users\Support201\DuplicateEpsList.csv"
    .EXAMPLE
    UpdateEpAo.ps1 -Token "xxxxx.xxxx.xxxxxxxxxxxxxxxxxx" -ProjectId "xxxxxxxxxxxxxxxxxxxxxx" -AoId "xxxxxxxxxxxxxxxxxxxxxx"
.NOTES
    Developed by Mahir Mujkanovic @BrightSec.com 04.11.2024 v1.0 
.LINK
    Official guides on how to retrieve tokens:
    https://docs.brightsec.com/docs/manage-your-personal-account#managing-your-personal-api-keys-authentication-tokens
    https://docs.brightsec.com/docs/manage-your-organization#manage-organization-apicli-authentication-tokens
#>
param
(
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$BaseUri="https://app.brightsec.com/",
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Token,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProjectId,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$AoId,
    [Parameter(Mandatory=$false)][switch]$RemoveAo,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][System.IO.FileInfo]$DuplicateEps="DuplicateEpsList.csv"
)

# Check the conditions for parameters related to AO
if (-not $RemoveAo -and -not $AoId) 
{
    throw "Either parameter 'RemoveAO' or 'AoId' must be provided."
}

if ($RemoveAo -and $AoId) 
{
    throw "Only one of the parameters 'RemoveAO' or 'AoId' should be provided."
}

# Check conditions for parameter related to the Duplicate EPs CSV file path

$duplicaetEpsPath = $DuplicateEps 

if($duplicaetEpsPath -match '\\' -or $duplicaetEpsPath -match '/' )
{
    if(-not (Test-Path $(Split-Path -Path $duplicaetEpsPath -Parent)))
    {
       throw "Specified Duplicate EPs path ""$duplicaetEpsPath"" does not exist. Please specifiy a full file path, example: ""C:\Users\Support201\DuplicateEpsList.csv""\n ^
        Or remove the '\' or '/' from the DuplicateEps path to indicate only a file name was set"
    }
}

###Define variables
$baseUri = $BaseUri
$token = $Token
$projectId = $ProjectId
if(-not ([string]::IsNullOrEmpty($AoId)))
{
    $aoId = $AoId
}
$removeAo = $RemoveAo

$Limit = 10
$GetAllEntrypointsQry = "$baseUri/api/v2/projects/$projectId/entry-points?limit=$Limit&moveTo=next"

# Prep the headers
[hashtable]$headers=@{}
$headers.Add("accept", "application/json")
$headers.Add("Authorization",  "Api-Key $token")

# Initialize Duplicate EPs list
$DuplicateEpsList =  New-Object System.Collections.Generic.List[System.Object]

# Query first set of Entrypoints
$ListOfEntrypoints = (Invoke-RestMethod -Headers $headers $($GetAllEntrypointsQry)).items | Select-Object -Property id,createdAt

if($RemoveAO)
{ 
    while($ListOfEntrypoints.Count -gt 0)
    {  
        foreach($entrypoint in $ListOfEntrypoints)
        {
            $entrypointObj = (Invoke-WebRequest -Uri "$baseUri/api/v2/projects/$projectId/entry-points/$($entrypoint.id)" -Method Get -Headers $headers).Content | ConvertFrom-Json | Select request,parameters
            # Convert the entrypointObj object to a hashtable
            $entrypointHt = @{}
            foreach ($property in $entrypointObj.PSObject.Properties) 
            {
                $entrypointHt[$property.Name] = $property.Value
            }
  
            $entryPointJson = $entrypointHt | ConvertTo-Json
            
            # Update the target Entrypoint
            try 
            {
                $epUpdateResponse = Invoke-WebRequest -Uri "$baseUri/api/v2/projects/$projectId/entry-points/$($entrypoint.id)" -Method PUT -Body $entryPointJson -Headers $headers -ContentType "application/json"
            }
            catch
            {
                # Check if the error message contains the text indicating duplicate EntryPoint was found
                if($_.Exception -is [System.Net.WebException] -and ($_.Exception.Message -match "The remote server returned an error: \(409\) Conflict" -or $_.Exception.Message -match "Entrypoint already exists with identical parameters")){
                    Write-Warning "Entrypoint already exists with identical parameters. Entrypoint: ""$baseUri/api/v2/projects/$projectId/entry-points/$($entrypoint.id)"""
                    $DuplicateEpsList.Add("$baseUri/api/v2/projects/$projectId/entry-points/$($entrypoint.id),")
                } else {
                    # Handle other types of Exception errors
                    Write-Error "An error occurred: $($_.Exception.Message)"
                }
            }
            
        }
        
        $ListOfEntrypoints = (Invoke-RestMethod -Headers $headers $("$GetAllEntrypointsQry&nextId=$($ListOfEntrypoints[-1].id)&nextCreatedAt=$($ListOfEntrypoints[-1].createdAt)")).items | Select-Object -Property id,createdAt
    }
}else {
    while($ListOfEntrypoints.Count -gt 0)
    {  
        foreach($entrypoint in $ListOfEntrypoints)
        {
            $entrypointObj = (Invoke-WebRequest -Uri "$baseUri/api/v2/projects/$projectId/entry-points/$($entrypoint.id)" -Method Get -Headers $headers).Content | ConvertFrom-Json | Select request,parameters,authObjectId
           
            # Convert the entrypointObj object to a hashtable
            $entrypointHt = @{}
            foreach ($property in $entrypointObj.PSObject.Properties) 
            {
                $entrypointHt[$property.Name] = $property.Value
            }

            # Check if the new AO ID is already applied to the target EP if not add it, otherwise there is no need to update the EP
            if($entrypointHt["authObjectId"] -ne $aoId)
            {
                $entrypointHt["authObjectId"] = $aoId   # Add AO object
                $entryPointJson = $entrypointHt | ConvertTo-Json

                # Update the target Entrypoint
                try 
                {
                    $epUpdateResponse = Invoke-WebRequest -Uri "$baseUri/api/v2/projects/$projectId/entry-points/$($entrypoint.id)" -Method PUT -Body $entryPointJson -Headers $headers -ContentType "application/json"
                }
                catch
                {
                    # Check if the error message contains the text indicating duplicate EntryPoint was found
                    if ($_.Exception -is [System.Net.WebException] -and ($_.Exception.Message -match "The remote server returned an error: \(409\) Conflict" -or $_.Exception.Message -match "Entrypoint already exists with identical parameters"))
                    {
                        Write-Warning "Entrypoint already exists with identical parameters. Entrypoint: ""$baseUri/api/v2/projects/$projectId/entry-points/$($entrypoint.id)"""
                        $DuplicateEpsList.Add("$baseUri/api/v2/projects/$projectId/entry-points/$($entrypoint.id),")
                    }
                    else 
                    {
                        # Handle other types of Exception errors
                        Write-Error "An error occurred: $($_.Exception.Message)"
                    }
                }
            }
        }
        
        $ListOfEntrypoints = (Invoke-RestMethod -Headers $headers $("$GetAllEntrypointsQry&nextId=$($ListOfEntrypoints[-1].id)&nextCreatedAt=$($ListOfEntrypoints[-1].createdAt)")).items | Select-Object -Property id,createdAt
    }
}

# Save found Duplicate EPs
Set-Content -Value $DuplicateEpsList -Path $duplicaetEpsPath






