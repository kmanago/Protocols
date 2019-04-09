
Add-Type -Path "$($PSScriptRoot)\Module_Classes.cs"

function Set-SSLProtocols{
    <#
            .SYNOPSIS

            Enable/Disable SSL/TLS Protocols for server/client for an individual AD FS Server or an entire ADFS Environment.
 

            .DESCRIPTION

            Enable/Disable SSL/TLS Protocols for server/client for an individual AD FS Server or an entire ADFS Environment.
            Rebooting a system is required at the end of the task for the changes to take place. They can be set with
            the reboot flag with it being $true or $false.

            .EXAMPLE

            Set-SSLTLS -Computer Server01 -Protocol TLS10 -Action Disable -Reboot $true

            This sets Server01 to have its TLS 1.0 connection disabled 

            .EXAMPLE

            Set-SSLTLS -Environment Env02 -Protocol TLS20 -Action Enable -Reboot $true

            This sets all computers that are in the Env02 environment to have their TLS 2.0 connection enabled
 

#>

    [CmdletBinding(SupportsShouldProcess=$False,
    ConfirmImpact='High')]

    #creates accepted commands for the cmdlet
    PARAM(
    [parameter(Mandatory=$True,ParameterSetName="Computer",Position=0)]
    [STRING]$Computer="",
    #set of ADFS environments that are accepted inputs
    [ValidateSet("21Dev","21Prod","30Dev","30Prod","40Dev","40Prod")]
    [parameter(Mandatory=$True, ParameterSetName="Environment",Position=0)]
    [STRING]$Environment="",
    #set of protocols that are accepted inputs
    [ValidateSet("SSL20","SSL30","TLS10","TLS11","TLS12")]
    [parameter(Mandatory=$True,Position=1)]
    [STRING]$Protocol="",
    #set of actions that are accepted inputs
    [ValidateSet("Enable","Disable")]
    [parameter(Mandatory=$True,Position=2)]
    [STRING]$Action="",
    [bool]
    $Reboot = $false
    )
    
    #write-host "Connected to" $Computer;

    $ErrorActionPreference = "Stop"
    #creates the base statement registry key based on the protocol that was selected
    switch($Protocol){
        SSL20 {$regkey="HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0"}
        SSL30 {$regkey="HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0"}
        TLS10 {$regkey="HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0"}
        TLS11 {$regkey="HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1"}
        TLS12 {$regkey="HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2"}
    }

    #if user selects an entire environment instead of an individual computer, it loads a variable with all computers
    #from that environment that will have the changes completed on
    switch($Environment){
        21Dev{$env=""}
        21Prod{$env=""}
        30Dev{$env=""}
        30Prod{$env=""}
        40Dev{$env=""}
        40Prod{$env=""}
    }

    Write-Host "Setting up both client and server protocols."

    #if user goes with the environment option, this occurs
    if(!$Computer){
        #for loop goes through each computer in the environment
        for($i=0;$i -lt $env.Count;$i++){
            $error.clear() #clear out error
            $Computer = $env[$i].ToString();
            #attemtps to make the necessary changes to the computers
            try {
                New-Protocol
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-Host 'An error occured' -ForegroundColor Red -BackgroundColor Black
            }
            #if no error occurs, print successful completion and ask to reboot
            if ($Reboot)
            {
                if (!$Error){
                    Write-Host "`nThe operation completed successfully on $Computer. Reboot is required." -ForegroundColor Green
                    $reply = Read-Host -Prompt "Would you like to restart $Computer now?[y/n]"
                    if ( $reply -match "[yY]" ) { 
                        Write-Host "Restarting $Computer" -ForegroundColor Yellow
                        Restart-Computer -ComputerName $Computer -Force -Wait -For WinRM
                        Write-Host "Restarting $Computer completed"
                    }
                } #end of no error            
            }
        }#end of for loop
    }#end of if computer is null

    #if user decides to go with an individual computer, this occurs
    else{
        try {
            New-Protocol
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host 'An error occured' -ForegroundColor Red -BackgroundColor Black
        }
        #if no error occurs, print successful completion and ask to reboot
        if ($Reboot)
        {
            if (!$Error){
                Write-Host "`nThe operation completed successfully on $Computer. Reboot is required." -ForegroundColor Green
                $reply = Read-Host -Prompt "Would you like to restart $Computer now?[y/n]" -
                if ( $reply -match "[yY]" ) { 
                    Write-Host "Restarting $Computer" -ForegroundColor Yellow
                    Restart-Computer -ComputerName $Computer -Force -Wait -For WinRM
                    Write-Host "Restarting $Computer completed"
                }
            } #end of no error
        }
    }#end of individual computer option
}


