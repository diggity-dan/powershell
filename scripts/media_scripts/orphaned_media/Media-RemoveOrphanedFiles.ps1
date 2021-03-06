


<#
Help Section (todo)

Author: Dan Anderson
#>



[CmdletBinding()]
  
Param (

[Parameter(Mandatory=$False)]
[string]$LogFile = $null,

[Parameter(Mandatory=$False)]
[string]$MyDirectory = $null,

[Parameter(Mandatory=$False)]
[string]$ReportFile = $null,

[Parameter(Mandatory=$False)]
[string]$MediaRoot = $null,

[Parameter(Mandatory=$False)]
[string]$ExtractorRulesCheck = "True",

[Parameter(Mandatory=$False)]
[string]$DeleteMode = "False",

[Parameter(Mandatory=$False)]
[string]$UseExtractor = "True",

[Parameter(Mandatory=$False)]
[string]$UseNIA = "True",

[Parameter(Mandatory=$False)]
[string]$DBServer = $null,

[Parameter(Mandatory=$False)]
[string]$DBName = $null,

[Parameter(Mandatory=$False)]
[string]$UserName = $null,

[Parameter(Mandatory=$False)]
[string]$Password = $null

) 


#################################################
# Import required modules:
#################################################

#Check for a directory context:
If(-not $MyDirectory){

    $MyDirectory = (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)

    #For running in the ISE - $MyInvocation works only from command line:
    If($psISE.CurrentFile.FullPath.Length -gt 0){
        $MyDirectory = (Split-Path -Parent -Path $psISE.CurrentFile.FullPath)
    }

}

#log-utils:
If(-not (Get-Module -Name "log-utils")){
    Import-Module -Name $MyDirectory\..\..\..\modules\log-utils.psm1 -DisableNameChecking -Force
}

#sql-utils:
If(-not (Get-Module -Name "sql-utils")){
    Import-Module -Name $MyDirectory\..\..\..\modules\sql-utils.psm1 -DisableNameChecking -Force
}

#report-utils:
If(-not (Get-Module -Name "report-utils")){
    Import-Module -Name $MyDirectory\..\..\..\modules\report-utils.psm1 -DisableNameChecking -Force
}


#Make sure we have a logfile:
If(-not $LogFile){
    $LogFile = "$($MyDirectory)\log\Media-RemoveOrphanedFiles.log"
    Log-Start -LogFile $LogFile -JobName "Media-RemoveOrphanedFiles.ps1"
}


#################################################
# Get the queries:
#################################################

#Extractor rules:
$ExtractorCurrentRulesFile = "$($MyDirectory)\queries\Get-Extractor-Current-Rules.sql"
$ExtractorMissingRulesFile = "$($MyDirectory)\queries\Get-Extractor-Missing-Rules.sql"

#Retention settings:
$NIARetentionFile = "$($MyDirectory)\queries\Get-NIA-Retention.sql"
$ExtractorRetentionFile = "$($MyDirectory)\queries\Get-Extractor-Retention.sql"

#Exclusion list:
$NIAExclusionFile = "$($MyDirectory)\queries\Get-NIA-Exclusions.sql"
$ExtractorExclusionFile = "$($MyDirectory)\queries\Get-Extractor-Exclusions.sql"

#NIA Queries:
$NIARetentionQuery = [IO.File]::ReadAllText($NIARetentionFile)
$NIAExclusionQuery = [IO.File]::ReadAllText($NIAExclusionFile)

#Extractor Queries:
$ExtractorCurrentRulesQuery = [IO.File]::ReadAllText($ExtractorCurrentRulesFile)
$ExtractorMissingRulesQuery = [IO.File]::ReadAllText($ExtractorMissingRulesFile)
$ExtractorRetentionQuery = [IO.File]::ReadAllText($ExtractorRetentionFile)
$ExtractorExclusionQuery = [IO.File]::ReadAllText($ExtractorExclusionFile)


Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Log-Write -LogFile $LogFile -LineValue "Media-RemoveOrphanedFiles.ps1: `r`n"
Write-Host ("-" * 50)
Write-Host "Media-RemoveOrphanedFiles.ps1: `r`n"

