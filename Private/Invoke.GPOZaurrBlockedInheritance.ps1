﻿$GPOZaurrBlockedInheritance = [ordered] @{
    Name           = 'Group Policy Blocked Inhertiance'
    Enabled        = $true
    ActionRequired = $null
    Data           = $null
    Execute        = {
        Get-GPOZaurrInheritance -IncludeBlockedObjects -OnlyBlockedInheritance
    }
    Processing     = {

    }
    Variables      = @{

    }
    Overview       = {

    }
    Solution       = {
        New-HTMLTable -DataTable $Script:Reporting['GPOBlockedInheritance']['Data'] -Filtering
    }
}