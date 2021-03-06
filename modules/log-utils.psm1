

Function Log-Start {
    <#
    .SYNOPSIS
    Creates a log file and appends data to it.

    .DESCRIPTION
    Creates a log file with supplied path. Checks if log file exists. If so, appends to file. If not, creates a new one.
    Once created, writes initial logging data.

    .PARAMETER LogFile
    Required. Full path of the log file. 
    Ex. "C:\Logs\Jobs_for_20-SEP-2016.log"

    .PARAMETER JobName
    Required. Name of the job to log. 
    Ex. "Important_Report_Query"

    .INPUTS
    This script does not support pipeline inputs.

    .OUTPUTS
    This function returns exceptions to the calling script.    

    .NOTES
    Author: Dan Anderson (danderson@nexidia.com)

    .EXAMPLE
    Log-Start -LogFile "C:\Logs\Jobs_for_20-SEP-2016.log" -JobName "Recent User Activity"
    #>
    
  [CmdletBinding()]
  
  Param (
  [Parameter(Mandatory=$true)]
  [string]$LogFile,
  
  [Parameter(Mandatory=$true)]
  [string]$JobName
  )
  
  Process{
    
    #Check if log exists, if not, create it.
    If(!(Test-Path -Path $LogFile)){
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
    
    Add-Content -Path $LogFile -Value $("*" * 80)
    Add-Content -Path $LogFile -Value "Running Job: [$JobName]"
    Add-Content -Path $LogFile -Value "Started at: [$([DateTime]::Now)]"
    Add-Content -Path $LogFile -Value $("*" * 80)
    Add-Content -Path $LogFile -Value "`r`n"
  
    #Write to screen for debug mode
    Write-Debug $("*" * 80)
    Write-Debug "Running Job: [$JobName]."
    Write-Debug "Started at: [$([DateTime]::Now)]"
    Write-Debug $("*" * 80)
    Write-Debug "`r`n"
    
  } #End Process
  
} #End Function



Function Log-Write {
    <#
    .SYNOPSIS
    Writes a line to the specified file
        
    .DESCRIPTION
    Writes a line to the specified file
        
    .PARAMETER LogFile
    Required. Full path of the log file. 
    Ex. "C:\Logs\Jobs_for_20-SEP-2016.log"
        
    .PARAMETER LineValue
    Required. The string that you want to write to the log
    
    .INPUTS
    This script does not support pipeline inputs.

    .OUTPUTS
    This function returns exceptions to the calling script.
        
    .NOTES
    Author: Dan Anderson (danderson@nexidia.com)
        
    .EXAMPLE
    Log-Write -LogFile "C:\Logs\Jobs_for_20-SEP-2016.log" -LineValue "Something I want to append to the log file."
    #>
  
  [CmdletBinding()]
  
  Param (
  [Parameter(Mandatory=$true)]
  [string]$LogFile, 
  
  [Parameter(Mandatory=$true)]
  [string]$LineValue
  )
  
  Process{
    Add-Content -Path $LogFile -Value $LineValue
  
    #Write to screen for debug mode
    Write-Debug $LineValue
    
  } #End Process
  
} #End Function



Function Log-Error {
    <#
    .SYNOPSIS
    Writes an error to the specified file

    .DESCRIPTION
    Writes an error to the specified file

    .PARAMETER LogFile
    Required. Full path of the log file. 
    Ex. "C:\Logs\Jobs_for_20-SEP-2016.log"

    .PARAMETER ErrorDesc
    Requierd. The description of the error you want to pass. 
    Recommended use: $_.Exception

    .PARAMETER ExitGracefully
    Required. Boolean. If set to $True, runs Log-Finish and then exits.
    Note, ExitGracefully will also end any ForEach, or ForEach-Object loop.
    Default = $False. Options ($True or $False)

    .INPUTS
    This script does not support pipeline inputs.

    .OUTPUTS
    This function returns exceptions to the calling script.

    .NOTES
    Author: Dan Anderson (danderson@nexidia.com)

    .EXAMPLE
    Log-Error -LogFile "C:\Logs\Jobs_for_20-SEP-2016.log" -ErrorDesc $_.Exception -ExitGracefully $False
    #>
  
  [CmdletBinding()]
  
  Param (
  [Parameter(Mandatory=$true)]
  [string]$LogFile,
  
  [Parameter(Mandatory=$true)]
  [string]$ErrorDesc,
  
  [Parameter(Mandatory=$true)]
  [boolean]$ExitGracefully = $False
  )
  
  Process{
    Add-Content -Path $LogFile -Value "$($ErrorDesc)"
  
    #Write to screen for debug mode
    Write-Debug "$($ErrorDesc)"
    
    #If $ExitGracefully = True then run Log-Finish and exit script
    If ($ExitGracefully -eq $True){
      Log-Finish -LogFile $LogFile -Exit $True
      Break
    }
    
  } #End Process
  
} #End Function


Function Log-Finish {
    <#
    .SYNOPSIS
    Write a finished block to a log file.

    .DESCRIPTION
    Write a finished block to a log file.

    .PARAMETER LogFile
    Required. Full path of the log file. 
    Ex. C:\Logs\Jobs_for_20-SEP-2016.log
    
    .PARAMETER JobName
    Required. Message to write.
    Ex. "Important_Report_Query"

    .PARAMETER Exit
    Optional. If this is set to True, then the function will exit the calling application. 
    Note, Exit will also end any ForEach, or ForEach-Object loop.
    Default = $False. Options ($True or $False)

    .INPUTS
    This script does not support pipeline inputs.

    .OUTPUTS
    This function returns exceptions to the calling script.

    .NOTES
    Author: Dan Anderson (danderson@nexidia.com)

    .EXAMPLE
    Log-Finish -LogFile "C:\Windows\Temp\Test_Script.log" -JobName "Important_Report_Query"
    
    .EXAMPLE
    Log-Finish -LogFile "C:\Windows\Temp\Test_Script.log" -JobName "Important_Report_Query" -Exit $True
    #>
  
  [CmdletBinding()]
  
  Param (
  [Parameter(Mandatory=$True)]
  [string]$LogFile,
  
  [Parameter(Mandatory=$True)]
  [string]$JobName,
  
  [Parameter(Mandatory=$False)]
  [string]$Exit = $False
  )
  
  Process{
    Add-Content -Path $LogFile -Value "`r`n"
    Add-Content -Path $LogFile -Value $("*" * 80)
    Add-Content -Path $LogFile -Value "Finished Job: [$($JobName)]"
    Add-Content -Path $LogFile -Value "Ended at: [$([DateTime]::Now)]"
    Add-Content -Path $LogFile -Value $("*" * 80)
    Add-Content -Path $LogFile -Value "`r`n"
  
    #Write to screen for debug mode
    Write-Debug "`r`n"
    Write-Debug $("*" * 80)
    Write-Debug "Finished Job: [$($JobName)]"
    Write-Debug "Ended at: [$([DateTime]::Now)]"
    Write-Debug $("*" * 80)
    Write-Debug "`r`n"
  
    #Exit calling script if Exit is true
    If($Exit -eq $True){
      Exit
    }
        
  } #End Process
  
} #End Function


export-modulemember -function Log-Start, Log-Write, Log-Error, Log-Finish