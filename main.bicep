@description('Optional. Azure region where the resource should be created. Defaults to the resource group location.')
param parLocation string = resourceGroup().location

@description('Required. The custom location resource ID of the hybrid machine.')
param parCustomLocationName string

@description('Required. The name of the hybrid machine.')
param parName string

@description('Required. The computer name of the hybrid machine.')
param parComputerName string

@allowed([
  'AVS'
  'AWS'
  'EPS'
  'GCP'
  'HCI'
  'SCVMM'
  'VMware'
])
@description('Optional. The kind of the hybrid machine. Defaults to HCI.')
param parKind string = 'HCI'

@allowed([
  'windows'
  'linux'
])
@description('Optional. The operating system type of the hybrid machine. Defaults to windows.')
param parOsType string = 'windows'

@description('Optional. The list of DNS servers of the hybrid machine. Defaults to empty list.')
param parDnsServers array = []

@description('Optional. The private IP address of the hybrid machine.')
param parPrivateIPAddress string?

@allowed([
  'SystemAssigned'
])
@description('Optional. The identity of the hybrid machine.')
param parIdentity string?

@description('Optional. The dynamic memory configuration of the hybrid machine.')
param parDynamicMemoryConfig dynamicMemoryConfigType?

@description('Optional. Memory in MB of the hybrid machine. Defaults to 8192 MB.')
param parMemoryMB int?

@description('Optional. Number of processors of the hybrid machine. Defaults to 4.')
param parProcessors int?

@allowed([
  'Custom'
  'Default'
  'Standard_A2_v2'
  'Standard_A4_v2'
  'Standard_D16s_v3'
  'Standard_D2s_v3'
  'Standard_D32s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
  'Standard_DS13_v2'
  'Standard_DS2_v2'
  'Standard_DS3_v2'
  'Standard_DS4_v2'
  'Standard_DS5_v2'
  'Standard_K8S2_v1'
  'Standard_K8S3_v1'
  'Standard_K8S4_v1'
  'Standard_K8S5_v1'
  'Standard_K8S_v1'
  'Standard_NK12'
  'Standard_NK6'
  'Standard_NV12'
  'Standard_NV6'
])
@description('Optional. The size of the hybrid machine. Defaults to Default.')
param parVmSize string?

@description('Optional. The HTTP proxy configuration of the hybrid machine.')
param parHttpProxyConfig httpProxyConfigType?

@secure()
@description('Required. The admin password of the hybrid machine.')
param parAdminPassword string

@description('Required. The admin username of the hybrid machine.')
param parAdminUsername string

@description('Optional. The security profile of the hybrid machine.')
param parSecurityProfile virtualMachineSecurityProfileType?

@description('Optional. The list of data disk ids of the hybrid machine.')
param parDataDiskIds array?

@description('Required. The image reference id of the hybrid machine.')
param parImageReferenceName string

@description('Required. The resource group name of the VM image reference.')
param parImageReferenceResourceGroup string

@allowed([
  'gallery'
  'marketplace'
])
@description('Optional. The image type of the hybrid machine - gallery or marketplace.')
param parImageType string = 'gallery'

@description('Optional. The osDisk definition of the hybrid machine.')
param parOsDisk osDiskType?

@description('Optional. Id of the storage container that hosts the VM configuration file.')
param parVmConfigStoragePathId string?

@description('Required. Name of AD domain to join the VM.')
param parDomainToJoin string

@description('Required. AD Organizational Unit path for joined VM. Use the distinguished name format: "OU=,DC=,DC=".')
param parOrgUnitPath string

@description('Required. AD user name with domain join rights. Use just the username without domain prefix in UPN format.')
param parDomainJoinUserName string

@secure()
@description('Required. AD domain join user password.')
param parDomainJoinPassword string

@description('Required. Specifies whether to join VM the domain.')
param parJoinDomain bool

@description('Optional. Deploy VM Insights on the hybrid machine. Defaults to true.')
param parDeployVmInsights bool = false

@description('Required. Name of the VM Insights data collection rule.')
param parVmInsightsDataCollectionRuleName string = ''

@description('Required. Resource group name of the central monitoring resources like Log Analytics workspace & Data Collection Rules.')
param parMonitoringResourceGroupName string = ''

