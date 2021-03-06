


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
[int]$FileAge = 7

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

#Log-Utils:
If(-not (Get-Module -Name "log-utils")){
    Import-Module -Name $MyDirectory\..\..\Modules\log-utils.psm1 -DisableNameChecking -Force
}

#File-Utils:
If(-not (Get-Module -Name "file-utils")){
    Import-Module -Name $MyDirectory\..\..\Modules\file-utils.psm1 -DisableNameChecking -Force
}

#Web Administration:
If(-not (Get-Module -Name "WebAdministration")){

    If(Get-Module -ListAvailable -Name "WebAdministration"){
        Import-Module -Name WebAdministration -Force
    }
    Else{
        Write-Host "WebAdministration Module not supported on this server."
        Write-Host "Exiting script."
    }
}


#################################################
# Execute Logic:
#################################################

#Make sure we have a logfile:
If(-not $LogFile){
    $LogFile = "$($MyDirectory)\log\Clean-IIS_Logs.log"
    Log-Start -LogFile $LogFile -JobName "Clean-IIS_Logs.ps1"
}

#Exit if the WebAdministration Module is not loaded:
If(-not(Get-Module -Name "WebAdministration")){

    Log-Write -LogFile $LogFile -LineValue "WebAdministration Module not supported on this server."
    Log-Write -LogFile $LogFile -LineValue "Exiting script."

    Exit
}

#Results:
$ResultSet = New-Object System.Collections.ArrayList

#Iterate the list, targeting the log files:
ForEach($WebSite in $(Get-Website)) {
    $Files_Path = "$($Website.logFile.directory)\w3svc$($website.id)".replace("%SystemDrive%",$env:SystemDrive)
    
    #clean files:
    If($(Test-Path $Files_Path)) {
        $ResultSet.Add((Remove-Generic -RootPath $Files_Path -FileAge $FileAge -FileType "*.log"))
    }
    
}

#################################################
# Log results:
#################################################

Log-Write -LogFile $LogFile -LineValue "Clean-IIS_Logs.ps1 Results: `r`n"


ForEach($Result in $ResultSet){

    ForEach($Item in $Result) {
    
        #Check for data, Remove-Generic returns nothing if no action was taken.
        If($($Item.DirPath)) {
        
            #Formatted ItemSizes:
            $OrigSize = [float]::Parse("{0:N2}" -f (($Item.OrigSizeInB)/1MB))
            $CurrentSize = [float]::Parse("{0:N2}" -f (($Item.SizeInB)/1MB))
            $SizeDiff = [float]::Parse("{0:N2}" -f (($Item.DiffInB)/1MB))
            
            #Write everything to the log:
            Log-Write -LogFile $LogFile -LineValue "Directory: $($Item.DirPath)"
            Log-Write -LogFile $LogFile -LineValue "Total Number of Files: $($Item.NumFiles)"
            Log-Write -LogFile $LogFile -LineValue "Number of Files Deleted: $($Item.NumDeleted)"
            Log-Write -LogFile $LogFile -LineValue "Number of Files Failed: $($Item.NumFailed)"
            Log-Write -LogFile $LogFile -LineValue "Original Size (MB): $($OrigSize)"
            Log-Write -LogFile $LogFile -LineValue "Current Size (MB): $($CurrentSize)"
            Log-Write -LogFile $LogFile -LineValue "Size Difference (MB): $($SizeDiff)"
            
            
            ForEach($Failure in $Item.Failures) {
                Log-Write -LogFile $LogFile -LineValue "File Failed: $($Failure.FilePath)"
                Log-Write -LogFile $LogFile -LineValue "Fail Message: $($Failure.Message)"
            } #For Each Failure
            
            Log-Write -LogFile $LogFile -LineValue ("-" * 50)
            
        }
        Else {
        
            #Do/log nothing since there is no data for this iteration.
            
        } #If/Else $Item.DirPath
    
    } #For Each Item in Result
    
} #For Each Result in ResultSet

Log-Write -LogFile $LogFile -LineValue ("`r`n")
Log-Write -LogFile $LogFile -LineValue "Clean-IIS_Logs.ps1 Complete."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)

Write-Host "Clean-IIS_Logs.ps1 completed."
Write-Host "`t Full Results in: $LogFile"
Write-Host ("-" * 50)