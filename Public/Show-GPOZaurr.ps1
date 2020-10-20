﻿function Show-GPOZaurr {
    [cmdletBinding()]
    param(
        [string] $FilePath,
        [ValidateSet(
            'GPOList', 'GPOOrphans', 'GPOPermissions', 'GPOPermissionsRoot',
            'GPOConsistency', 'GPOOwners', 'GPOAnalysis', 'NetLogon'
        )][string[]] $Type
    )
    if ($Type -contains 'GPOList' -or $null -eq $Type) {
        Write-Verbose -Message "Show-GPOZaurr - Processing GPO List"
        $GPOSummary = Get-GPOZaurr
        $GPOLinked = $GPOSummary.Where( { $_.Linked -eq $true }, 'split')
        $GPOEmpty = $GPOSummary.Where( { $_.Empty -eq $true, 'split' })
        $GPOTotal = $GPOSummary.Count
    }
    if ($Type -contains 'GPOOrphans' -or $null -eq $Type) {
        Write-Verbose -Message "Show-GPOZaurr - Processing GPO Sysvol"
        $GPOOrphans = Get-GPOZaurrBroken

        $NotAvailableInAD = [System.Collections.Generic.List[PSCustomObject]]::new()
        $NotAvailableOnSysvol = [System.Collections.Generic.List[PSCustomObject]]::new()
        $NotAvailablePermissionIssue = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($_ in $GPOOrphans) {
            if ($_.Status -eq 'Not available in AD') {
                $NotAvailableInAD.Add($NotAvailableInAD)
            } elseif ($_.Status -eq 'Not available on SYSVOL') {
                $NotAvailableOnSysvol.Add($NotAvailableInAD)
            } elseif ( $_.Status -eq 'Permissions issue') {
                $NotAvailablePermissionIssue.Add($NotAvailableInAD)
            }
        }
    }
    if ($Type -contains 'GPOPermissions' -or $null -eq $Type) {
        Write-Verbose -Message "Show-GPOZaurr - Processing GPO Permissions"
        $GPOPermissions = Get-GPOZaurrPermission -Type All -IncludePermissionType GpoEditDeleteModifySecurity, GpoEdit, GpoCustom -IncludeOwner
    }
    if ($Type -contains 'GPOConsistency' -or $null -eq $Type) {
        Write-Verbose -Message "Show-GPOZaurr - Processing GPO Permissions Consistency"
        $GPOPermissionsConsistency = Get-GPOZaurrPermissionConsistency -Type All -VerifyInheritance
        [Array] $Inconsistent = $GPOPermissionsConsistency.Where( { $_.ACLConsistent -eq $true } , 'split' )
        [Array] $InconsistentInside = $GPOPermissionsConsistency.Where( { $_.ACLConsistentInside -eq $true }, 'split' )
    }
    if ($Type -contains 'GPOConsistency' -or $null -eq $Type) {
        Write-Verbose -Message "Show-GPOZaurr - Processing GPO Permissions Root"
        $GPOPermissionsRoot = Get-GPOZaurrPermissionRoot
    }
    if ($Type -contains 'GPOOwners' -or $null -eq $Type) {
        Write-Verbose "Show-GPOZaurr - Processing GPO Owners"
        $GPOOwners = Get-GPOZaurrOwner -IncludeSysvol
        $IsOwnerConsistent = $GPOOwners.Where( { $_.IsOwnerConsistent -eq $true } , 'split' )
        $IsOwnerAdministrative = $GPOOwners.Where( { $_.IsOwnerAdministrative -eq $true } , 'split' )
    }
    if ($Type -contains 'NetLogon' -or $null -eq $Type) {
        Write-Verbose "Get-GPOZaurrNetLogon - Processing NETLOGON Share"
        $Netlogon = Get-GPOZaurrNetLogon
    }
    if ($Type -contains 'GPOAnalysis' -or $null -eq $Type) {
        Write-Verbose "Show-GPOZaurr - Processing GPO Analysis"
        $GPOContent = Invoke-GPOZaurr
    }

    Write-Verbose "Show-GPOZaurr - Generating HTML"
    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px -RemoveShadow
        New-HTMLTableOption -DataStore JavaScript
        New-HTMLTab -Name 'Overview' {
            if ($Type -contains 'GPOConsistency' -or $Type -contains 'GPOList' -or $null -eq $Type) {
                New-HTMLSection -Invisible {
                    if ($Type -contains 'GPOList' -or $null -eq $Type) {
                        New-HTMLPanel {
                            New-HTMLChart -Title 'Group Policies Summary' {
                                New-ChartLegend -Names 'Unlinked', 'Linked', 'Empty', 'Total' -Color Salmon, PaleGreen, PaleVioletRed, PaleTurquoise
                                New-ChartBar -Name 'Group Policies' -Value $GPOLinked[1].Count, $GPOLinked[0].Count, $GPOEmpty[1].Count, $GPOTotal
                            } -TitleAlignment center
                        }
                    }
                    if ($Type -contains 'GPOConsistency' -or $null -eq $Type) {
                        New-HTMLPanel {
                            New-HTMLChart {
                                New-ChartBarOptions -Type barStacked
                                New-ChartLegend -Name 'Consistent', 'Inconsistent'
                                New-ChartBar -Name 'TopLevel' -Value $Inconsistent[0].Count, $Inconsistent[1].Count
                                New-ChartBar -Name 'Inherited' -Value $InconsistentInside[0].Count, $InconsistentInside[1].Count
                            } -Title 'Permissions Consistency' -TitleAlignment center
                        }
                    }
                }
            }
            if ($Type -contains 'GPOOwners' -or $Type -contains 'GPOOrphans' -or $null -eq $Type) {
                New-HTMLSection -Invisible {
                    if ($Type -contains 'GPOOwners' -or $null -eq $Type) {
                        New-HTMLPanel {
                            New-HTMLText -Text 'Following chart presents Group Policy owners and whether they are administrative and consistent. By design an owner of Group Policy should be Domain Admins or Enterprise Admins group only to prevent malicious takeover. ', `
                                "It's also important that owner in Active Directory matches owner on SYSVOL (file system)."
                            New-HTMLChart {
                                New-ChartBarOptions -Type barStacked
                                New-ChartLegend -Name 'Yes', 'No' -Color PaleGreen, Orchid
                                New-ChartBar -Name 'Is administrative' -Value $IsOwnerAdministrative[0].Count, $IsOwnerAdministrative[1].Count
                                New-ChartBar -Name 'Is consistent' -Value $IsOwnerConsistent[0].Count, $IsOwnerConsistent[1].Count
                            } -Title 'Group Policy Owners'
                        }
                    }
                    if ($Type -contains 'GPOOrphans' -or $null -eq $Type) {
                        New-HTMLPanel {
                            New-HTMLText -Text 'Following chart presents ', 'Broken / Orphaned Group Policies' -FontSize 10pt -FontWeight normal, bold
                            New-HTMLList -Type Unordered {
                                New-HTMLListItem -Text 'Group Policies on SYSVOL, but no details in AD: ', $NotAvailableInAD.Count -FontWeight normal, bold
                                New-HTMLListItem -Text 'Group Policies in AD, but no content on SYSVOL: ', $NotAvailableOnSysvol.Count -FontWeight normal, bold
                                New-HTMLListItem -Text "Group Policies which couldn't be assed due to permissions issue: ", $NotAvailablePermissionIssue.Count -FontWeight normal, bold
                            } -FontSize 10pt
                            New-HTMLText -FontSize 10pt -Text 'Those problems must be resolved before doing other clenaup activities.'
                            New-HTMLChart {
                                New-ChartBarOptions -Type barStacked
                                New-ChartLegend -Name 'Not in AD', 'Not on SYSVOL', 'Permissions Issue' -Color Crimson, LightCoral, IndianRed
                                New-ChartBar -Name 'Orphans' -Value $NotAvailableInAD.Count, $NotAvailableOnSysvol.Count, $NotAvailablePermissionIssue.Count
                            } -Title 'Broken / Orphaned Group Policies' -TitleAlignment center
                        }
                    }
                }
            }
        }
        if ($Type -contains 'GPOList' -or $null -eq $Type) {
            New-HTMLTab -Name 'Group Policies Summary' {
                New-HTMLTable -DataTable $GPOSummary -Filtering {
                    New-HTMLTableCondition -Name 'Empty' -Value $true -BackgroundColor Salmon -TextTransform capitalize -ComparisonType bool
                    New-HTMLTableCondition -Name 'Linked' -Value $false -BackgroundColor Salmon -TextTransform capitalize -ComparisonType bool
                }
            }
        }
        if ($Type -contains 'GPOOrphans' -or $null -eq $Type) {
            New-HTMLTab -Name 'Health State' {
                New-HTMLPanel {
                    New-HTMLText -TextBlock {
                        "Following table shows list of all group policies and their status in AD and SYSVOL. Due to different reasons it's "
                        "possible that "
                    } -FontSize 10pt
                    New-HTMLList -Type Unordered {
                        New-HTMLListItem -Text 'Group Policies on SYSVOL, but no details in AD: ', $NotAvailableInAD.Count -FontWeight normal, bold
                        New-HTMLListItem -Text 'Group Policies in AD, but no content on SYSVOL: ', $NotAvailableOnSysvol.Count -FontWeight normal, bold
                        New-HTMLListItem -Text "Group Policies which couldn't be assed due to permissions issue: ", $NotAvailablePermissionIssue.Count -FontWeight normal, bold
                    } -FontSize 10pt
                    New-HTMLText -Text "Follow the steps below table to get Active Directory Group Policies in healthy state." -FontSize 10pt
                }
                New-HTMLSection -Name 'Health State of Group Policies' {
                    New-HTMLTable -DataTable $GPOOrphans -Filtering {
                        New-HTMLTableCondition -Name 'Status' -Value "Not available in AD" -BackgroundColor Salmon -ComparisonType string
                        New-HTMLTableCondition -Name 'Status' -Value "Not available on SYSVOL" -BackgroundColor LightCoral -ComparisonType string
                    } -PagingLength 10 -PagingOptions 10, 20, 30, 50
                }
                New-HTMLSection -Name 'Steps to fix - Not available on SYSVOL / Active Directory' {
                    New-HTMLContainer {
                        New-HTMLSpanStyle -FontSize 10pt {
                            New-HTMLText -Text 'Following steps will guide you how to fix GPOs which are not available on SYSVOL or AD.'
                            New-HTMLWizard {
                                New-HTMLWizardStep -Name 'Prepare environment' {
                                    New-HTMLText -Text "To be able to execute actions in automated way please install required modules. Those modules will be installed straight from Microsoft PowerShell Gallery."
                                    New-HTMLCodeBlock -Code {
                                        Install-Module GPOZaurr -Force
                                        Import-Module GPOZaurr -Force
                                    } -Style powershell
                                    New-HTMLText -Text "Using force makes sure newest version is downloaded from PowerShellGallery regardless of wha is currently installed. Once installed you're ready for next step."
                                }
                                New-HTMLWizardStep -Name 'Prepare report' {
                                    New-HTMLText -Text "Depending when this report was run you may want to prepare new report before proceeding with removal. To generate new report please use:"
                                    New-HTMLCodeBlock -Code {
                                        Show-GPOZaurr -FilePath $Env:UserProfile\Desktop\GPOZaurrBrokenGpoBefore.html -Verbose -Type GPOOrphans
                                    }
                                    New-HTMLText -Text {
                                        "When executed it will take a while to generate all data and provide you with new report depending on size of environment."
                                        "Once confirmed that data is still showing issues and requires fixing please proceed with next step."
                                    }
                                    New-HTMLText -Text "Alternatively if you prefer working with console you can run: "
                                    New-HTMLCodeBlock -Code {
                                        $GPOOutput = Get-GPOZaurrBroken
                                        $GPOOutput | Format-Table
                                    }
                                    New-HTMLText -Text "It provides same data as you see in table above just doesn't prettify it for you."
                                }
                                New-HTMLWizardStep -Name 'Fix GPOs not available on SYSVOL' {
                                    New-HTMLText -Text "Following command when executed runs cleanup procedure that removes all broken GPOs on SYSVOL side."
                                    New-HTMLText -Text "Make sure when running it for the first time to run it with ", "WhatIf", " parameter as shown below to prevent accidental removal." -FontWeight normal, bold, normal -Color Black, Red, Black

                                    New-HTMLCodeBlock -Code {
                                        Remove-GPOZaurrBroken -Type SYSVOL -WhatIf
                                    }
                                    New-HTMLText -TextBlock {
                                        "After execution please make sure there are no errors, make sure to review provided output, and confirm that what is about to be deleted matches expected data. Once happy with results please follow with command: "
                                    }
                                    New-HTMLCodeBlock -Code {
                                        Remove-GPOZaurrBroken -Type SYSVOL -LimitProcessing 2 -BackupPath $Env:UserProfile\Desktop\GPOSYSVOLBackup
                                    }
                                    New-HTMLText -TextBlock {
                                        "This command when executed deletes only first X broken GPOs. Use LimitProcessing parameter to prevent mass delete and increase the counter when no errors occur."
                                        "Repeat step above as much as needed increasing LimitProcessing count till there's nothing left. In case of any issues please review and action accordingly."
                                    }
                                    New-HTMLText -Text "If there's nothing else to be deleted on SYSVOL side, we can skip to next step step"
                                }
                                New-HTMLWizardStep -Name 'Fix GPOs not available on AD' {
                                    New-HTMLText -Text "Following command when executed runs cleanup procedure that removes all broken GPOs on Active Directory side."
                                    New-HTMLText -Text "Make sure when running it for the first time to run it with ", "WhatIf", " parameter as shown below to prevent accidental removal." -FontWeight normal, bold, normal -Color Black, Red, Black

                                    New-HTMLCodeBlock -Code {
                                        Remove-GPOZaurrBroken -Type AD -WhatIf
                                    }
                                    New-HTMLText -TextBlock {
                                        "After execution please make sure there are no errors, make sure to review provided output, and confirm that what is about to be deleted matches expected data. Once happy with results please follow with command: "
                                    }
                                    New-HTMLCodeBlock -Code {
                                        Remove-GPOZaurrBroken -Type AD -LimitProcessing 2 -BackupPath $Env:UserProfile\Desktop\GPOSYSVOLBackup
                                    }
                                    New-HTMLText -TextBlock {
                                        "This command when executed deletes only first X broken GPOs. Use LimitProcessing parameter to prevent mass delete and increase the counter when no errors occur."
                                        "Repeat step above as much as needed increasing LimitProcessing count till there's nothing left. In case of any issues please review and action accordingly."
                                    }
                                    New-HTMLText -Text "If there's nothing else to be deleted on AD side, we can skip to next step step"
                                }
                                New-HTMLWizardStep -Name 'Verification report' {
                                    New-HTMLText -TextBlock {
                                        "Once cleanup task was executed properly, we need to verify that report now shows no problems."
                                    }
                                    New-HTMLCodeBlock -Code {
                                        Show-GPOZaurr -FilePath $Env:UserProfile\Desktop\GPOZaurrBrokenGpoAfter.html -Verbose -Type GPOOrphans
                                    }
                                    New-HTMLText -Text "If everything is health in the report you're done! Enjoy rest of the day!" -Color BlueDiamond
                                }
                            } -RemoveDoneStepOnNavigateBack -Theme arrows -ToolbarButtonPosition center
                        }
                    }
                }
            }
        }
        if ($Type -contains 'NetLogon' -or $null -eq $Type) {
            New-HTMLTab -Name 'NetLogon' {
                New-HTMLTable -DataTable $Netlogon -Filtering
            }
        }
        if ($Type -contains 'GPOPermissionsRoot' -or $Type -contains 'GPOOwners' -or
            $Type -contains 'GPOPermissions' -or $Type -contains 'GPOConsistency' -or
            $null -eq $Type
        ) {
            New-HTMLTab -Name 'Permissions' {
                if ($Type -contains 'GPOPermissionsRoot' -or $null -eq $Type) {
                    New-HTMLTab -Name 'Root' {
                        New-HTMLTable -DataTable $GPOPermissionsRoot -Filtering
                    }
                }
                if ($Type -contains 'GPOOwners' -or $null -eq $Type) {
                    New-HTMLTab -Name 'Owners' {
                        New-HTMLTable -DataTable $GPOOwners -Filtering
                    }
                }
                if ($Type -contains 'GPOPermissions' -or $null -eq $Type) {
                    New-HTMLTab -Name 'Edit & Modify' {
                        New-HTMLTable -DataTable $GPOPermissions -Filtering
                    }
                }
                if ($Type -contains 'GPOConsistency' -or $null -eq $Type) {
                    New-HTMLTab -Name 'Permissions Consistency' {
                        New-HTMLTable -DataTable $GPOPermissionsConsistency -Filtering {
                            New-HTMLTableCondition -Name 'ACLConsistent' -Value $false -BackgroundColor Salmon -TextTransform capitalize -ComparisonType bool
                            New-HTMLTableCondition -Name 'ACLConsistentInside' -Value $false -BackgroundColor Salmon -TextTransform capitalize -ComparisonType bool
                        }
                    }
                }
            }
        }
        if ($Type -contains 'GPOAnalysis' -or $null -eq $Type) {
            New-HTMLTab -Name 'Analysis' {
                foreach ($Key in $GPOContent.Keys) {
                    New-HTMLTab -Name $Key {
                        New-HTMLTable -DataTable $GPOContent[$Key] -Filtering -Title $Key
                    }
                }
            }
        }
    } -Online -ShowHTML -FilePath $FilePath
}