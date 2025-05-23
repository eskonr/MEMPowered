<#
Usage:
Run the powershell script and then use the following to convert the co-mgmt code to human readble format
[workloads]12543
#>
[flags()] Enum workloads {
        CoMgmt_Enabled = 8193
        Compliance_Policies = 2
        Resource_Access_Policies = 4
        Device_Configuration = 8
        Windows_Update_Policies = 16
        Client_Apps = 64
        Office_Click2Run_Apps = 128
        Endpoint_Protection = 4128
    }