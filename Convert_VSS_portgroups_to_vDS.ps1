# ===============================================================================================
# 
# COMMENT: This script gets all the VSS port groups for a given cluster and creates a vDS
# equivalent port group on a given destination dvSwitch.
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================

# Squelching CN Warnings when making initial connection to VCs
# First, capture existing preference
$wpref = $WarningPreference
# Then, set to 'SilentlyContinue'
$WarningPreference="SilentlyContinue"

"Welcome, this script will prompt you to enter a source cluster and destination vDS switch name."
"Then, vDS port groups will be created equivalent to the port groups retrieved from the source VSS"

########################################################
#### Get user input details
do {
	$vc = read-host -prompt "Enter VC to connect to"
} while ($vc -eq "")
do {
	$vmHost = read-host -prompt "Enter source host name (as shown in VIC)"
} while ($Host -eq "")
do {
	$vSS = read-host -prompt "Enter the name of the source vSS switch (e.g. vSwitch0)"
} while ($vSS -eq "")
do {
	$vDS = read-host -prompt "Enter the name of the destination vDS switch (e.g. vDS-40-Cluster_A)"
} while ($vDS -eq "")
# Get user login details if ran from a non-hosted server, comment this section out if running from a hosted server
do {
	$cred = Get-Credential
} while ($cred -eq "")


########################################################
#### Running Script

# Connect to vCenter server (edit this connection if running from a hosted server)
Connect-VIServer -server $vc -Credential $cred

# Get the VSS port groups (not including management port groups)
$vsPG = Get-VirtualPortGroup | where {$_.ExtensionData -like "VMware.Vim.HostPortGroup" -and $_.Name -notlike "VMkernel" -and $_.Name -notlike "VMotion" -and $_.Name -notlike "Management Network"} | select -Unique

# Check if the vDS switch already exists, otherwise create a new one

$gvDS = Get-VDSwitch | where {$_.Name -like $vDS}

If ($gvDS -eq $null){
	"no vDS exists"
} else {
	"vDS already exists"
}

#Get-Cluster -Name $Cluster | Get-VMHost | % 
#{
	$gvSS = Get-VirtualSwitch -VMHost $vmHost -Name $vSS 
	$gvSS | Get-VirtualPortGroup | where {$_.Name -notlike "dvSwitch_X3850X5_NIC_100s"} | % {
		$pg_name = $_.Name
		[int]$vlan_id = $_.VlanId	#$_.ExtensionData.Config.DefaultPortConfig.Vlan.VlanId

		"Portgroup: " + $pg_name

		if ($gvDS | Get-VDPortgroup | where {$_.Name -like $pg_name -and $_.ExtensionData.Config.DefaultPortConfig.Vlan.VlanId -like $vlan_id}) {
			"VLAN already exists on host: " + $_.Name
		} else {
			"VLAN does not exist on host: " + $_.Name + ", adding it now...."
			"vdSwitch: " + $gvDS.Name + ", Portgroup name: " + $pg_name + ", VLAN: " + $vlan_id
			New-VDPortgroup -Vds $gvDS -VlanId $vlan_id -Name $pg_name
			#New-VirtualPortGroup -VirtualSwitch $gvDS -VlanId $vlan_id -Name $pg_name
		}
	}
#}

########################################################
#### End of script, resetting environment

Disconnect-VIServer $vc -Confirm:$false

# Now resetting warning preference to original setting
$WarningPreference = $wpref