function New-Protocol{
    #begins session with computer 
   $session = New-PSSession -ComputerName $Computer; 

    #makes the string for both client and servers that's going to be used for the registry
    $client=$(Join-Path $regkey "Client").ToString();
    $server=$(Join-Path $regkey "Server").ToString();

    #checks to see if the strings exist already in the registry and if not, creates them
    if(!(Invoke-Command -session $session -scriptblock{test-path -path $Using:client})){
        Write-Host "Client path does not exist in registry. Creating..."
        Invoke-Command -session $session -scriptblock{New-Item $Using:client -Force} -HideComputerName   
    }
    if(!(Invoke-Command -session $session -scriptblock{test-path -path $Using:server})){
        Write-Host "`nServer path does not exist in registry. Creating..."
        Invoke-Command -session $session -scriptblock{New-Item $Using:server -Force} -HideComputerName   
    }

    Write-Host "`nSetting changes..." 

    #makes the changes if the user selects to disable their versions
    if($Action -eq 'Disable'){
        Write-Host "`t`Updating $server"
        Invoke-Command -session $session -scriptblock{New-ItemProperty -path $Using:server -name 'Enabled' -value '0' -PropertyType 'DWord' -Force | Out-Null} -HideComputerName   
        Invoke-Command -session $session -scriptblock{New-ItemProperty -path $Using:server -name 'DisabledByDefault' -value 1 -PropertyType 'DWord' -Force | Out-Null} -HideComputerName
        Write-Host "`t`Updating $client"
        Invoke-Command -session $session -scriptblock{New-ItemProperty -path  $Using:client -name 'Enabled' -value '0' -PropertyType 'DWord' -Force | Out-Null} -HideComputerName   
        Invoke-Command -session $session -scriptblock{New-ItemProperty -path  $Using:client -name 'DisabledByDefault' -value 1 -PropertyType 'DWord' -Force | Out-Null} -HideComputerName  
        
        #ADFS requires strong authentication when TLS 1.0 is disabled so enables it
        if($Protocol -eq 'TLS10'){
            Write-Host "`t`Disabling TLS 1.0 so enabling Strong Authentication for applications...."
            #checks the registry for the strong auth string and creates if it is not found
            $target="HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319";
            if(!(Invoke-Command -session $session -scriptblock{test-path -path $Using:target})){
                Write-Host "Strong Auth path does not exist in registry. Creating..."
                Invoke-Command -session $session -scriptblock{New-Item $Using:target -Force} -HideComputerName  
            }
            Invoke-Command -session $session -scriptblock{New-ItemProperty -path $Using:target -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null} -HideComputerName
        }  
      
    }
    
    #makes the changes if the user selects to enable their versions
    elseif($Action -eq 'Enable'){
        Write-Host "`t`Updating $server"
        Invoke-Command -session $session -scriptblock{New-ItemProperty -path $Using:server -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null} -HideComputerName   
        Invoke-Command -session $session -scriptblock{New-ItemProperty -path $Using:server -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null} -HideComputerName
        Write-Host "`t`Updating $client"
        Invoke-Command -session $session -scriptblock{New-ItemProperty -path $Using:client -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null} -HideComputerName   
        Invoke-Command -session $session -scriptblock{New-ItemProperty -path $Using:client -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null} -HideComputerName

        #ADFS required strong authentication when TLS 1.0 was disabled so disabling it
        if($Protocol -eq 'TLS10'){
            Write-Host "`t`Enabling TLS 1.0 so disabling Strong Authentication for applications...."
            #checks the registry for the strong auth string and creates if it is not found
            $target="HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319";
            if(!(Invoke-Command -session $session -scriptblock{test-path -path $Using:target})){
                Write-Host "Strong Auth path does not exist in registry. Creating..."
                Invoke-Command -session $session -scriptblock{New-Item $Using:target -Force} -HideComputerName  
            }
            Invoke-Command -session $session -scriptblock{New-ItemProperty -path $Using:target -name 'SchUseStrongCrypto' -value '0' -PropertyType 'DWord' -Force | Out-Null} -HideComputerName   
        } 
    }

    Remove-PSSession -Session $session;
}

function Get-Protocol
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true)]
        [string]
        $ComputerName,
        [ValidateSet("SSL20","SSL30","TLS10","TLS11","TLS12")]
        [parameter(Mandatory=$True,Position=1)]
        [STRING]$Protocol=""
    )
    
    begin {
    }
    
    process 
    {
        switch($Protocol)
        {
            SSL20 {$regkey="SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client",
                            "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"}
            SSL30 {$regkey="SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client",
                            "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"}
            TLS10 {$regkey="SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client",
                            "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"}
            TLS11 {$regkey="SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client",
                            "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"}
            TLS12 {$regkey="SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client",
                            "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"}
        }

        $outItem = New-Object PSProtocols.Protocol

        try
        {
            $regKeyClient = Get-RegistryKey -ComputerName $ComputerName `
                                                -Path $regkey[0]
        }
        catch
        {
            Write-Verbose "Client registry key does not exist. `n$($_)"
        }
        try
        {
            $regKeyServer = Get-RegistryKey -ComputerName $ComputerName `
                                                -Path $regkey[1]
        }
        catch
        {
            Write-Verbose "Server registry key does not exits. `n$($_)"
        }

        if ($regKeyClient -ne $null)
        {
            if ($regKeyClient.GetValue("enabled") -ne $null)
            {
                $outItem.Client_Enabled = $regKeyClient.GetValue("enabled") -eq 1
            }
            if ($regKeyClient.GetValue("DisabledByDefault") -ne $null)
            {
                $outItem.Client_DisabledByDefault = $regKeyClient.GetValue("DisabledByDefault") -eq 1
            }
        }
        if ($regKeyServer -ne $null)
        {
            if ($regKeyServer.GetValue("enabled") -ne $null)
            {
                $outItem.Server_Enabled = $regKeyServer.GetValue("enabled") -eq 1
            }
            if ($regKeyServer.GetValue("DisabledByDefault") -ne $null)
            {
                $outItem.Server_DisabledByDefault = $regKeyServer.GetValue("DisabledByDefault") -eq 1
            }
        }

        $outItem | Write-Output
    }
    
    end {
    }
}

Set-Alias Set-TLSProtocols Set-SSLProtocols
Export-ModuleMember -Function 'Set-SSLProtocols','New-Protocol','Get-Protocol'-Alias 'Set-TLSProtocols'

