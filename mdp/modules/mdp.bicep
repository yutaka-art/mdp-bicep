param __location__ string
param _devCenterName_ string
param _devCenterProjectName_ string
param _managedDevOpsPoolName_ string
param _vnetManagedDevOpsPoolName_ string
param _pipNatGatewayName_ string
param _natGatewayName_ string
param __devOpsOrganizationName__ string
param __devOpsProjectName__ string
param __devOpsInfrastructureSpId__ string

@description('Dev Center Deployment')
resource devCenter 'Microsoft.DevCenter/devcenters@2025-02-01' = {
  name: _devCenterName_
  location: __location__
}

resource devCenterProject 'Microsoft.DevCenter/projects@2025-02-01' = {
  name: _devCenterProjectName_
  location: __location__
  properties: {
    devCenterId: devCenter.id
  }
}

@description('Virtual Network Deployment')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: _vnetManagedDevOpsPoolName_
  location: __location__
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.30.0/24'
      ]
    }
    subnets: [
      {
        name: 'snet-mdp-prod'
        properties: {
          addressPrefix: '10.20.30.0/24'
          natGateway: {
             id: natGateway.id
          }
          delegations: [
            {
              name: 'Microsoft.DevOpsInfrastructure/pools'
              properties: {
                serviceName: 'Microsoft.DevOpsInfrastructure/pools'
              }
            }
          ]
        }
      }
    ]
  }
}

@description('Role Assignments Deployment')
resource networkContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: virtualNetwork
  name: guid(virtualNetwork.id, 'Network Contributor', '${__devOpsInfrastructureSpId__}')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7') // Network Contributor role ID
    principalId: __devOpsInfrastructureSpId__
  }
}

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: virtualNetwork
  name: guid(virtualNetwork.id, 'Reader', '${__devOpsInfrastructureSpId__}')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader role ID
    principalId: __devOpsInfrastructureSpId__
  }
}

@description('Public IP Address Deployment')
resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: _pipNatGatewayName_
  location: __location__
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}

@description('NAT Gateway Deployment')
resource natGateway 'Microsoft.Network/natGateways@2024-07-01' = {
  name: _natGatewayName_
  location: __location__
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [{
        id: publicIPAddress.id
      }]
  }
  sku: {
    name: 'Standard'
  } 
}

@description('Managed DevOps Pool Deployment')
resource managedDevOpsPool 'Microsoft.DevOpsInfrastructure/pools@2025-01-21' = {
  name: _managedDevOpsPoolName_
  location: __location__ 
  properties: {
    agentProfile: {
      kind: 'Stateful'
    }
    devCenterProjectResourceId: devCenterProject.id
    fabricProfile: {
      sku: {
        name: 'Standard_B2ms'
      }
      kind: 'Vmss'
      images: [
        {
          wellKnownImageName: 'windows-2022/latest'
        }
      ]
      networkProfile: {
        subnetId: virtualNetwork.properties.subnets[0].id
      }
    }
    maximumConcurrency: 1
    organizationProfile: {
      kind: 'AzureDevOps'
      organizations: [
        {
          url: 'https://dev.azure.com/${__devOpsOrganizationName__}'
          projects: [
            __devOpsProjectName__
          ]
        }
      ]
    }
  }
}