@description('Required. The logical network resource name for the VM.')
param parVmLogicalNetworkName string

@description('Required. The resource group name of the custom location resource.')
param parCustomLocationResourceGroupName string

@description('Optional. The tags of the hybrid machine.')
param parTags object?

// - Variables -
var varVmWindowsConfiguration = (parOsType == 'windows') ? {
  enableAutomaticUpdates: true
  provisionVMAgent: true // Arc for Servers agent onboarding
  provisionVMConfigAgent: true // VM Config Agent. The Azure Windows VM Agent has a primary role in enabling and executing Azure virtual machine extensions.
} : null

var varVmLinuxConfiguration = (parOsType == 'linux') ?{
  provisionVMAgent: true
  provisionVMConfigAgent: true
} : null

var varVmPatchSettings = {
  assessmentMode: 'AutomaticByPlatform'
  enableHotpatching: true
  patchMode: 'AutomaticByPlatform'
}


// - Resources -
// -- VM Logical Network --
resource resVmLogicalNetwork 'Microsoft.AzureStackHCI/logicalNetworks@2024-01-01' existing = {
  name: parVmLogicalNetworkName
  scope: resourceGroup(parCustomLocationResourceGroupName)
}

// -- VM Image Reference --
resource resVirtualMachineInstanceGalleryImage 'Microsoft.AzureStackHCI/galleryImages@2024-01-01' existing = if (parImageType == 'gallery') {
  name: parImageReferenceName
  scope: resourceGroup(parImageReferenceResourceGroup)
}

resource resVirtualMachineInstanceMarketplaceImage 'Microsoft.AzureStackHCI/marketplaceGalleryImages@2024-01-01' existing = if (parImageType == 'marketplace') {
  name: parImageReferenceName
  scope: resourceGroup(parImageReferenceResourceGroup)
}

// -- VM Insights --
resource vmInsightsDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2021-04-01' existing = if (parDeployVmInsights) {
  name: parVmInsightsDataCollectionRuleName
  scope: resourceGroup(parMonitoringResourceGroupName)
}

// -- Custom Location --
resource resCustomLocation 'Microsoft.ExtendedLocation/customLocations@2021-08-15' existing = {
  name: parCustomLocationName
  scope: resourceGroup(parCustomLocationResourceGroupName)
}


// -- Hybrid Machine --
resource resHybridMachine 'Microsoft.HybridCompute/machines@2024-05-20-preview' = {
  name: parName
  location: parLocation
  identity: {
    type: 'SystemAssigned'
  }
  kind: parKind
  // tags: parTags
  properties: {
    // agentUpgrade: agentUpgrade
    // clientPublicKey: clientPublicKey
    // extensions: extensions
    // licenseProfile: licenseProfile
    // locationData: locationData
    osProfile: {
      linuxConfiguration: parOsType == 'linux' ? {
        patchSettings: varVmPatchSettings
      } : null
      windowsConfiguration: parOsType == 'windows' ? {
        patchSettings: varVmPatchSettings
      } : null
    }
    // osType: parOsType
    // parentClusterResourceId: parentClusterResourceId
    // privateLinkScopeResourceId: privateLinkScopeResourceId
  }
}

// -- Network Interface --
resource resNetworkInterface 'Microsoft.AzureStackHCI/networkInterfaces@2023-09-01-preview' = {
  name: 'vnic-${parName}'
  location: parLocation
  extendedLocation: {
    name: resCustomLocation.id
    type: 'CustomLocation'
  }
  tags: parTags
  properties: {
    dnsSettings: !empty(parDnsServers) ? {
      dnsServers: parDnsServers
    } : null
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: parPrivateIPAddress
          subnet: {
            id: resVmLogicalNetwork.id
          }
        }
      }
    ]
  }
}

