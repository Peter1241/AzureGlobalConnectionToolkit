﻿  Param(
    [Parameter(Mandatory=$false)]
    [PSObject] $vm,

    [Parameter(Mandatory=$false)]
    [String] $destEnvironment,
  
    [Parameter(Mandatory=$false)]
    [String] $targetLocation,

    [Parameter(Mandatory=$false)]
    [PSObject] $SrcContext,

    [Parameter(Mandatory=$false)]
    [PSObject] $DestContext,

    [Parameter(Mandatory=$false)]
    [ValidateSet("Validate", "Prepare", "VhdCopy", "VMBuild", "Rename", "All")]
    [String] $JobType = "All",

    [Parameter(Mandatory=$false)]
    [Object[]]
    $RenameInfos, 

    [Parameter(Mandatory=$false)]
    [String] $osDiskUri,

    [Parameter(Mandatory=$false)]
    [String[]] $dataDiskUris
  )

  ##Parameter Type Check
  if ( $vm -ne $null )
  {
    if ( $vm.GetType().FullName -ne "Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine" )
    {
      Throw "-vm : parameter type is invalid. Please enter the right parameter type." 
    }
  }

  if ( $SrcContext -ne $null )
  {
    if ( $SrcContext.GetType().FullName -ne "Microsoft.Azure.Commands.Profile.Models.PSAzureContext" )
    {
      Throw "-SrcContext : parameter type is invalid. Please enter the right parameter type."
    }
  }

  if ( $DestContext -ne $null )
  {
    if ( $DestContext.GetType().FullName -ne "Microsoft.Azure.Commands.Profile.Models.PSAzureContext" )
    {
      Throw "-DestContext : parameter type is invalid. Please enter the right parameter type."
    }
  }
  
  if ($RenameInfos.Count -ne 0)
  {
    ForEach( $RenameInfo in $RenameInfos )
    {
      if ( $RenameInfo.GetType().FullName -ne "ResourceProfile" )
      {
        Throw "-RenameInfos : parameter type is invalid. Please enter the right parameter type: ResourceProfile"
      }
    }
  }

  Function Check-AzureRmMigrationPSRequirement
  {
    $moduleList = Get-Module -ListAvailable

    $AzureRmStorage = $moduleList | Where-Object { $_.Name -eq "AzureRm.Storage" }
    $AzureRmCompute = $moduleList | Where-Object { $_.Name -eq "AzureRm.Compute" }
    $AzureRMNetwork = $moduleList | Where-Object { $_.Name -eq "AzureRm.Network" }
    $AzureRMProfile = $moduleList | Where-Object { $_.Name -eq "AzureRm.Profile" }

    function Check-AzurePSModule
    {
      Param( [PSObject] $module )

      if ( $module -eq $null )
      { Throw "AzureRm PowerShell Module does not successfully install on PowerShell Environment. Please Install before execute this script." }

      if ( !(($module.Version.Major -ge 2) -or (($module.Version.Major -eq 1) -and ( $module.Version.Minor -ge 7 ))) )
      { Throw "This script requires AzureRm PowerShell version higher than 1.7.0. Please install the latest Azure Powershell before execute this script." }
    
    }

    Check-AzurePSModule -module $AzureRmStorage
    Check-AzurePSModule -module $AzureRmCompute
    Check-AzurePSModule -module $AzureRMNetwork
    Check-AzurePSModule -module $AzureRMProfile
  }

  ##PS Module Check
  Check-AzureRmMigrationPSRequirement

  #Define Azure Environment
  Enum AzureEnvironment
  {
    AzureCloud = 0
    AzureChinaCloud = 1
    AzureGermanCloud = 2
    AzureUSGovernment = 3
  }

 $showform = {
    Function Show-Form
      {
        Param(
          [Parameter(Mandatory=$True)]
          [String] $title,

          [Parameter(Mandatory=$True)]
          [String[]] $options,

          [Switch]
          $MultipleChoice
        )
  
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 

        $objForm = New-Object System.Windows.Forms.Form 
        $objForm.Text = "Azure Global Connection Center"
        $objForm.Size = New-Object System.Drawing.Size(700,500) 
        $objForm.StartPosition = "CenterScreen"

        $objForm.KeyPreview = $True

        $objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
            {
              $objForm.DialogResult = "OK"
              $objForm.Close()
            }
        })

        $objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
        {$objForm.Close()}})

        $objForm.BackColor = "#1F4E79"

        $Buttonfont = New-Object System.Drawing.Font("Arial",16,[System.Drawing.FontStyle]::Bold)
        $OKButton = New-Object System.Windows.Forms.Button
        $OKButton.Location = New-Object System.Drawing.Size(10,400)
        $OKButton.Size = New-Object System.Drawing.Size(180,40)
        $OKButton.Text = "OK"
        $OKButton.Font = $Buttonfont
        $OKButton.BackColor = "Gainsboro"

        $OKButton.Add_Click(
          {    
            $objForm.DialogResult = "OK"
            $objForm.Close()
        })

        $objForm.Controls.Add($OKButton)

        $CancelButton = New-Object System.Windows.Forms.Button
        $CancelButton.Location = New-Object System.Drawing.Size(200,400)
        $CancelButton.Size = New-Object System.Drawing.Size(180,40)
        $CancelButton.Text = "Cancel"
        $CancelButton.Font = $Buttonfont
        $CancelButton.BackColor = "Gainsboro"

        $CancelButton.Add_Click({$objForm.Close()})
        $objForm.Controls.Add($CancelButton)

        $objFont = New-Object System.Drawing.Font("Arial",16,[System.Drawing.FontStyle]::Italic)
        $objLabel = New-Object System.Windows.Forms.Label
        $objLabel.Location = New-Object System.Drawing.Size(10,20) 
        $objLabel.AutoSize = $True
        $objLabel.BackColor = "Transparent"
        $objLabel.ForeColor = "White"
        $objLabel.Font = $objFont
        $objLabel.Text = $title
        $objForm.Controls.Add($objLabel) 

        $objListbox = New-Object System.Windows.Forms.Listbox 
        $objListbox.Location = New-Object System.Drawing.Size(10,70) 
        $objListbox.Size = New-Object System.Drawing.Size(650,30) 

        if($MultipleChoice)
        {
          $objListbox.SelectionMode = "MultiExtended"
        }

        foreach ( $option in $options ) {
          [void] $objListbox.Items.Add($option)
        }

        $objlistfont = New-Object System.Drawing.Font("Arial",14,[System.Drawing.FontStyle]::Regular)
        $objListbox.Font = $objlistfont
        $objListbox.Height = 320
        $objForm.Controls.Add($objListbox) 


        $objForm.Add_Shown({$objForm.Activate()})
        [void] $objForm.ShowDialog()
        if ( $objForm.DialogResult -eq "OK" ) {

          $responses = @()
          foreach ( $selection in $objListbox.SelectedItems ) {
            $responses+= $selection
          }

          $objForm.Dispose()

        }

        if ($responses.Count -eq 0)
        {
          $objForm.Dispose()
          Break
        }

        return $responses
      }
  }

  Function SelectionBox
  {
    Param(
      [Parameter(Mandatory=$True)]
      [String] $title,

      [Parameter(Mandatory=$True)]
      [String[]] $options,

      [Switch]
      $MultipleChoice
    )
    if($MultipleChoice){
        $result = Start-Job -InitializationScript $showform -ScriptBlock {Show-Form -title $args[0] -options $args[1] -MultipleChoice $args[2]} -ArgumentList $title,$options,$MultipleChoice | Receive-Job -Wait -AutoRemoveJob
    }
    else{
        $result = Start-Job -InitializationScript $showform -ScriptBlock {Show-Form -title $args[0] -options $args[1]} -ArgumentList $title,$options | Receive-Job -Wait -AutoRemoveJob
    }
    return $result
  }

  ##Get the parameter if not provided
  Try
  {
    if ( $SrcContext -eq $null )
    {
      $SrcEnv = SelectionBox -title "Please Select the Source Environment" -options ("Global Azure", "Germany Azure", "China Azure")
      Switch ( $SrcEnv )
      {
        "China Azure" { $SrcEnvironment = [AzureEnvironment] "AzureChinaCloud" }
        "Germany Azure" { $SrcEnvironment = [AzureEnvironment] "AzureGermanCloud" }
        "Global Azure" { $SrcEnvironment = [AzureEnvironment] "AzureCloud" }
      }

      [Windows.Forms.MessageBox]::Show("Please Enter " + $SrcEnv + " credential after click OK", "Azure Global Connection Center", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information) | Out-Null
      Add-AzureRmAccount -EnvironmentName $SrcEnvironment | Out-Null

      $subscriptions = Get-AzureRmSubscription
      $subList = @()

      ForEach ( $sub in $subscriptions )
      {
        $subList += $sub.SubscriptionName
      }

      $subscription = SelectionBox -title "Please Select the Source Subscription" -options $subList

      Select-AzureRmSubscription -SubscriptionName $Subscription | Out-Null

      $SrcContext = Get-AzureRmContext
    }


    if ($destContext -eq $null )
    {
      if ([string]::IsNullOrEmpty($destEnvironment))
      {
        $destEnv = SelectionBox -title "Please Select the Destination Environment" -options ("China Azure", "Germany Azure", "Global Azure")
        Switch ( $destEnv )
        {
          "China Azure" { $destEnvironment = [AzureEnvironment] "AzureChinaCloud" }
          "Germany Azure" { $destEnvironment = [AzureEnvironment] "AzureGermanCloud" }
          "Global Azure" { $destEnvironment = [AzureEnvironment] "AzureCloud" }
        }
      }
      else
      {
        $destEnvironment = [AzureEnvironment] $destEnvironment
      }

      [Windows.Forms.MessageBox]::Show("Please Enter " + $destEnv + " credential after click OK", "Azure Global Connection Center", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information) | Out-Null
      Add-AzureRmAccount -EnvironmentName $destEnvironment | Out-Null

      $subscriptions = Get-AzureRmSubscription
      $subList = @()

      ForEach ( $sub in $subscriptions )
      {
        $subList += $sub.SubscriptionName
      }

      $subscription = SelectionBox -title "Please Select the Desitnation Subscription" -options $subList

      Select-AzureRmSubscription -SubscriptionName $Subscription | Out-Null

      $destContext = Get-AzureRmContext
    }

    if ( $vm -eq $null )
    {
      Set-AzureRmContext -Context $SrcContext | Out-Null

      $vms = Get-AzureRmVM
      $vmList = @()

      ForEach ( $v in $vms )
      {
        $vmDescription = $v.Name + "(Resource Group:" + $v.ResourceGroupName +")"
        $vmList += $vmDescription
      }

      $vmSelected = SelectionBox -title "Please Select the VM to Migrate" -options $vmList

      $vmName = $vmSelected.Split("(")[0]
      $vmResourceGroupName = $vmSelected.Split(":")[1].Replace(")","")

      $vm = Get-AzureRmVM -ResourceGroupName $vmResourceGroupName -Name $vmName
  
    }


    if ([string]::IsNullOrEmpty($targetLocation))
    {
      Set-AzureRmContext -Context $DestContext | Out-Null
  
      $locations = Get-AzureRmLocation
      $locationList = @()

      ForEach ( $loc in $locations )
      {
        $locationList += $loc.DisplayName
      }

      $Location = SelectionBox -title "Please Select the Destination Location" -options $locationList
      $targetLocation = ($locations | Where-Object { $_.DisplayName -eq $Location }).Location
    }
    else
    {
      Set-AzureRmContext -Context $DestContext | Out-Null
  
      $locations = Get-AzureRmLocation

      $locationCheck = $locations | Where-Object { ($_.DisplayName -eq $targetLocation) -or ( $_.Location -eq $targetLocation ) }

      if ( $locationCheck -eq $null )
      {
        Throw ( "The targetLocation " + $targetLocation + " is invalid." )
      }

      $targetLocation = $locationCheck.Location
    }
    
    if ($RenameInfos -eq $null)
    {
      $RenameInfos = .\Rename.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext
    }

  }
  Catch
  {
    Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
    Throw "Input Parameters are not set correctly. Please try again."
  }




  Switch($JobType)
  {
    ##Validation Only
    "Validate"
    {
      Try
      {
        $validationResult = .\Validate.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext -DestContext $DestContext -RenameInfos $RenameInfos
      }
      Catch
      {
        Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
        Throw "Validation Failed. Please check the error message and try again."
      }
      return $validationResult
    }

    ##Prepare Only
    "Prepare"
    {
      Try
      {
        .\Preparation.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext -DestContext $destContext -RenameInfos $RenameInfos
      }
      Catch
      {
        Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
        Throw "Preparation Failed. Please check the error message and try again."
      }
      break
    }

    ##VHD Copy Only
    "VhdCopy"
    {
      Try
      { 
        $diskUris = .\CopyVhds.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext -DestContext $destContext -RenameInfos $RenameInfos
      }
      Catch
      {
        Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
        Throw "Vhd Copy Failed. Please check the error message and try again."
      }
      return $diskUris
    }

    ##VMBuild Only
    "VMBuild"
    {
      if([String]::IsNullOrEmpty($osDiskUri) )
      {
        Throw ( "-osDiskUri Parameter is null or empty. Please input correct value." )
      }
    
      Try
      {
        .\VMBuild.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext -DestContext $destContext -osDiskUri $osDiskUri -dataDiskUris $dataDiskUris -RenameInfos $RenameInfos
      }
      Catch
      {
        Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
        Throw "VM Building Failed. Please check the error message and try again."
      } 
    }
    
    #Rename Only
    "Rename"
    {
      Try
      {
        $RenameInfos = .\Rename.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext
      }
      Catch
      {
        Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
        Throw "Rename Failed. Please check the error message and try again."
      }
      
      return $RenameInfos
    }
  }

  ##Confirm and Deploy
  $migrationConfirmation = [System.Windows.Forms.MessageBox]::Show("Migrate virtual machine: " + $vm.Name + "(ResourceGroup:" + $vm.ResourceGroupName + ")?" , "Azure Global Connection Center" , 4)

  if ($migrationConfirmation -eq "Yes")
  {
    Write-Progress -id 0 -activity ($vm.Name + "(ResourceGroup:" + $vm.ResourceGroupName + ")" ) -status "Migration Started" -percentComplete 0

    Try
    {
      $validationResult = .\Validate.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext -DestContext $DestContext -RenameInfos $RenameInfos
    }
    Catch
    {
      Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
      Throw "Validation Failed. Please check the error message and try again."
    }
    
    if ($validationResult.Result -eq "Failed")
    {
      return $validationResult
    }
  
    Try
    {
      .\Preparation.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext -DestContext $destContext -RenameInfos $RenameInfos
    }
    Catch
    {
      Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
      Throw "Preparation Failed. Please check the error message and try again."
    }
    
    Try
    {
      $diskUris = .\CopyVhds.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext -DestContext $destContext -RenameInfos $RenameInfos
    }
    Catch
    {
      Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
      Throw "Vhd Copy Failed. Please check the error message and try again."
    }
    
    Try
    {
      .\VMBuild.ps1 -vm $vm -targetLocation $targetLocation -SrcContext $SrcContext -DestContext $destContext -osDiskUri $diskUris.osDiskUri -dataDiskUris $diskUris.dataDiskUris -RenameInfos $RenameInfos
    }
    Catch
    {
      Write-Host ($_.CategoryInfo.Activity + " : " + $_.Exception.Message) -ForegroundColor Red
      Throw "VM Building Failed. Please check the error message and try again."
    }
    Write-Progress -id 0 -activity ($vm.Name + "(ResourceGroup:" + $vm.ResourceGroupName + ")" ) -status "Migration Succeeded" -percentComplete 100
  
    return ($vm.Name + "(ResourceGroup:" + $vm.ResourceGroupName + ")" + "Migration Succeeded")
  }