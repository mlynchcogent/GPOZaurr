﻿$GPOZaurrOrphans = [ordered] @{
    Name           = 'Orphaned Group Policies'
    Enabled        = $true
    ActionRequired = $null
    Data           = $null
    Execute        = {
        Get-GPOZaurrBroken
    }
    Processing     = {
        foreach ($GPO in $Script:Reporting['GPOOrphans']['Data']) {
            if ($GPO.Status -eq 'Not available in AD') {
                $Script:Reporting['GPOOrphans']['Variables']['NotAvailableInAD']++
                $Script:Reporting['GPOOrphans']['Variables']['ToBeDeleted']++
            } elseif ($GPO.Status -eq 'Not available on SYSVOL') {
                $Script:Reporting['GPOOrphans']['Variables']['NotAvailableOnSysvol']++
                $Script:Reporting['GPOOrphans']['Variables']['ToBeDeleted']++
            } elseif ($GPO.Status -eq 'Permissions issue') {
                $Script:Reporting['GPOOrphans']['Variables']['NotAvailablePermissionIssue']++
            }
        }
        if ($Script:Reporting['GPOOrphans']['Variables']['ToBeDeleted'].Count -gt 0) {
            $Script:Reporting['GPOOrphans']['ActionRequired'] = $true
        } else {
            $Script:Reporting['GPOOrphans']['ActionRequired'] = $false
        }
    }
    Variables      = @{
        NotAvailableInAD            = 0
        NotAvailableOnSysvol        = 0
        NotAvailablePermissionIssue = 0
        ToBeDeleted                 = 0
    }
    Overview       = {
        New-HTMLPanel {
            New-HTMLText -TextBlock {
                "Group Policies are stored in two places - Active Directory (metadata) and SYSVOL (content)."
                "Since those are managed in different ways, replicated in different ways it's possible because of different issues they get out of sync."
            }
            New-HTMLText -Text "For example:"
            New-HTMLList -Type Unordered {
                New-HTMLListItem -Text 'USN Rollback in AD could cause group policies to reappar in Active Directory, yet SYSVOL data would be unavailable'
                New-HTMLListItem -Text 'Group Policy deletion failing to delete GPO content'
                New-HTMLListItem -Text 'DFSR replication failing between DCs'
            }
            New-HTMLText -Text 'Following chart presents ', 'Broken / Orphaned Group Policies' -FontSize 10pt -FontWeight normal, bold
            New-HTMLList -Type Unordered {
                New-HTMLListItem -Text 'Group Policies on SYSVOL, but no details in AD: ', $Script:Reporting['GPOOrphans']['Variables']['NotAvailableInAD'] -FontWeight normal, bold
                New-HTMLListItem -Text 'Group Policies in AD, but no content on SYSVOL: ', $Script:Reporting['GPOOrphans']['Variables']['NotAvailableOnSysvol'] -FontWeight normal, bold
                New-HTMLListItem -Text "Group Policies which couldn't be assed due to permissions issue: ", $Script:Reporting['GPOOrphans']['Variables']['NotAvailablePermissionIssue'] -FontWeight normal, bold
            } -FontSize 10pt
            New-HTMLText -FontSize 10pt -Text 'Those problems must be resolved before doing other clenaup activities.'
            New-HTMLChart {
                New-ChartBarOptions -Type barStacked
                New-ChartLegend -Name 'Not in AD', 'Not on SYSVOL', 'Permissions Issue' -Color Crimson, LightCoral, IndianRed
                New-ChartBar -Name 'Orphans' -Value $Script:Reporting['GPOOrphans']['Variables']['NotAvailableInAD'], $Script:Reporting['GPOOrphans']['Variables']['NotAvailableOnSysvol'], $Script:Reporting['GPOOrphans']['Variables']['NotAvailablePermissionIssue']
            } -Title 'Broken / Orphaned Group Policies' -TitleAlignment center
        }
    }
    Summary        = {
        New-HTMLPanel {
            New-HTMLText -TextBlock {
                "Group Policies are stored in two places - Active Directory (metadata) and SYSVOL (content)."
                "Since those are managed in different ways, replicated in different ways it's possible because of different issues they get out of sync."
            } -FontSize 10pt
            New-HTMLText -Text "For example:" -FontSize 10pt -FontWeight bold
            New-HTMLList -Type Unordered {
                New-HTMLListItem -Text 'USN Rollback in AD could cause already deleted Group Policies to reapper in Active Directory, yet SYSVOL data would be unavailable'
                New-HTMLListItem -Text 'Group Policy deletion failing to delete GPO content'
                New-HTMLListItem -Text 'Permission issue preventing deletion of GPO content'
                New-HTMLListItem -Text 'Failing DFSR replication between DCs'
            } -FontSize 10pt
            New-HTMLText -Text 'Following problems were detected:' -FontSize 10pt -FontWeight bold
            New-HTMLList -Type Unordered {
                New-HTMLListItem -Text 'Group Policies on SYSVOL, but no details in AD: ', $Script:Reporting['GPOOrphans']['Variables']['NotAvailableInAD'] -FontWeight normal, bold
                New-HTMLListItem -Text 'Group Policies in AD, but no content on SYSVOL: ', $Script:Reporting['GPOOrphans']['Variables']['NotAvailableOnSysvol'] -FontWeight normal, bold
                New-HTMLListItem -Text "Group Policies which couldn't be assed due to permissions issue: ", $Script:Reporting['GPOOrphans']['Variables']['NotAvailablePermissionIssue'] -FontWeight normal, bold
            } -FontSize 10pt
            New-HTMLText -Text "Please review output in table and follow the steps below table to get Active Directory Group Policies in healthy state." -FontSize 10pt
        }
    }
    Solution       = {
        New-HTMLSection -Invisible {
            & $Script:GPOConfiguration['GPOOrphans']['Summary']
            New-HTMLPanel {
                New-HTMLChart {
                    New-ChartBarOptions -Type barStacked
                    New-ChartLegend -Name 'Not in AD', 'Not on SYSVOL', 'Permissions Issue' -Color Crimson, LightCoral, IndianRed
                    New-ChartBar -Name 'Orphans' -Value $Script:Reporting['GPOOrphans']['Variables']['NotAvailableInAD'], $Script:Reporting['GPOOrphans']['Variables']['NotAvailableOnSysvol'], $Script:Reporting['GPOOrphans']['Variables']['NotAvailablePermissionIssue']
                } -Title 'Broken / Orphaned Group Policies' -TitleAlignment center
            }
        }
        New-HTMLSection -Name 'Health State of Group Policies' {
            New-HTMLTable -DataTable $Script:Reporting['GPOOrphans']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'Status' -Value "Not available in AD" -BackgroundColor Salmon -ComparisonType string
                New-HTMLTableCondition -Name 'Status' -Value "Not available on SYSVOL" -BackgroundColor LightCoral -ComparisonType string
                New-HTMLTableCondition -Name 'Status' -Value "Permissions issue" -BackgroundColor MediumVioletRed -ComparisonType string -Color White
            } -PagingOptions 10, 20, 30, 40, 50
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
                            New-HTMLText -Text "Using force makes sure newest version is downloaded from PowerShellGallery regardless of what is currently installed. Once installed you're ready for next step."
                        }
                        New-HTMLWizardStep -Name 'Prepare report' {
                            New-HTMLText -Text "Depending when this report was run you may want to prepare new report before proceeding with removal. To generate new report please use:"
                            New-HTMLCodeBlock -Code {
                                Invoke-GPOZaurr -FilePath $Env:UserProfile\Desktop\GPOZaurrBrokenGpoBefore.html -Verbose -Type GPOOrphans
                            }
                            New-HTMLText -TextBlock {
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
                                Invoke-GPOZaurr -FilePath $Env:UserProfile\Desktop\GPOZaurrBrokenGpoAfter.html -Verbose -Type GPOOrphans
                            }
                            New-HTMLText -Text "If everything is healthy in the report you're done! Enjoy rest of the day!" -Color BlueDiamond
                        }
                    } -RemoveDoneStepOnNavigateBack -Theme arrows -ToolbarButtonPosition center
                }
            }
        }
    }
}