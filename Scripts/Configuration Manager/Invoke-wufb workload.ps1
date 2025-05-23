function Invoke-ForceEvaluation
{
    param (
        [Parameter(Mandatory=$true, HelpMessage="Computer Name",ValueFromPipeline=$true)] $ComputerName
           )
    $Baselines = Get-WmiObject -Namespace root\ccm\dcm -Class SMS_DesiredConfiguration | Where-Object {$_.DisplayName ="CoMgmtSettingsPilotWUP"}
    $Baselines | % { ([wmiclass]"\\$ComputerName\root\ccm\dcm:SMS_DesiredConfiguration").TriggerEvaluation($_.Name, $_.Version) }
}
foreach($hostname in (Get-Content C:\path to our txt file with hostnames)) {
    Invoke-ForceEvaluation $hostname
}