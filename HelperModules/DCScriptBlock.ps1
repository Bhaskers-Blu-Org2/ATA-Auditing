param(
    # FQDN of the DC
    [Parameter(Mandatory=$true, Position=0)]
    [string]
    $FqdnDc,

    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $LiteralPath,

    [Parameter(Mandatory=$true, Position=2)]
    [string]
    $AtaVersion
)
Import-Module $LiteralPath\HelperModules\Get-AuditPolicyCompliance.psm1 -Force -ErrorAction Stop

Write-Host "`t[-] Inspecting $FqdnDc" -ForegroundColor Green
<#
    Test connection--if not reachable, go to next DC (continue)

    Upon success, do magic
#>
If((Test-Connection -ComputerName $FqdnDc -Quiet) -eq $false){break}
#Advanced Audit Settings Force check
$AdvancedAuditForce = Get-RemoteAdvancedAuditForcePolicy -ServerName $FqdnDc
#Assess AuditPol settings
$AuditPolResultsFile = "$LiteralPath\Results\$FqdnDc-$(get-date -Format "MM-dd").csv"
$FqdnDc | Get-AuditPolSettings -ResultsFilePath "$AuditPolResultsFile"
$auditPolStatus = Measure-AtaCompliance -AtaVersion $AtaVersion -AuditPolFile $AuditPolResultsFile

#Service Discovery of LWGW/ATA Service
[bool]$isLwgw = Get-RemoteAtaServiceStatus -ServerName $FqdnDc

$overallStatus = ""
if ($AdvancedAuditForce -eq $false){
    $overallStatus = "Advanced Audit Settings are not enforced.  This is against security best practices and should be fixed immediately. https://docs.microsoft.com/en-us/windows/device-security/security-policy-settings/audit-force-audit-policy-subcategory-settings-to-override"
}
elseif ($auditPolStatus.HighLevel -and $isLwgw){
    $overallStatus = "All is good :) Events are detected and being pushed to the ATA Center"
}
elseif ($auditPolStatus.HighLevel -and ($isLwgw -eq $false)) {
    $overallStatus = "Audit policies are good but not LWGW. Ensure events are forwarded via Windows Event Forwarding or SIEM. https://docs.microsoft.com/en-us/advanced-threat-analytics/install-ata-step6"
}
elseif (($auditPolStatus.HighLevel -eq $false) -and $isLwgw){
    $overallStatus = "Audit policies need attention for this LWGW."
}
else{
    $overallStatus = "Audit policies need attention and ensure events are forwarded via Windwos Event Forwarding or SIEM. https://docs.microsoft.com/en-us/advanced-threat-analytics/install-ata-step6"
}


$DCResults += New-Object psobject -Property @{
    DC_FQDN = $FqdnDc
    AdvancedAuditForce = $AdvancedAuditForce
    AuditSettingsOverall = $auditPolStatus.HighLevel
    AuditSettingsCredVal = $auditPolStatus.Details.CredVal
    AuditSettingsSecGroupMgt = $auditPolStatus.Details.SecGroupMgmt
    IsLWGW = $isLwgw
    OverallStatus = $overallStatus
}

return $DCResults