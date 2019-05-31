function New-VMHostAffinityRule{
<#
.SYNOPSIS
Create a new DRSGroupRule for VMs to reside on some hosts in a cluster
.DESCRIPTION
Use this function to create vms in a group and hosts in a group and a host-vm affinity
.PARAMETER  MustRun
A switch that will create the rule with Must Run on these host, if not set it will create the rule with should run.
.NOTES
Author: Niklas Akerlund / RTS (most of the code came from http://communities.vmware.com/message/1667279 @LucD22 and GotMoo)
Date: 2012-06-28
Modiefied by: Tommy Song, 2016-06-17
#>
        param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$True)]
        $VcenterName,
        $cluster,
        $VMHost,
        $VM,
        [string]$Name,
        [switch]$MustRun
        )
        
        If ((Get-Module -Name "VMware.VimAutomation.Core") -eq $null) {
                Try {
                        Import-Module -Name "VMware.VimAutomation.Core" -ErrorAction Stop
                }
                Catch {
                        Send-Alert -Subject "Failed to import module: VMware.VimAutomation.Core" -Body $_.Exception.Message
                        Return
                }
        }
        
        # Connect to vCenter if not already connected
        While ( $global:DefaultVIServer.Name -ne $VcenterName -or -not $global:DefaultVIServer.IsConnected ) {
                Try {
                        Connect-VIServer -Server $VcenterName -ErrorAction Stop
                }
                Catch {
                        Send-Alert -Subject "Failed to connect to vCenter: $VcenterName" -Body $_.Exception.Message
                        Return
                }
        }
        
        $cluster = Get-Cluster $cluster
        
        $spec = New-Object VMware.Vim.ClusterConfigSpecEx
        $groupVM = New-Object VMware.Vim.ClusterGroupSpec
        $groupVM.operation = "add"
        $groupVM.Info = New-Object VMware.Vim.ClusterVmGroup
        $groupVM.Info.Name = "VM-$Name"
        
        Get-VM $VM | %{
                $groupVM.Info.VM += $_.Extensiondata.MoRef
        }
        $spec.GroupSpec += $groupVM
        
        $groupESX = New-Object VMware.Vim.ClusterGroupSpec
        $groupESX.operation = "add"
        $groupESX.Info = New-Object VMware.Vim.ClusterHostGroup
        $groupESX.Info.Name = "Host-$Name"
        
        Get-VMHost $VMHost | %{
                $groupESX.Info.Host += $_.Extensiondata.MoRef
        }
        $spec.GroupSpec += $groupESX
        
        $rule = New-Object VMware.Vim.ClusterRuleSpec
        $rule.operation = "add"
        $rule.info = New-Object VMware.Vim.ClusterVmHostRuleInfo
        $rule.info.enabled = $true
        $rule.info.name = $Name
        if($MustRun){
                $rule.info.mandatory = $true
        }else{
                $rule.info.mandatory = $false
        }
        $rule.info.vmGroupName = "VM-$Name"
        $rule.info.affineHostGroupName = "Host-$Name"
        $spec.RulesSpec += $rule
        
        $cluster.ExtensionData.ReconfigureComputeResource($spec,$true)
}