#################################################
# Check for missing extractor rules:
# Default for ExtractorCheck is True.
# If script detects missing rules, it will exit. 
#################################################

If($ExtractorRulesCheck -eq "True") {

    Log-Write -LogFile $LogFile -LineValue "Querying Extractor for current and missing rules... `r`n"
    Write-Host "Querying Extractor for current and missing rules... `r`n"

    #Results:
    $MissingRulesSet = @{}

    #Execute:
    $MissingRulesSet.Current = (Sql-Select -Server $DBServer -Database $DBName -Query $ExtractorCurrentRulesQuery)
    $MissingRulesSet.Missing = (Sql-Select -Server $DBServer -Database $DBName -Query $ExtractorMissingRulesQuery)

    $CurrentRulesCount = ($MissingRulesSet.Current | Measure-Object).Count
    $MissingRulesCount = ($MissingRulesSet.Missing | Measure-Object).Count

    #Display current rules result:
    If($CurrentRulesCount -gt 0){

        Log-Write -LogFile $LogFile -LineValue "`t Current delete rules: `r`n"
        Write-Host "`t Current delete rules: `r`n"

        ForEach($Row in $MissingRulesSet.Current){
            Log-Write -LogFile $LogFile -LineValue "`t SourceDirectory: $($Row.SourceDirectory)"
            Log-Write -LogFile $LogFile -LineValue "`t SourceFileName: $($Row.SourceFileName) - Threshold: $($Row.Threshold) `r`n"
            Write-Host "`t SourceDirectory: $($Row.SourceDirectory)"
            Write-Host "`t SourceFileName: $($Row.SourceFileName) - Threshold: $($Row.Threshold) `r`n"
        } #ForEach Row in Current rules
        
         Log-Write -LogFile $LogFile -LineValue ("-" * 50)
         Write-Host ("-" * 50)
    }
    Else {
        Log-Write -LogFile $LogFile -LineValue "`t No current delete rules found."
        Write-Host "`t No current delete rules found."
        
    }#If CurrentRulesCount > 0
    

    #Display missing rules result:
    If($MissingRulesCount -gt 0){

        Log-Write -LogFile $LogFile -LineValue "`t Missing the following rules: `r`n"
        Write-Host "`t Missing the following rules: `r`n"

        ForEach($Row in $MissingRulesSet.Missing){
            Log-Write -LogFile $LogFile -LineValue "`t Extension: $($Row.Extension) - FileCount: $($Row.ExtensionCount)"
            Write-Host "`t Extension: $($Row.Extension) - FileCount: $($Row.ExtensionCount)"
        } #ForEach Row in Missing rules
        
        Log-Write -LogFile $LogFile -LineValue "`r`nExtractor delete rules for the above must be implemented before script can execute. Exiting.`r`n"
        Log-Write -LogFile $LogFile -LineValue ("-" * 50)
        Write-Host "`r`nExtractor delete rules for the above must be implemented before script can execute. Exiting.`r`n"
        Write-Host ("-" * 50)
        
        #Exit script:
        Exit
        
    }
    Else {
        Log-Write -LogFile $LogFile -LineValue "`t No missing rules found."
        Write-Host "`t No missing rules found."
    } #If MissingRulesCount > 0
    
    
    
    Log-Write -LogFile $LogFile -LineValue ("-" * 50)
    Write-Host ("-" * 50)

} #If ExtractorCheck = True



#################################################
#Exit if media root does not exist:
#################################################

#Validate Media Root:

If(-not(Test-Path $MediaRoot)){
    Log-Write -LogFile $LogFile -LineValue "Media Path: $($MediaRoot)"
    Log-Write -LogFile $LogFile -LineValue "Does not exist. Exiting Script."
    Log-Write -LogFile $LogFile -LineValue ("-" * 50)
    
    Write-Host "Media Path: $($MediaRoot)"
    Write-Host "Does not exist. Exiting Script."
    Write-Host ("-" * 50)
    
    Exit
}

