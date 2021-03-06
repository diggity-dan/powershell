<#
Help section.

All scripts must accept LogFile parameter.
All scripts must accept MyDirectory parameter.
#>


[CmdletBinding()]
  
Param (

[Parameter(Mandatory=$False)]
[string]$ConfigFile = $null,

[Parameter(Mandatory=$False)]
[string]$LogFile = $null,

[Parameter(Mandatory=$False)]
[string]$ScriptDir = $null,

[Parameter(Mandatory=$False)]
[string]$ModuleDir = $null,

[Parameter(Mandatory=$False)]
[string]$Unattended = "False",

[Parameter(Mandatory=$False)]
[string]$ScriptFile = $null,

[Parameter(Mandatory=$False)]
[int]$LogDays = 5

) 


#################################################
# Get relative path for execution/loading modules:
#################################################

$ThisScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)

#For running in the ISE - $MyInvocation works only from command line:
If($psISE.CurrentFile.FullPath.Length -gt 0){
    $ThisScriptPath = (Split-Path -Parent -Path $psISE.CurrentFile.FullPath)
}

#If params are null, load defaults using relative paths.
If(-not $ConfigFile){
    $ConfigFile = $ThisScriptPath + "\config\script.config"
}

If(-not $ModuleDir) {
    $ModuleDir = $ThisScriptPath + "\modules"
}

If(-not $ScriptDir){
    $ScriptDir = $ThisScriptPath + "\scripts"
}

Clear-Host
Write-Host ("-" * 50)

#################################################
# Import all modules:
#################################################

$ModuleList = (Get-ChildItem -Path $ModuleDir -Filter "*.psm1" -Recurse -Force)

ForEach($Module in $ModuleList) {
    Import-Module -Name $Module.FullName -DisableNameChecking -Force
}

###################################################
#Read config:
###################################################

#Get config:
If(-not(Test-Path $ConfigFile)){
   
    Write-Host "Script configuration file not found. Check the path:"
    Write-Host "`t $($ConfigFile)"
    Write-Host "`t Exiting Application in 10 seconds."
    Write-Host ("-" * 50)
    
    Start-Sleep -Seconds 10
    Exit

} Else {

    #Set Default Config Tokens:
    
    #Read in file
    $TempFile = [IO.File]::ReadAllText($ConfigFile)
    
    #CurrentUserProfile:
    $TempFile = $TempFile.Replace("{{USERPROFILE}}", $($env:UserProfile))
    
    #CurrentDate:
    $TempFile = $TempFile.Replace("{{DATE}}", $(Get-Date -Format "dd-MMM-yyyy"))

    #HostName:
    $TempFile = $TempFile.Replace("{{HOSTNAME}}", $($env:ComputerName))

    #Database Server:
    $TempFile = $TempFile.Replace("{{DBSERVER}}", $($env:ComputerName))

    #Set configuration:
    [XML]$Configuration = $TempFile
    
}


###################################################
#Setup Logging:
###################################################

Write-Host "Setting up logging for this session:"

#Check for configured logfile:
If($Configuration.root.globals.logfile){

    $LogFile = $Configuration.root.globals.logfile
    
}
#Set default log if command line option not set:
ElseIf (-not $LogFile) {

    $Date = (Get-Date -Format "dd-MMM-yyyy")
    $LogFile = $ThisScriptPath + "\logs\Script-Library-$($Date).log"
}


Write-Host "`t Logging to $($LogFile)"
Write-Host ("-" * 50)

#Clean up old log files:

$LogDir = $(Split-Path $LogFile -leaf)

If((Test-Path $LogDir)) {
    Remove-Generic -RootPath $LogDir -FileAge $LogDays | Out-Null
}


#################################################
# Create list of scripts:
#################################################

$ScriptList = (Get-ChildItem -Path $ScriptDir -Filter "*.ps1" -Recurse -Force)
$CommandHash = @{}
$CommandArgs = @{}

#Load all the scripts into the CommandHash:
ForEach($Script in $ScriptList) {
    $CommandHash.Add($Script.FullName, $CommandArgs)
}

#################################################
# Load script configuration:
#################################################

