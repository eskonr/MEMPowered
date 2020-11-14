# Custom class to create a background powershell job
class BackgroundJob
{
    # Properties
    hidden $PowerShell = [powershell]::Create() 
    hidden $Handle = $null
    hidden $Runspace = $null
    $Result = $null
    $RunspaceID = $This.PowerShell.Runspace.ID
    $PSInstance = $This.PowerShell

    
    # Constructor (just code block)
    BackgroundJob ([scriptblock]$Code)
    { 
        $This.PowerShell.AddScript($Code)
    }

    # Constructor (code block + arguments)
    BackgroundJob ([scriptblock]$Code,$Arguments)
    { 
        $This.PowerShell.AddScript($Code)
        foreach ($Argument in $Arguments)
        {
            $This.PowerShell.AddArgument($Argument)
        }
    }

    # Constructor (code block + arguments + functions)
    BackgroundJob ([scriptblock]$Code,$Arguments,$Functions)
    { 
        $InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $Scope = [System.Management.Automation.ScopedItemOptions]::AllScope
        foreach ($Function in $Functions)
        {
            $FunctionName = $Function.Split('\')[1]
            $FunctionDefinition = Get-Content $Function -ErrorAction Stop
            $SessionStateFunction = New-Object -TypeName System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $FunctionName, $FunctionDefinition, $Scope, $null
            $InitialSessionState.Commands.Add($SessionStateFunction)
        }
        $This.Runspace = [runspacefactory]::CreateRunspace($InitialSessionState)
        $This.PowerShell.Runspace = $This.Runspace
        $This.Runspace.Open()
        $This.PowerShell.AddScript($Code)
        foreach ($Argument in $Arguments)
        {
            $This.PowerShell.AddArgument($Argument)
        }
    }
    
    # Start Method
    Start()
    {
        $THis.Handle = $This.PowerShell.BeginInvoke()
    }

    # Stop Method
    Stop()
    {
        $This.PowerShell.Stop()
    }

    # Receive Method
    [object]Receive()
    {
        $This.Result = $This.PowerShell.EndInvoke($This.Handle)
        return $This.Result
    }

    # Remove Method
    Remove()
    {
        $This.PowerShell.Dispose()
        If ($This.Runspace)
        {
            $This.Runspace.Dispose()
        }
    }

    # Get Status Method
    [object]GetStatus()
    {
        return $This.PowerShell.InvocationStateInfo
    }
}