#################################################
#Exit if UseNIA and UseExtractor are both false:
#################################################


If( ($UseNIA -eq "False") -and ($UseExtractor -eq "False") ){
    Log-Write -LogFile $LogFile -LineValue "Not checking NIA or Extractor. No need to continue."
    Log-Write -LogFile $LogFile -LineValue "Exiting Script."
    Log-Write -LogFile $LogFile -LineValue ("-" * 50)
    
    Write-Host "Not checking NIA or Extractor. No need to continue."
    Write-Host "Exiting Script."
    Write-Host ("-" * 50)
    
    Exit
}

#################################################
# Get NIA Retention Settings List:
#################################################

#Grab data from NIA if desired:
If($UseNIA -eq "True") {

    Log-Write -LogFile $LogFile -LineValue "Querying NIA for retention settings... `r`n"
    Write-Host "Querying NIA for retention settings... `r`n"

    #Results:
    $NIARetentionSet = @{}

    #Execute:
    $NIARetentionSet.Settings = (Sql-Select -Server $DBServer -Database $DBName -Query $NIARetentionQuery)

    #Fill Retention Settings
    $NIAMediaCutoff = ($NIARetentionSet.Settings.MediaCutoff)
    $NIADataCutoff = ($NIARetentionSet.Settings.DataCutoff)
    $NIAMediaTypeList = ($NIARetentionSet.Settings.MediaTypeList) -Split ','

    #Convert MediaFileType list into usable filter:
    $NIAIncludeList = $NIAMediaTypeList | % { "*.$($_)" }

    Log-Write -LogFile $LogFile -LineValue "`t Done."
    Log-Write -LogFile $LogFile -LineValue ("-" * 50)
    Write-Host "`t Done."
    Write-Host ("-" * 50)

}

#################################################
# Get Extractor Retention Settings List:
#################################################

#Grab data from Extractor if desired:
If($UseExtractor -eq "True") {

    Log-Write -LogFile $LogFile -LineValue "Querying Extractor for retention settings... `r`n"
    Write-Host "Querying Extractor for retention settings... `r`n"

    #Results:
    $ExtractorRetentionSet = @{}

    #Execute:
    $ExtractorRetentionSet.Settings = (Sql-Select -Server $DBServer -Database $DBName -Query $ExtractorRetentionQuery)

    Log-Write -LogFile $LogFile -LineValue "`t Done."
    Log-Write -LogFile $LogFile -LineValue ("-" * 50)
    Write-Host "`t Done."
    Write-Host ("-" * 50)

}

#################################################
#Gather all the folders:
#################################################

Log-Write -LogFile $LogFile -LineValue "Building file system directory structure ..."
Write-Host "Building file system directory structure ..."
Write-Host "This can take a while. Please be patient ..."

$AllFolders = Get-ChildItem -Path $MediaRoot -Recurse -Force -ErrorAction SilentlyContinue `
| Where-Object { $_.PSIsContainer -and @(Get-ChildItem $_.Fullname | Where {-not $_.PSIsContainer}).Length -gt 0 } ` 
| Select-Object -Property FullName

#Count Folders:
$AllFoldersCount = ($AllFolders | Measure-Object).Count

#Execute for $MediaRoot if no subfolders exist:
If($AllFoldersCount -eq 0){

    $AllFolders = @{ FullName = $($MediaRoot) } 
}


#Log Stuff:
Log-Write -LogFile $LogFile -LineValue "`t Found $($AllFoldersCount) folders to check."
Log-Write -LogFile $LogFile -LineValue "`t Done."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host "`t Found $($AllFoldersCount) folders to check."
Write-Host "`t Done."
Write-Host ("-" * 50)

#################################################
#Execute Folder by Folder:
#################################################

#SummaryStats:
$TotalFiles = 0
$TotalCriteriaNotMet = 0
$TotalRemoved = 0
$TotalSkipped = 0
$TotalFailed = 0

