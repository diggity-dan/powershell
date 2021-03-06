


<#
Help Section

#Add instructions for each script.

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
[string]$UnifiedReport = "False",

[Parameter(Mandatory=$False)]
[string]$DBServer = $null,

[Parameter(Mandatory=$False)]
[string]$DBName = "master",

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

#Get formatted date:
$FormattedDate = (Get-Date -Format "dd-MMM-yyyy")

#Make sure we have a logfile:
If(-not $LogFile){
    $LogFile = "$($MyDirectory)\log\Extractor-CheckDeleteRules-$($FormattedDate).log"
    Log-Start -LogFile $LogFile -JobName "Extractor-CheckDeleteRules.ps1"
}


#Make sure we have a report file:
If(-not $ReportFile){

    $ReportFile = "$($MyDirectory)\reports\$($env:ComputerName)-$($FormattedDate)"
}


#Check for Unified Reporting:
If($UnifiedReport -eq "False"){

    $CurrentReportFile = $($ReportFile) + "-CurrentExtractorRules.csv"
    $MissingReportFile = $($ReportFile) + "-MissingExtractorRules.csv"
    
}
Else {

    $CurrentReportFile = $($ReportFile) + "-LibraryOutput.csv"
    $MissingReportFile = $($ReportFile) + "-LibraryOutput.csv"

}



#################################################
# Get the queries:
#################################################

#Missing Extractor rules:
$ExtractorCurrentRulesFile = "$($MyDirectory)\queries\Get-Extractor-Current-Rules.sql"

#Missing Extractor rules:
$ExtractorMissingRulesFile = "$($MyDirectory)\queries\Get-Extractor-Missing-Rules.sql"

#Extractor:
$ExtractorCurrentRulesQuery = [IO.File]::ReadAllText($ExtractorCurrentRulesFile)
$ExtractorMissingRulesQuery = [IO.File]::ReadAllText($ExtractorMissingRulesFile)

#################################################
# Check for missing extractor rules:
# If there are results, the script should not continue.
#################################################

Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Log-Write -LogFile $LogFile -LineValue "Extractor-CheckDeleteRules.ps1: `r`n"
Log-Write -LogFile $LogFile -LineValue "Querying Extractor for current and missing rules... `r`n"
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host ("-" * 50)
Write-Host "Extractor-CheckDeleteRules.ps1: `r`n"
Write-Host "Querying Extractor for current and missing rules... `r`n"
Write-Host ("-" * 50)

#Results:
$RulesSet = @{}

#Execute:
$RulesSet.Current = (Sql-Select -Server $DBServer -Database $DBName -Query $ExtractorCurrentRulesQuery)
$RulesSet.Missing = (Sql-Select -Server $DBServer -Database $DBName -Query $ExtractorMissingRulesQuery)

#Operate if we have results:
$CurrentRulesCount = ($RulesSet.Current | Measure-Object).Count
$MissingRulesCount = ($RulesSet.Missing | Measure-Object).Count


#Display current rules result:
If($CurrentRulesCount -gt 0){

    Log-Write -LogFile $LogFile -LineValue "`t Current delete rules: `r`n"
    Write-Host "`t Current delete rules: `r`n"
    
    ForEach($Row in $RulesSet.Current){
    
        #Create a new report object for each iteration:
        $ReportObject = @{}
        $ReportObject.Summary = "SourceDirectory: $($Row.SourceDirectory) | SourceFilename: $($Row.SourceFileName) | Threshold: $($Row.Threshold)"
        
        #Call the reporting function:
        #Check if we're in custom mode 1st:
        If($UnifiedReport -eq "False"){
        
            #Separate reporting, add additional properties:
            $ReportObject.Directory = $($Row.SourceDirectory)
            $ReportObject.Extension = $($Row.SourceFileName)
            $ReportObject.Threshold = $($Row.Threshold)
        
            Report-CustomCSV -ScriptName "Extractor-CheckDeleteRules.ps1" -ComputerName $($env:ComputerName) -FileOut $CurrentReportFile -DataObject $ReportObject
        }
        Else {
            Report-CSV -ScriptName "Extractor-CheckDeleteRules.ps1" -ComputerName $($env:ComputerName) -FileOut $CurrentReportFile -DataObject $ReportObject
        } #If/Else UnifiedReport is false

        #Log to file/console:
        Log-Write -LogFile $LogFile -LineValue "`t SourceDirectory: $($Row.SourceDirectory)"
        Log-Write -LogFile $LogFile -LineValue "`t SourceFileName: $($Row.SourceFileName)"
        Log-Write -LogFile $LogFile -LineValue "`t Threshold: $($Row.Threshold) `r`n"
        Write-Host "`t SourceDirectory: $($Row.SourceDirectory)"
        Write-Host "`t SourceFileName: $($Row.SourceFileName) - Threshold: $($Row.Threshold) `r`n"
        
    } #ForEach Row in Current rules
    
     Log-Write -LogFile $LogFile -LineValue ("-" * 50)
     Write-Host ("-" * 50)
}
Else {
    Log-Write -LogFile $LogFile -LineValue "`t No current delete rules found."
    Log-Write -LogFile $LogFile -LineValue ("-" * 50)
    Write-Host "`t No current delete rules found."
    Write-Host ("-" * 50) 
}

#Display missing rules result:
If($MissingRulesCount -gt 0){

    Log-Write -LogFile $LogFile -LineValue "`t Missing the following rules: `r`n"
    Write-Host "`t Logging missing rules. Please be patient... `r`n"
    
    ForEach($Row in $RulesSet.Missing){
    
        #Create a new report object for each iteration:
        $ReportObject = @{}
        $ReportObject.Summary = "DirectoryPath: $($Row.DirectoryPath) | Extension: $($Row.Extension) | ExtensionCount: $($Row.ExtensionCount)"
       
        #Call the reporting function:
        #Check if we're in custom mode 1st:
        If($UnifiedReport -eq "False"){
        
            #Separate reporting, add additional properties:
            $ReportObject.Directory = $($Row.DirectoryPath)
            $ReportObject.Extension = $($Row.Extension)
            $ReportObject.FileCount = $($Row.ExtensionCount)
            
            Report-CustomCSV -ScriptName "Extractor-CheckDeleteRules.ps1" -ComputerName $($env:ComputerName) -FileOut $MissingReportFile -DataObject $ReportObject
        }
        Else {
            Report-CSV -ScriptName "Extractor-CheckDeleteRules.ps1" -ComputerName $($env:ComputerName) -FileOut $MissingReportFile -DataObject $ReportObject
        } #If/Else UnifiedReport is false
        
        #Log to file/console:
        Log-Write -LogFile $LogFile -LineValue "`t DirectoryPath: $($Row.DirectoryPath)"
        Log-Write -LogFile $LogFile -LineValue "`t Extension: $($Row.Extension)"
        Log-Write -LogFile $LogFile -LineValue "`t FileCount: $($Row.ExtensionCount) `r`n"
        
    } #ForEach Row in Missing rules
    
    
    Write-Log "`t Done. `r`n"
    
}
Else {
    Log-Write -LogFile $LogFile -LineValue "`t No missing rules found."
    Write-Host "`t No missing rules found."
}


Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host ("-" * 50)


#################################################
# Finish up:
#################################################

#Finish logging:
Log-Write -LogFile $LogFile -LineValue "Extractor-CheckDeleteRules.ps1 Complete."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)

Write-Host "Extractor-CheckDeleteRules.ps1 Complete."
Write-Host ("-" * 50)