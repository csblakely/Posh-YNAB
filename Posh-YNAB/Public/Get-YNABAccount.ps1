function Get-YNABAccount {
    <#
    .SYNOPSIS
    Describe the function here
    .DESCRIPTION
    Describe the function in more detail
    .EXAMPLE
    Give an example of how to use it
    .EXAMPLE
    Give another example of how to use it
    .PARAMETER computername
    The computer name to query. Just one.
    .PARAMETER logname
    The name of a file to write failed computer names to. Defaults to errors.txt.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName='Detail:BudgetName,AccountName')]
        [Parameter(Mandatory=$true,ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName='Detail:BudgetName,AccountID')]
        [Parameter(Mandatory=$true,ParameterSetName='List:BudgetName')]
        [String]$BudgetName,

        [Parameter(Mandatory=$true,ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName='Detail:BudgetID,AccountName')]
        [Parameter(Mandatory=$true,ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName='Detail:BudgetID,AccountID')]
        [Parameter(Mandatory=$true,ParameterSetName='List:BudgetID')]
        [String]$BudgetID,

        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName,ParameterSetName='Detail:BudgetName,AccountName')]
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName,ParameterSetName='Detail:BudgetID,AccountName')]
        [String[]]$AccountName,

        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName,ParameterSetName='Detail:BudgetName,AccountID')]
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName,ParameterSetName='Detail:BudgetID,AccountID')]
        [String[]]$AccountID,

        [Parameter(ParameterSetName='List:BudgetName')]
        [Parameter(ParameterSetName='List:BudgetID')]
        [Switch]$List,

        [Parameter(ParameterSetName='List:BudgetName')]
        [Parameter(ParameterSetName='List:BudgetID')]
        [Switch]$IncludeClosed,

        [Parameter(Mandatory=$true)]
        [String]$Token
    )

    begin {
        # Set the default header value for Invoke-RestMethod
        $header = Get-Header $Token`
        Write-Verbose "Get-YNABAccount ParameterSetName: $($PsCmdlet.ParameterSetName)"
    }

    process {
        # Get the budget IDs if the budget was specified by name
        if ($BudgetName) {
            Write-Verbose "Performing budget lookup to get BudgetID for $BudgetName"
            $budgets = Get-YNABBudget -List -Token $Token
            $BudgetID = $budgets.Where{$_.Budget -like $BudgetName}.BudgetID
            Write-Verbose "Using BudgetID: $BudgetID"
        }

        # Get the account ID if the account was specified by name
        if ($AccountName) {
            $accounts = Get-YNABAccount -List -BudgetID $BudgetID -Token $Token
            $AccountID = $AccountName.ForEach{
                $name = $_
                $accounts.Where{$_.Account -like $name}.AccountID
            }
            Write-Verbose "Using AccountID: $($AccountID -join ', ')"
        }

        switch -Wildcard ($PsCmdlet.ParameterSetName) {
            'List*' {
                $response = Invoke-RestMethod "$uri/budgets/$BudgetID/accounts" -Headers $header
                if ($response) {
                    # By default only include open accounts, return closed accounts if -IncludeClosed is specified
                    $data = $response.data.accounts.Where{
                        if (!$IncludeClosed) {$_.closed -ne $true}
                        else {$_}
                    }
                    Get-ParsedAccountJson $data
                }
            }
            'Detail*' {
                # Return account details for each AccountID specified
                $AccountID.ForEach{
                    $response = Invoke-RestMethod "$uri/budgets/$BudgetID/accounts/$_" -Headers $header
                    if ($response) {
                        Get-ParsedAccountJson $response.data.account
                    }
                }
            }
        }
    }
}
