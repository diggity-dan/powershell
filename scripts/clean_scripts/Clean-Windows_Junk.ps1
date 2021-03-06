
<#
Help Section
#>

[CmdletBinding()]
  
Param (

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
    $LogFile = "$($MyDirectory)\log\Clean-IE_Active.log"
    Log-Start -LogFile $LogFile -JobName "Clean-IE_Active.ps1"
}


#Store results:
$ResultSet = New-Object System.Collections.ArrayList


######################################################
#Clean All Recycle Bins:
######################################################

Log-Write -LogFile $LogFile -LineValue "Cleaning Recycle Bins..."
Write-Host "Cleaning Recycle Bins..."

$RecycleDriveList = (Get-PSDrive -PSProvider FileSystem | % {"$($_.Root)$('$recycle.bin')"})
ForEach($Bin in $RecycleDriveList){

    #Ensure the drive has a <drive>:\$recycle.bin:
    If($(Test-Path $Bin)){

        #Get a list of all folders in the recycle bin:
        $Bin_Folders = (Get-ChildItem -Path $Bin -Force | Where-Object {$_.PSIsContainer})
       
        #Iterate the recycle bin list:
        ForEach($Folder in $Bin_Folders) {
            
            #clean files:
            If($(Test-Path $Folder.FullName)) {
                $ResultSet.Add((Remove-Generic -RootPath $Folder.FullName -FileAge 0 -FileType $null)) | Out-Null
            }
            
        } #ForEach $Folder in $Bin_Folders
    
    } #If recycle.bin exists

} #ForEach $Bin in $RecycleDriveList

Log-Write -LogFile $LogFile -LineValue "Done."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host "Done."
Write-Host ("-" * 50)

######################################################
#Check for large System Volume Information Folders:
######################################################

Log-Write -LogFile $LogFile -LineValue "Checking System Volume Information...`r`n"
Write-Host "Checking System Volume Information...`r`n"

$VolumeDriveList = (Get-PSDrive -PSProvider FileSystem | % {"$($_.Root)$('System Volume Information')"})

ForEach($Volume in $VolumeDriveList){

    #Ensure the drive has a <drive>:\System Volume Information folder:
    If($(Test-Path $Volume)){

        $VolumeHash = @{}
        $VolumeHash.Drive = $Volume
        $VolumeHash.TotalSize = 0
           
        #Add to hash:
        $VolumeHash.VolumeInfo = (Get-ChildItem -Path $Volume -Force -Recurse -ErrorAction SilentlyContinue | Where-Object {(-not $_.PSIsContainer)})
        
        If(($VolumeHash.VolumeInfo | Measure-Object).Count -gt 0) {
        
            #Get total size of all objects:
            ForEach($File in $VolumeHash.VolumeInfo){

                $VolumeHash.TotalSize += $File.Length
                        
            } #ForEach File in VolumeHash
        
        
        } #If VolumeHash.VolumeInfo > 0


        #Formatted ItemSizes:
        $TotalSize = [float]::Parse("{0:N2}" -f (($VolumeHash.TotalSize)/1MB))
        
        Log-Write -LogFile $LogFile -LineValue "`t Drive: $($VolumeHash.Drive)"
        Log-Write -LogFile $LogFile -LineValue "`t File Size (MB): $($TotalSize)"
        Log-Write -LogFile $LogFile -LineValue "`r`n"
        Write-Host "`t Drive: $($VolumeHash.Drive)"
        Write-Host "`t File Size (MB): $($TotalSize)"
        Write-Host "`r`n"

        #Reset the hash:
        $VolumeHash = @{}
            
    } #If volume exists

} #ForEach $Volume in $VolumeDriveList  


Log-Write -LogFile $LogFile -LineValue "Done."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host "If these directories are large, inform IT to have space cleared."
Write-Host "There are critical operating system files mixed in with junk, it's not safe to delete everything."
Write-Host "Done."
Write-Host ("-" * 50)

######################################################
# Prompt the clean manager, create a sage set:
######################################################



#Prompt for creating a sageset and open disk cleanup:
If( (-not $psISE) ){

    Try{
        
        (& CleanMgr /sageset:5000)
        
        Log-Write -LogFile $LogFile -LineValue "Launching Advanced Cleanup..."
        Write-Host "Launching Advanced Cleanup..."
        Write-Host "`t Please choose the options to run, then press any key to continue script."   
        
        [void]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
        
    }
    Catch {
    
        Write-Host "`t Disk Cleanup is not enabled on this server. Please inform IT."
    }
    
} Else {

    Try{
        
        (& CleanMgr /sageset:5000)
        Write-Host "`t Please choose the options to run, then press any key to continue script."       
        [void](Read-Host 'Press Enter or Click OK to continue.')
        
    }
    Catch {
    
        Write-Host "`t Disk Cleanup is not enabled on this server. Please inform IT."
    }
    
    
} #If/Else not $psISE


Try{

    (& CleanMgr /sagerun:5000)
    Log-Write -LogFile $LogFile -LineValue "`t Executing Advanced Disk Cleanup."
    Log-Write -LogFile $LogFile -LineValue "`t Please allow disk cleanup to finish executing. This may take a few minutes."
    Write-Host "`t Executing Advanced Disk Cleanup."
    Write-Host "`t Please allow disk cleanup to finish executing. This may take a few minutes."
    
}
Catch {

    Write-Host "`t Disk Cleanup is not enabled on this server. Please inform IT."
}

Log-Write -LogFile $LogFile -LineValue "Done."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host "Done."
Write-Host ("-" * 50)

#################################################
# Log results:
#################################################

Log-Write -LogFile $LogFile -LineValue "Clean-IE_Active.ps1 Results: `r`n"


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
            Log-Write -LogFile $LogFile -LineValue "Delete Mode: $($Item.DeleteMode)"
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
Log-Write -LogFile $LogFile -LineValue "Clean-IE_Active.ps1 Complete."
Log-Write -LogFile $LogFile -LineValue ("-" * 50)

Write-Host "Clean-IE_Active.ps1 completed."
Write-Host "`t Full Results in: $LogFile"
Write-Host ("-" * 50)