ForEach($Script in $Configuration.root.script) {

    $ConfigItemName = $ScriptDir + $Script.name
    $ArgsHash = @{}
    
    #Ensure the script has params:
    If($Script.param){
    
        #Cycle through all params in the configuration:
        ($Script.param | % {
            #Load config file if PassConfig = True
            If($_.name -eq "PassConfig" -and ($_.'#text') -eq "True"){
                $ArgsHash.Add("Config", $Configuration)
            }
            Else {
                $ArgsHash.Add($_.name, ($_.'#text'))
            }
        })
    
    } #If #Script.param
    
    #Add the script name and the param/values to the command hash:
    
    #Update the configuration value:
    If($CommandHash.ContainsKey($ConfigItemName) ){
    
        $CommandHash.Set_Item($ConfigItemName, $ArgsHash)
    }   
    
}

###################################################
#User control:
###################################################

If($Unattended -eq "False"){

    #Build a menu:
    $MenuHash = @{}
    $MenuNum = 1
    
    Write-Host "Options Menu:"
        
    ForEach($Key in ($CommandHash.Keys | Sort-Object) ) {
    
        $MenuHash.Add($MenuNum,($Key))
        $ShortScriptName = (Split-Path $Key -leaf)
            
        Write-Host "`t $($MenuNum). $($ShortScriptName)"
        
        $MenuNum ++
    }
       
    Write-Host ("-" * 50)
    
    #Ask the user which script to run:
    [int]$User_Prompt = Read-Host 'Enter the script number to execute:'
    $User_Answer = $MenuHash.Item($User_Prompt)
    
    #Set File and Args accordingly:
    $ScriptFile = $User_Answer
    $ScriptArgs = $CommandHash.Item($User_Answer)
    
}
Else {

    #Unattended
    If($ScriptFile){
        
        #Get Args (if any)
        $ScriptArgs = $CommandHash.Item($ScriptFile)
        
    }
    Else {
    
        Log-Start -LogFile $LogFile -JobName "Script Library"
        Log-Write -LogFile $LogFile -LineValue "Argument -ScriptFile not specified. Nothing to execute."
        Log-Finish -LogFile $LogFile -JobName "Script Library"
        Exit
    }
    
}

#Add the current log file to the list of arguments:
$ScriptArgs.Add("LogFile", $LogFile)

#Add the parent directory for the selected script to the list of arguments:
$ScriptArgs.Add("MyDirectory", (Split-Path -Parent -Path $ScriptFile))

###################################################
#Execute Script:
###################################################

#If interactive, give user chance to cancel before running:
If( ($Unattended -eq "False") -and (-not $psISE) ){

    Write-Host "Enter any key to confirm running: $(Split-Path $ScriptFile -leaf)"
    Write-Host "Press ctrl + c to cancel."
    [void]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
    
}

#Start logging:
Log-Start -LogFile $LogFile -JobName "$(Split-Path $ScriptFile -leaf)"
Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Log-Write -LogFile $LogFile -LineValue "User: $($env:UserDomain)\$($env:UserName)"
Log-Write -LogFile $LogFile -LineValue "Executing: $(Split-Path $ScriptFile -leaf)"
If($Unattended -eq "True"){$ScriptMode = "Unattended"}Else{$ScriptMode = "Interactive"}
Log-Write -LogFile $LogFile -LineValue "Mode: $($ScriptMode)"
Log-Write -LogFile $LogFile -LineValue ("-" * 50)

Write-Host "Executing: $(Split-Path $ScriptFile -leaf):"

#Log Arguments too:
Log-Write -LogFile $LogFile -LineValue "Script Arguments: `r`n"
ForEach($Arg in $ScriptArgs.Keys){
    Log-Write -LogFile $LogFile -LineValue "$($Arg) = $($ScriptArgs.Item($Arg))"
}

Log-Write -LogFile $LogFile -LineValue ("-" * 50)
Write-Host ("-" * 50)

#Run script:
[void](. $ScriptFile @ScriptArgs)

#End Logging:
Log-Finish -LogFile $LogFile -JobName "$(Split-Path $ScriptFile -leaf)"



