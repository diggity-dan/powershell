
<#
Help Section
#>

[CmdletBinding()]
  
Param (

[Parameter(Mandatory=$False)]
[string]$UsersRoot = "C:\Users",

[Parameter(Mandatory=$False)]
[string]$IEActiveFilesPath = "AppData\Local\Microsoft\Internet Explorer\Recovery\Active",

[Parameter(Mandatory=$False)]
[string]$IEWebCacheFilesPath = "AppData\Local\Microsoft\Windows\WebCache",

[Parameter(Mandatory=$False)]
[string]$IETempFilesPath = "AppData\Local\Microsoft\Windows\Temporary Internet Files",

[Parameter(Mandatory=$False)]
[string]$LogFile = $null,

[Parameter(Mandatory=$False)]
[string]$MyDirectory = $null

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


#################################################
# Execute Logic:
#################################################

#Make sure we have a logfile:
If(-not $LogFile){
    $LogFile = "$($MyDirectory)\log\Clean-IE_Junk.log"
    Log-Start -LogFile $LogFile -JobName "Clean-IE_Junk.ps1"
}

#Get a list of all folders:
$User_Folders = (Get-ChildItem -Path $UsersRoot -Force | Where-Object {$_.PSIsContainer})
$ResultSet = New-Object System.Collections.ArrayList

#Iterate the list, targeting the temp files:
ForEach($Folder in $User_Folders) {

    #Build paths:
    $FE_IETempFilesPath = "$($UsersRoot)\$($Folder)\$($IETempFilesPath)"
    $FE_IEActiveFilesPath = "$($UsersRoot)\$($Folder)\$($IEActiveFilesPath)"
    $FE_IEWebCacheFilesPath = "$($UsersRoot)\$($Folder)\$($IEWebCacheFilesPath)"
    
    Log-Write -LogFile $LogFile -LineValue "Checking User: $($Folder)"
    Write-Host "Checking User: $($Folder)"
    
    #clean IE temp files:
    If($(Test-Path $FE_IETempFilesPath)) {
        $ResultSet.Add((Remove-Generic -RootPath $FE_IETempFilesPath -FileAge 0 -FileType $null))
        
        Log-Write -LogFile $LogFile -LineValue "`t Temporary Internet Files Cleared."
        Write-Host "`t Temporary Internet Files Cleared."
    }
    
    #clean old IE active recovery files:
    If($(Test-Path $FE_IEActiveFilesPath)) {
        $ResultSet.Add((Remove-Generic -RootPath $FE_IEActiveFilesPath -FileAge 0 -FileType $null))
        
        Log-Write -LogFile $LogFile -LineValue "`t Temporary IE Active Recovery Files Cleared."
        Write-Host "`t Temporary IE Active Recovery Files Cleared."       
    }
    
    #clean old IE webcache files:
    If($(Test-Path $FE_IEWebCacheFilesPath)) {
        $ResultSet.Add((Remove-Generic -RootPath $FE_IEWebCacheFilesPath -FileAge 0 -FileType $null))
        
        Log-Write -LogFile $LogFile -LineValue "`t IE WebCache Files Cleared."
        Write-Host "`t IE WebCache Files Cleared."       
    }
    
    #Reset the folder paths:
    $FE_IETempFilesPath = $null
    $FE_IEActiveFilesPath = $null
    $FE_IEWebCacheFilesPath = $null
    
    Log-Write -LogFile $LogFile -LineValue "`t Done."
    Write-Host "`t Done."
    
} #ForEach Folder in User_Folders

Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host ("-" * 50)

#################################################
# Log results:
#################################################

Log-Write -LogFile $LogFile -LineValue "Clean-IE_Junk.ps1 Results: `r`n"

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
Log-Write -LogFile $LogFile -LineValue "Clean-IE_Junk.ps1 Complete."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)

Write-Host "Clean-IE_Junk.ps1 completed."
Write-Host "`t Full Results in: $LogFile"
Write-Host ("-" * 50)