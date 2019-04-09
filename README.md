# Protocols
Set SSL/TLS protocols for environments and Servers

## SYNOPSIS
Enable/Disable SSL/TLS Protocols for server/client for an individual AD FS Server or an entire ADFS Environment.
 
## DESCRIPTION
Enable/Disable SSL/TLS Protocols for server/client for an individual AD FS Server or an entire ADFS Environment.
Rebooting a system is required at the end of the task for the changes to take place. They can be set with
the reboot flag with it being $true or $false.

## EXAMPLE
`Set-SSLTLS -Computer Server01 -Protocol TLS10 -Action Disable -Reboot $true`

This sets Server01 to have its TLS 1.0 connection disabled 

`Set-SSLTLS -Environment Env02 -Protocol TLS20 -Action Enable -Reboot $true`

This sets all computers that are in the Env02 environment to have their TLS 2.0 connection enabled
 

