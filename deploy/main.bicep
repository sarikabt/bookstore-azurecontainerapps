@description('The location where we will deploy our resources to. Default is the location of the resource group')
param location string = resourceGroup().location

@description('Name of our application.')
param applicationName string = uniqueString(resourceGroup().id)

@description('The name of the api container image that we will deploy to this container app')
param apiContainerImageName string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('The name of the web container image that we will deploy to this container app')
param webContainerImageName string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('The name of the Publisher for APIM')
param publisherName string

@description('The publisher email for APIM')
param publisherEmail string

var logAnalyticsWorkspaceName = 'logs-${applicationName}'
var logAnalyticsWorkspaceSkuName = 'PerGB2018'
var appInsightsName = 'appsins-${applicationName}'
var containerRegistryName = 'acr${applicationName}'
var containerRegistrySkuName = 'Basic'
var environmentName = 'env-${applicationName}'
var containerWebAppName = 'bookstoreweb'
var containerApiAppName = 'bookstoreapi'
var apimInstanceName = 'apim-${applicationName}'
var apimSkuName = 'Developer'
var cosmosDbAccountName = 'cosmosdb-${applicationName}'
var bookDatabaseName = 'BooksDB'
var bookContainerName = 'Books'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSkuName
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: containerRegistryName
  location: location 
  sku: {
    name: containerRegistrySkuName
  }
  properties: {
    adminUserEnabled: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource environment 'Microsoft.App/managedEnvironments@2022-01-01-preview' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource bookstoreApiContainerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: containerApiAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      secrets: [
        {
          name: 'registrypassword'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'cosmosdbendpoint'
          value: cosmosDbAccount.properties.documentEndpoint
        }
        {
          name: 'databasename'
          value: database.name
        }
        {
          name: 'containername'
          value: container.name
        }
        {
          name: 'appinsightsinstrumentationkey'
          value: appInsights.properties.InstrumentationKey 
        }
        {
          name: 'appinsightsconnectionstring'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'registrypassword'
        }
      ]
      ingress: {
        external: false
        targetPort: 443
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          image: apiContainerImageName
          name: containerApiAppName
          resources: {
            cpu: '0.5'
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource bookstoreWebContainerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: containerWebAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      secrets: [
        {
          name: 'registrypassword'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'registrypassword'
        }
      ]
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          image: webContainerImageName
          name: containerWebAppName
          resources: {
            cpu: '0.5'
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimInstanceName
  location: location
  sku: {
    capacity: 1
    name: apimSkuName
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-11-15-preview' = {
  name: cosmosDbAccountName
  location: location
  properties: {
    databaseAccountOfferType: 'Standard' 
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    enableAnalyticalStorage: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-11-15-preview' = {
  name: bookDatabaseName
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: bookDatabaseName
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-11-15-preview' = {
  name: bookContainerName
  parent: database
  properties: {
    resource: {
      id: bookContainerName
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
    options: {
      autoscaleSettings: {
        maxThroughput: 4000
      }
    }
  }
}

module sqlRoleAssignment 'modules/sqlRoleAssignment.bicep' = {
  name: 'sqlRoleAssignment'
  params: {
    cosmosDbAccountName: cosmosDbAccount.name
    principalId: bookstoreApiContainerApp.identity.principalId
  }
}