#Start iteration:
ForEach($Folder in $AllFolders) {

    #Cache the folder.fullname so PS doesn't need to expand
    #it over and over:
    $FolderFullName = ($Folder.FullName)

    Log-Write -LogFile $LogFile -LineValue "Directory: $($FolderFullName) `r`n"
    Write-Host "Directory: $($FolderFullName) `r`n"
        
    #################################################
    #Get list of files:
    #################################################
    
    Log-Write -LogFile $LogFile -LineValue "Gathering file system details..."
    Write-Host "Gathering file system details..."
    
    #Get list of all files in current folder:
    $CompleteCollection = Get-ChildItem -Path $FolderFullName -Force -ErrorAction SilentlyContinue | `
                          Where-Object { (-not $_.PSIsContainer) } | `
                          Select-Object -Property LastWriteTime, FullName, DirectoryName, BaseName, Extension
           
    #Count current items found:
    $CurrentCount = ($CompleteCollection | Measure-Object).Count
    
    #Add file count to summary:
    $TotalFiles += $CurrentCount
    
    #Log Stuff:
    Log-Write -LogFile $LogFile -LineValue "`t Found $($CurrentCount) files to check. `r`n"
    Write-Host "`t Found $($CurrentCount) files to check. `r`n"
       
    #################################################
    #Check files:
    #################################################
    
    
    #Only Run if there are files in the collection:
    If($CurrentCount -gt 0) {
    
    
        #################################################
        #Build Exclusion Lists for this folder:
        #################################################
        
        Log-Write -LogFile $LogFile -LineValue "Getting NIA and Extractor Exclusions..."
        Write-Host "Getting NIA and Extractor Exclusions..."
        
        
        #Build Exclusion Lists:
        #NIA:
        If($UseNIA -eq "True"){
            #Pass the Current $MediaRoot into the exclusion queries:
            $NIACurrentExclusions = $NIAExclusionQuery.Replace("{{MEDIAROOT}}", $FolderFullName)
            
            #Execute:
            $NIARetentionSet.Exclusions = (Sql-Select -Server $DBServer -Database $DBName -Query $NIACurrentExclusions)
            
            #Get count of exclusions:
            $NIAExclusionCount = ($NIARetentionSet.Exclusions | Measure-Object).Count
            
            Log-Write -LogFile $LogFile -LineValue "`t Found $($NIAExclusionCount) NIA Exclusions."
            Write-Host "`t Found $($NIAExclusionCount) NIA Exclusions."
            
        }
        
        #Extractor:
        If($UseExtractor -eq "True"){
            #Pass the Current $MediaRoot into the exclusion queries:
            $ExtractorCurrentExclusions = $ExtractorExclusionQuery.Replace("{{MEDIAROOT}}", $FolderFullName)
            
            #Execute:
            $ExtractorRetentionSet.Exclusions = (Sql-Select -Server $DBServer -Database $DBName -Query $ExtractorCurrentExclusions)
            
            #Get count of exclusions:
            $ExtractorExclusionCount = ($ExtractorRetentionSet.Exclusions | Measure-Object).Count
            
            Log-Write -LogFile $LogFile -LineValue "`t Found $($ExtractorExclusionCount) Extractor Exclusions. `r`n"
            Write-Host "`t Found $($ExtractorExclusionCount) Extractor Exclusions. `r`n"
            
        }
       
        
        Log-Write -LogFile $LogFile -LineValue "Checking file retention settings..."
        Write-Host "Checking file retention settings..."
        
        #################################################
        #Iterate the file list:
        #################################################
        
        ForEach($File in $CompleteCollection) {
    
            #Cache some properties:
            $FileAge = $File.LastWriteTime
            $FileFullName = $File.FullName
            $FileDirName = $File.DirectoryName
            $FileBaseName = $File.BaseName
            $FileExtension = $File.Extension
    
            #Set some modes:
            $FileIsMedia = $False
            $FoundExceptionMatch = $False
            $FileIsDeleteCandidate = $False
            
            
            #################################################            
            #NIA Rules:
            #################################################
            
            #Ensure we should be checking NIA:
            If($UseNIA -eq "True") {
            
                #Check file properties against retention settings:
                ForEach($Type in $NIAIncludeList) {
                
                    If($FileExtension -Like $Type) {
                        $FileIsMedia = $True
                    }

                } #ForEach Type in NIAIncludeList
                
                
                #NIA Media Cutoff:
                If( ($FileIsMedia) -and ($FileAge -lt $NIAMediaCutoff) ) {
                    $FileIsDeleteCandidate = $True
                } #If FileAge < NIAMediaCutoff
                
                
                #NIA Data Cutoff:
                If( (-not $FileIsMedia) -and ($FileAge -lt $NIADataCutoff) ) {
                    $FileIsDeleteCandidate = $True        
                } #If FileAge < NIADataCutoff
            
            } #If UseNIA = True
            
            #################################################            
            #Extractor Rules:
            #################################################
            
            #Ensure we should be checking Extractor:
            If($UseExtractor -eq "True") {
            
                :ExtractorRetentionLoop
                ForEach($Row in $ExtractorRetentionSet.Settings){
                
                    #Check the directory we're in:
                    If($FileDirName -Like "$($Row.SourceDirectory)"){
                    
                        #Extract the SourceFileName into an array:
                        $ExtractorFileType = ($Row.SourceFileName) -Split ','
                    
                        #Check the file type:
                        $ExtractorFileType | % {
                        
                            #Match the extension:
                            If($FileExtension -Like $_){
                            
                                #Match the threshold:
                                If($FileAge -lt $Row.Cutoff) {

                                    $FileIsDeleteCandidate = $True
                                    Break ExtractorRetentionLoop
                                    
                                } #If FileAge
                                
                            }# If/Else FileExtension
                            Else {
                                Continue
                            }
                            
                        } #ForEach SourceFileName
                    
                    } #If/Else FileDirName
                    Else {
                        Continue
                    }
                
                } #ForEach Row in ExtractorRetentionSet.Settings
            
            } #If UseExtractor = True
            
            #################################################
            #Gate Check:
            #################################################
            
            #If the file has not met criteria gates, move to next file:
            If(-not $FileIsDeleteCandidate){ 
                $TotalCriteriaNotMet ++ 
                Continue 
            }
            
            #################################################            
            #Check NIA Exclusion Lists:
            #################################################           
            
            #Ensure we should be checking NIA:
            If($UseNIA -eq "True") {
            
                #NIA Exclusion List:
                If($FileIsDeleteCandidate -and ($NIAExclusionCount -gt 0) ) {
                    #Iterate NIA retention list:
                    ForEach($Row in $NIARetentionSet.Exclusions) {
                
                        If($Row.ExternalMediaId -Like "$($FileDirName)\$($FileBaseName)*") {
                            
                            #Found a match in the exception list, so don't remove it from the file system:
                            $FoundExceptionMatch = $True
                            
                            Log-Write -LogFile $LogFile -LineValue "Skipping [$($Row.ReasonForKeeping)]: $($FileFullName)"
                            $TotalSkipped ++
                            Break
                            
                        } #If $Row.ExternalMediaId
                        
                    } #ForEach Row in NIARetentionSet
                    
                    #If we found a match, start on a new file:
                    If($FoundExceptionMatch){ Continue }
                    
                } #NIA Exclusion
            
            } #If UseNIA = True
            
            #################################################            
            #Check Extractor Exclusion Lists:
            #################################################
            
            If($UseExtractor -eq "True"){
            
                #Extractor Exclusion List:
                If($FileIsDeleteCandidate -and ($ExtractorExclusionCount -gt 0) ) {
                    #Iterate Extractor retention list:
                    ForEach($Row in $ExtractorRetentionSet.Exclusions) {
                
                        If($Row.FullFilePath -eq "$($FileFullName)") {
                            
                            #Found a match in the exception list, so don't remove it from the file system:
                            $FoundExceptionMatch = $True
                            
                            Log-Write -LogFile $LogFile -LineValue "Skipping [$($Row.ReasonForKeeping)]: $($FileFullName)"
                            $TotalSkipped ++
                            Break
                        
                        } #If $Row.FullFilePath
                        
                    } #ForEach Row in ExtractorRetentionSet
                    
                    #If we found a match, start on a new file:
                    If($FoundExceptionMatch){ Continue }
                
                } #Extractor Exclusion
                   
            } #If UseExtractor = True
        
            #################################################
            #Remove file:
            #################################################           
        
            #Checked all exception lists.         
            If($FileIsDeleteCandidate -and (-not $FoundExceptionMatch) ) {
        
                Log-Write -LogFile $LogFile -LineValue "Removing: $($FileFullName)"   
            
                If($DeleteMode -eq "True") {
            
                    Try {
                        Remove-Item -Path $FileFullName -Force -ErrorAction Stop
                        $TotalRemoved ++
                    }
                    Catch {
                        Log-Write -LogFile $LogFile -LineValue "Error: $($_.Exception.Message)"
                        $TotalFailed ++           
                    }
            
                } #If DeleteMode is true
            
            } #If CanDelete is true
                     
    
        #######################################
        } # END ForEach File in CompleteCollection
        #######################################


    }# If CurrentCount > 0

    #Log Stuff:
            
    Log-Write -LogFile $LogFile -LineValue "Done."
    Log-Write -LogFile $LogFile -LineValue ("-" * 50)
    Write-Host "Done.`r`n"
    Write-Host "Actions for this directory have been logged."
    Write-Host ("-" * 50)
    
    #Release some memory:
    $CompleteCollection = $null
    [GC]::Collect()
    Start-Sleep -Milliseconds 5
    

#################################################
} # END FOR EACH FOLDER IN ALLFOLDERS
#################################################


