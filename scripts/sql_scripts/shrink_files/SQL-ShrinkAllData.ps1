


<#
Help Section
#>



[CmdletBinding()]
  
Param (

[Parameter(Mandatory=$False)]
[string]$LogFile = $null,

[Parameter(Mandatory=$False)]
[string]$MyDirectory = $null,

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
    Import-Module -Name $MyDirectory\..\..\..\Modules\log-utils.psm1 -DisableNameChecking -Force
}


#sql-utils:
If(-not (Get-Module -Name "sql-utils")){
    Import-Module -Name $MyDirectory\..\..\..\Modules\sql-utils.psm1 -DisableNameChecking -Force
}


#################################################
# Get the query:
#################################################

#Get Files:
$RecoveryModelFile = "$($MyDirectory)\queries\SQL-CorrectRecoveryModel.sql"
$ShrinkDataFile = "$($MyDirectory)\queries\SQL-ShrinkAllData.sql"

#Get Queries
$RecoveryModelQuery = [IO.File]::ReadAllText($RecoveryModelFile)
$ShrinkDataQuery = [IO.File]::ReadAllText($ShrinkDataFile)

#################################################
# Run the queries:
#################################################

#Make sure we have a logfile:
If(-not $LogFile){
    $LogFile = "$($MyDirectory)\log\SQL-ShrinkAllData.log"
    Log-Start -LogFile $LogFile -JobName "SQL-ShrinkAllData.ps1"
}

Log-Write -LogFile $LogFile -LineValue "SQL-ShrinkAllData.ps1: `r`n"
Log-Write -LogFile $LogFile -LineValue "Gathering database details:"
Write-Host "SQL-ShrinkAllData.ps1: `r`n"
Write-Host "Gathering database details:"


#Results:
$DetailsResultSet = @{}

#Execute:
$DetailsResultSet.RecoverySettings = (Sql-Select -Server $DBServer -Database $DBName -Query $RecoveryModelQuery)
$DetailsResultSet.ShrinkDataSettings = (Sql-Select -Server $DBServer -Database $DBName -Query $ShrinkDataQuery)

#Get count:
$RecoverySettingsCount = ($DetailsResultSet.RecoverySettings | Measure-Object).Count
$ShrinkDataCount = ($DetailsResultSet.ShrinkDataSettings | Measure-Object).Count

#More Logging:
Log-Write -LogFile $LogFile -LineValue "`t Done."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host "`t Done."
Write-Host ("-" * 50)


#################################################
#Work with result set (Recovery Mode):
#################################################

#Results:
$RecoveryHash = @{}

Log-Write -LogFile $LogFile -LineValue "Checking recovery mode: `r`n"
Write-Host "Checking recovery mode: `r`n"

#If we have databases to work with:
If($RecoverySettingsCount -gt 0){

    #Iterate Results:
    ForEach($Row in $DetailsResultSet.RecoverySettings){

        #Get DBServer:
        $DBServer = $($Row.ServerName)
        
        #Get DBName:
        $DBName = $($Row.DatabaseName)
        
        #Get Query:
        $Query = $($Row.RecoveryCommand)
        
        #Log what's happening:
        Log-Write -LogFile $LogFile -LineValue "`t Setting Simple Recovery for: $($DBServer)\$($DBName) ..."
        Write-Host "`t Setting Simple Recovery for: $($DBServer)\$($DBName) ..."
        
        #Execute:
        $RecoveryHash.Result = (Sql-Select -Server $DBServer -Database $DBName -Query $Query)
        
        #TestResult:
        If($RecoveryHash.Result){
        Write-Host "`t Error: $($RecoveryHash.Result)"
        }
        
        #Reset for next iteration:
        $RecoveryHash = @{}
        
        Log-Write -LogFile $LogFile -LineValue "`t Done."
        Write-Host "`t Done."
        
    } #ForEach Row in RecoverySettings
    
}
Else {

    Log-Write -LogFile $LogFile -LineValue "`t All databases are set to simple recovery."
    Write-Host "`t All databases are set to simple recovery."
    
}

Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host ("-" * 50)


#################################################
#Work with result set (Shrink Data):
#################################################

#Results:
$ShrinkResultSet = New-Object System.Collections.ArrayList
$ShrinkHash = @{}

Log-Write -LogFile $LogFile -LineValue "Shrinking data files: `r`n"
Write-Host "Shrinking data files: `r`n"

#If we have logs to shrink:
If($ShrinkDataCount -gt 0){

    #Iterate Results:
    ForEach($Row in $DetailsResultSet.ShrinkDataSettings){
    
        #Get DBServer:
        $DBServer = $($Row.ServerName)
        
        #Get DBName:
        $DBName = $($Row.DatabaseName)
        
        #Get Logical Name:
        $LogicalFileName = $($Row.LogicalName)
        
        #Get Original Size:
        $OriginalSizeMB = [float]::Parse("{0:N2}" -f ( $($Row.FileSizeKB) / 1024) )
                
        #Get Query:
        $Query = $($Row.ShrinkCommand)
        
        #Log what's happening:
        Log-Write -LogFile $LogFile -LineValue "`t Shrinking: $($DBServer)\$($DBName)\$($LogicalFileName)..."
        Write-Host "`t Shrinking: $($DBServer)\$($DBName)\$($LogicalFileName):" 
        Write-Host "`t This may take a while. Please be patient... `r`n"
        
        #Execute:
        $ShrinkHash.Result = (Sql-Select -Server $DBServer -Database $DBName -Query $Query)
        
        #Size returned is number of 8KB pages used.
        $SizeInMB = [float]::Parse("{0:N2}" -f ( ($($ShrinkHash.Result.CurrentSize) * 8 ) / 1024) )
        
        #Get Size Difference:
        $SizeDiff = [float]::Parse("{0:N2}" -f $("$($OriginalSizeMB)" - "$($SizeInMB)") )
                
        Log-Write -LogFile $LogFile -LineValue "`t Size Before Shrink: $OriginalSizeMB MB"
        Log-Write -LogFile $LogFile -LineValue "`t Size After Shrink: $SizeInMB MB"
        Log-Write -LogFile $LogFile -LineValue "`t Net Change: $($SizeDiff) MB `r`n"
        Write-Host "`t Size Before Shrink: $OriginalSizeMB MB"
        Write-Host "`t Size After Shrink: $SizeInMB MB"
        Write-Host "`t Net Change: $($SizeDiff) MB `r`n"
        
        #Reset for next iteration:
        $ShrinkHash = @{}
        
    } #ForEach Row in ShrinkLogSettings
    
}
Else {
    Log-Write -LogFile $LogFile -LineValue "`t No data files to shrink."
    Write-Host "`t No data files to shrink."
}

Log-Write -LogFile $LogFile -LineValue "`t Done."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host "`t Done."
Write-Host ("-" * 50)


#################################################
# Finish Up:
#################################################


Log-Write -LogFile $LogFile -LineValue "SQL-ShrinkAllData.ps1 Complete."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host "SQL-ShrinkAllData.ps1 Complete."
Write-Host ("-" * 50)