// -- Virtual Machine Instance --
resource resVirtualMachineInstance 'Microsoft.AzureStackHCI/virtualMachineInstances@2023-09-01-preview' = {
  name: 'default'
  extendedLocation: {
    name: resCustomLocation.id
    type: 'CustomLocation'
  }
  scope: resHybridMachine
  identity: !empty(parIdentity) ? {
    type: parIdentity
  } : null
  properties: {
    hardwareProfile: {
      dynamicMemoryConfig: parDynamicMemoryConfig
      memoryMB: parMemoryMB
      processors: parProcessors
      vmSize: parVmSize
    }
    httpProxyConfig: parHttpProxyConfig
    networkProfile: {
      networkInterfaces: [
        {
          id: resNetworkInterface.id
        }
      ]
    }
    osProfile: {
      adminPassword: parAdminPassword
      adminUsername: parAdminUsername
      computerName: parComputerName
      linuxConfiguration: parOsType == 'linux' ? varVmLinuxConfiguration : null
      windowsConfiguration: parOsType == 'windows' ? varVmWindowsConfiguration : null
    }
    securityProfile: parSecurityProfile
    storageProfile: {
      dataDisks: [
        for dataDiskId in (parDataDiskIds ?? []) : {
          id: dataDiskId
        }
      ]
      imageReference: {
        id: (parImageType == 'gallery') ? resVirtualMachineInstanceGalleryImage.id : resVirtualMachineInstanceMarketplaceImage.id
      }
      osDisk: parOsDisk
      vmConfigStoragePathId: parVmConfigStoragePathId
    }
  }
}

// -- Virtual Machine Domain Join extension --
resource resVirtualMachineDomainJoin 'Microsoft.HybridCompute/machines/extensions@2023-06-20-preview' = if (parJoinDomain) {
  name: 'joindomain'
  location: parLocation
  parent: resHybridMachine
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: parDomainToJoin
      OUPath: parOrgUnitPath
      User: parDomainJoinUserName
      Restart: 'true'
      Options: '3'
    }
    protectedSettings: {
      Password: parDomainJoinPassword
    }
  }
}

// -- VM Insights DCR Association --
resource vmInsightsDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = if (parDeployVmInsights) {
  name: '${resHybridMachine.name}-VMInsights-Dcr-Association'
  scope: resHybridMachine
  properties: {
    description: 'Association of data collection rule for VM Insights.'
    dataCollectionRuleId: vmInsightsDataCollectionRule.id
  }
}

// -- VM Insights Extension --
resource vmInsightsExtension 'Microsoft.HybridCompute/machines/extensions@2022-12-27' = if (parDeployVmInsights) {
  name: 'AzureMonitorWindowsAgent'
  parent: resHybridMachine
  location: parLocation
  dependsOn: [
    vmInsightsDataCollectionRuleAssociation
  ]
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    autoUpgradeMinorVersion: true
  }
}

// - Outputs -
output vmName string = resHybridMachine.name
output vmResourceId string = resHybridMachine.id


// - Definitions -
type dynamicMemoryConfigType = {
  @description('The maximum amount of memory that can be allocated to the virtual machine.')
  maximumMemoryMB: int?

  @description('The minimum amount of memory that can be allocated to the virtual machine.')
  minimumMemoryMB: int?

  @description('The target memory buffer for the virtual machine.')
  targetMemoryBuffer: int?
}?

type httpProxyConfigType = {
  @description('The HTTP proxy server address.')
  httpProxy: string?

  @description('The HTTPS proxy server address.')
  httpsProxy: string?

  @description('The list of URLs that should bypass the proxy server.')
  noProxy: string[]?

  @description('The trusted certificate authority (CA) certificates.')
  trustedCa: string?
}?

type osDiskType = {
  @description('The id of the disk.')
  id: string

  @description('The operating system type of the disk.')
  osType: ('Windows' | 'Linux')
}?

type virtualMachineSecurityProfileType = {
  @description('Optional. Specifies whether the Trusted Platform Module (TPM) is enabled.')
  enableTPM: bool?

  @description('Optional. Specifies the SecurityType of the virtual machine. EnableTPM and SecureBootEnabled must be set to true for SecurityType to function.')
  securityType: ('ConfidentialVM' | 'TrustedLaunch')?

  @description('Optional. The UEFI settings of the virtual machine.')
  uefiSettings: {
    @description('Optional. Specifies whether secure boot should be enabled on the virtual machine instance.')
    secureBootEnabled: bool?
  }
}?
