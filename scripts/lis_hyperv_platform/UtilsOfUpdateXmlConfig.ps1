

$logfile = ".\test.log"
$dbgLevel = 3


########################################################################
#
# LogMsg()
#
########################################################################
function LogMsg([int]$level, [string]$msg, [string]$colorFlag)
{
    <#
    .Synopsis
        Write a message to the log file and the console.
    .Description
        Add a time stamp and write the message to the test log.  In
        addition, write the message to the console.  Color code the
        text based on the level of the message.
    .Parameter level
        Debug level of the message
    .Parameter msg
        The message to be logged
    .Example
        LogMsg 3 "Info: This is a test"
    #>

    if ($level -le $dbgLevel)
    {
        $now = [Datetime]::Now.ToString("MM/dd/yyyy HH:mm:ss : ")
        ($now + $msg) | out-file -encoding ASCII -append -filePath $logfile
        
        $color = "White"
        if ( $msg.StartsWith("Error"))
        {
            $color = "Red"
        }
        elseif ($msg.StartsWith("Warn"))
        {
            $color = "Yellow"
        }
        else
        {
            $color = "Gray"
        }

		#Print info in specified color
		if( $colorFlag )
		{
			$color = $colorFlag
		}
        
        write-host -f $color "$msg"
    }
}




###########################################################
#
# Delete all IDE and SCSI disks except the OS disk
#
###########################################################

function DeleteDisks([String] $vmName, [String] $hvServer)
{
	$diskDrivers =  Get-VMHardDiskDrive -VMName $vmName -ComputerName $hvServer
	foreach( $driver in $diskDrivers)
	{
		if( $driver.ControllerType -eq "IDE" -and $driver.ControllerNumber -eq 0 -and $driver.ControllerLocation -eq 0 )
		{
			"Skip OS disk: $($driver.ControllerType) $($driver.ControllerNumber) $($driver.ControllerLocation) "
		}
		else
		{
			"To delete: $($driver.ControllerType) $($driver.ControllerNumber) $($driver.ControllerLocation) "
			$sts = Remove-VMHardDiskDrive $driver
			"Delete $($driver.ControllerType) $($driver.ControllerNumber) $($driver.ControllerLocation) done"
		}		
	}
}



###########################################################
#
# Create a snapshot(checkpoint) 
#
###########################################################

function CreateSnapshot([String] $vmName, [String] $hvServer, [String] $snapshotName)
{
	#To create a snapshot named ICABase
	checkpoint-vm -Name $vmName -Snapshotname  $snapshotName -ComputerName $hvServer  -Confirm:$False
	if ($? -eq "True")
    {
		LogMsg 3 "Info: create snapshot $snapshotName on $vmName VM successfully"
    }
    else
    {
		LogMsg 0 "Error: create snapshot $snapshotName on $vmName VM failed"
        return 1
    }

	return 0
}


###########################################################
#
# Stop the VM
#
###########################################################

function DoStopVM([String] $vmName, [String] $server)
{
	$timeout = 120
    while ($timeout -gt 0)
    {
        $v = Get-VM $vmName -ComputerName $server 2>null
        if( -not $v  )
        {
            Write-Error "Error: the vm $vmName doesn't exist!"
            return 1
        }
        
        $vmState = $v.State
        LogMsg 0 "Info : $vmName is in a $vmState state."
        
        # Check the VM is whether in the saving state
        if ($vmState -eq "Saving")
        {
            LogMsg 0 "Warning : $vmName is in a saving state."
            sleep 20
            Remove-VMSavedState  -VMName $vmName -ComputerName $server
        }
        
        # Check the VM is whether in the saved state
        if ($vmState -eq "Saved")
        {
            LogMsg 0 "Warning : $vmName is in a saved state."
            Remove-VMSavedState  -VMName $vmName -ComputerName $server
        }
        
        # If the VM is not stopped, try to stop it
        if ($vmState -ne "Off")
        {
            LogMsg 3 "Info : $vmName is not in a stopped state - stopping VM"
            Stop-VM -Name $vmName -ComputerName $server  -Force 2>null
        }
        
        if ($vmState -eq "Off")
        {
            break
        }

        start-sleep -seconds 3
        $timeout -= 1
    }

    if ($timeout -eq 0)
    {
		Write-Error "Error:failed to stop the vm $vmName"
		return 1
    }
    else
    {
		sleep 3
		Write-Output "Stop vm $vmName successfully."
    }

	return 0
}




