Function Get-BatchJob($jobName, $context) {
    if ($null -eq (Get-AzBatchJob -Id $jobName -Context $context -ErrorAction SilentlyContinue)) {
        New-AzBatchJob -Id $jobName -DisplayName $jobName -Context $context
    }
    else {
        Get-AzBatchJob -Id $jobName -Context $context
    }
}


bicep build .\main.bicep

$result = New-AzSubscriptionDeployment -Name 'batch-support-request' -Location westeurope -TemplateFile .\main.json

Read-Host "Waiting for pool start. press enter when it's done"

if ($result.ProvisioningState -eq 'Succeeded') {

    # Azure CLI upload in Azure Storage : https://github.com/Azure/azure-cli/releases/download/azure-cli-2.22.1/azure-cli-2.22.1.msi

    $containerName = "tools"
    $fileName = "azure-cli.msi"
    $azureCli = "https://github.com/Azure/azure-cli/releases/download/azure-cli-2.22.1/azure-cli-2.22.1.msi"

    $storageContext = New-AzStorageContext -StorageAccountName $result.outputs.storageName.value -StorageAccountKey $result.outputs.storageKey.value

    if ($null -eq (Get-AzStorageContainer -Name $containerName -Context $storageContext -ErrorAction SilentlyContinue)) {
        New-AzStorageContainer -Name $containerName -Context $storageContext -Permission Off
    }

    If ($null -eq (Get-AzStorageBlob -Blob $fileName -Container $containerName -Context $storageContext -ErrorAction SilentlyContinue)) {
        Invoke-WebRequest -Uri $azureCli -UseBasicParsing -OutFile $fileName

        Set-AzStorageBlobContent -File $fileName -Container $containerName -Context $storageContext
    }

    $token = New-AzStorageBlobSASToken -Blob $fileName -Container $containerName -Context $storageContext -StartTime (Get-Date).AddDays(-1) -ExpiryTime (Get-Date).AddDays(1) -Permission r
    $sasToken = "https://$($result.outputs.storageName.value).blob.core.windows.net/$containerName/$fileName$token"


    # Create Job for Batch Accounts
    $batchContext = Get-AzBatchAccount -AccountName $result.outputs.batchName.value  
    
    # Working Job 
    $workingJobName = "working-job"
    $workingPoolName = "pool-fwl-rot"
    
    $workingJob = (Get-AzBatchJob -Id $workingJobName -BatchContext $batchContext -ErrorAction SilentlyContinue)
    if ($null -eq $workingJob) {
        $poolInformation = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSPoolInformation"
        $poolInformation.PoolId = $workingPoolName

        New-AzBatchJob -Id $workingJobName -Pool $poolInformation -BatchContext $batchContext
    }

    # Failed Job
    $failedJobName = "failed-job"
    $failedPoolName = "pool-fwlbatch-rot"
        
    $failedJob = (Get-AzBatchJob -Id $failedJobName -BatchContext $batchContext -ErrorAction SilentlyContinue)
    if ($null -eq $failedJob) {
        $poolInformation = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSPoolInformation"
        $poolInformation.PoolId = $failedPoolName
    
        New-AzBatchJob -Id $failedJobName -Pool $poolInformation -BatchContext $batchContext
    }


    # Init Task for Azure CLI
    $initTaskName = "init-azure-cli"
    

    # Working Job

    $task = Get-AzBatchTask -JobId $workingJobName -BatchContext $batchContext -Id $initTaskName -ErrorAction SilentlyContinue

    if ($null -eq $task) {
        $autoUser = New-Object Microsoft.Azure.Commands.Batch.Models.PSAutoUserSpecification -ArgumentList @("Task", "Admin")
        $userIdentity = New-Object Microsoft.Azure.Commands.Batch.Models.PSUserIdentity $autoUser
        $file = New-AzBatchResourceFile -HttpUrl $sasToken -FilePath "azure-cli.msi"
        New-AzBatchTask -Id $initTaskName -BatchContext $batchContext -JobId $workingJobName -UserIdentity $userIdentity -ResourceFiles $file -CommandLine "cmd.exe /C msiexec.exe /I azure-cli.msi /quiet"
    }

    # Failed Job

    $task = Get-AzBatchTask -JobId $failedJobName -BatchContext $batchContext -Id $initTaskName -ErrorAction SilentlyContinue

    if ($null -eq $task) {
        $autoUser = New-Object Microsoft.Azure.Commands.Batch.Models.PSAutoUserSpecification -ArgumentList @("Task", "Admin")
        $userIdentity = New-Object Microsoft.Azure.Commands.Batch.Models.PSUserIdentity $autoUser
        $file = New-AzBatchResourceFile -HttpUrl $sasToken -FilePath "azure-cli.msi"
        New-AzBatchTask -Id $initTaskName -BatchContext $batchContext -JobId $failedJobName -UserIdentity $userIdentity -ResourceFiles $file -CommandLine "cmd.exe /C msiexec.exe /I azure-cli.msi /quiet"
    }

    # Test Task for Azure CLI Management API access
    $batchApiTaskName = "test-azure-batchapi-cnx"
    

    # Working Job

    $task = Get-AzBatchTask -JobId $workingJobName -BatchContext $batchContext -Id $batchApiTaskName -ErrorAction SilentlyContinue

    if ($null -eq $task) {
        $settings = @{"batchKey" = $result.Outputs.batchKey.Value}
        New-AzBatchTask -Id $batchApiTaskName -BatchContext $batchContext -JobId $workingJobName -EnvironmentSettings $settings -CommandLine "cmd.exe /C az batch pool list --account-endpoint %AZ_BATCH_ACCOUNT_URL% --account-key %batchKey% --account-name %AZ_BATCH_ACCOUNT_NAME%"
    }

    # Failed Job

    $task = Get-AzBatchTask -JobId $failedJobName -BatchContext $batchContext -Id $batchApiTaskName -ErrorAction SilentlyContinue

    if ($null -eq $task) {
        $settings = @{"batchKey" = $result.Outputs.batchKey.Value}
        New-AzBatchTask -Id $batchApiTaskName -BatchContext $batchContext -JobId $failedJobName -EnvironmentSettings $settings -CommandLine "cmd.exe /C az batch pool list --account-endpoint %AZ_BATCH_ACCOUNT_URL% --account-key %batchKey% --account-name %AZ_BATCH_ACCOUNT_NAME%"
    }
}