#################################################
# Finish up:
#################################################

#Create Summary object for reporting:
$ReportObject = @{}
$ReportObject.TotalFiles = ($TotalFiles)
$ReportObject.TotalCriteriaNotMet = ($TotalCriteriaNotMet)
$ReportObject.TotalRemoved = ($TotalRemoved)
$ReportObject.TotalSkipped = ($TotalSkipped)
$ReportObject.TotalFailed = ($TotalFailed)

#Make sure we have a file name and directory:
If(-not $ReportFile){
    $FormattedDate = (Get-Date -Format "dd-MMM-yyyy")
    $ReportFile = "$($MyDirectory)\reports\$($env:ComputerName)-$($FormattedDate)-LibraryOutput.csv"
}

#Call the reporting function:
Report-CSV -ScriptName "Media-RemoveOrphanedFiles.ps1" -ComputerName $($env:ComputerName) -FileOut $ReportFile -DataObject $ReportObject

#Log the data:
Log-Write -LogFile $LogFile -LineValue "Total Files Examined: $($TotalFiles)"
Log-Write -LogFile $LogFile -LineValue "Total Files Criteria Not Met: $($TotalCriteriaNotMet)"
Log-Write -LogFile $LogFile -LineValue "Total Files Removed: $($TotalRemoved)"
Log-Write -LogFile $LogFile -LineValue "Total Files Skipped: $($TotalSkipped)"
Log-Write -LogFile $LogFile -LineValue "Total Files Failed: $($TotalFailed) `r`n"
Log-Write -LogFile $LogFile -LineValue "Media-RemoveOrphanedFiles.ps1 Complete."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)

Write-Host "Total Files Examined: $($TotalFiles)"
Write-Host "Total Files Criteria Not Met: $($TotalCriteriaNotMet)"
Write-Host "Total Files Removed: $($TotalRemoved)"
Write-Host "Total Files Skipped: $($TotalSkipped)"
Write-Host "Total Files Failed: $($TotalFailed) `r`n"
Write-Host "Full details recorded in: $($LogFile) `r`n"
Write-Host "Media-RemoveOrphanedFiles.ps1 Complete."
Write-Host ("-" * 50)
