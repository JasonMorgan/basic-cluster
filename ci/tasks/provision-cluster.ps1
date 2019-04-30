#!/usr/bin/pwsh

## Fuck it, use PKS and do a pks login. I need the kubeconfig to be there.
pks login -a $ENV:PKS_URL -u $("$ENV:PKS_USER" -replace "\n","")-p $($ENV:PKS_PASSWORD -replace "\n","") -k
if ($LASTEXITCODE -ne 0) {
  throw "failed to login to pks @ $ENV:PKS_URL with user $ENV:PKS_USER"
}
pks get-credentials $ENV:PKS_CLUSTER

function apply ($file) {
  kubectl apply -f $file # swap to the ca file
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply $file"
  }
}

$ItemTypes = @(
  "customresourcedefinition",
  "namespaces",
  "serviceaccounts",
  "clusterroles",
  "clusterrolebindings",
  "configmaps",
  "rolebindings",
  "roles",
  "secrets",
  "storageclasses",
  "certificatesigningrequests",
  "cronjobs",
  "daemonsets",
  "deployments",
  "endpoints",
  "horizontalpodautoscalers",
  "ingresses",
  "jobs",
  "limitranges",
  "networkpolicies",
  "persistentvolumes",
  "poddisruptionbudgets",
  "podpreset",
  "pods",
  "podsecuritypolicies",
  "podtemplates",
  "replicasets",
  "replicationcontrollers",
  "resourcequotas",
  "services",
  "statefulsets"
)

foreach ($item in $ItemTypes) {
  foreach ($ci in (Get-ChildItem -Path cluster-state/objects/$item -File -recurse)) {
    Write-Output "Creating $($ci.name)"
    try {
      apply -file $ci.fullname
      Write-Output "applied $($ci.name)"
      Write-Output "Content follows:"
      Write-Output "----------------------------------------------"
      Write-Output ""
      cat $ci.fullname
    } catch {
      Write-Output "Failed to apply file: $($ci.name)"
      Write-Output "Content follows:"
      Write-Output "----------------------------------------------"
      Write-Output ""
      cat $ci.fullname
    }
  }
}
<# 
## Helm init
Write-Output "initializing helm"
$null = helm init --service-account tiller
if ($LASTEXITCODE -ne 0) {
  throw "failed to initialize helm"
}
# Handle Charts
foreach ($chart in (Get-ChildItem -Path cluster-state/charts -Directory)) {
  $metadata = cat "$($chart.fullname)/metadata.json" | ConvertFrom-Json
  if (! $metadata.skip) {
    Write-Output "Updating chart: $($metadata.name)"
    $arguments = "--install --namespace $($metadata.namespace) --version $($metadata.version)"
    if ($metadata.values.length -gt 0) {
      $arguments += " -f cluster-state/charts/$($chart.name)/$($metadata.values)"
    }
    Invoke-Expression "helm upgrade $($metadata.name) $($metadata.chart) $arguments"
    if (Test-Path "cluster-state/charts/$($chart.name)/objects") {
      foreach ($ci in (Get-ChildItem -Path "cluster-state/charts/$($chart.name)/objects" -filter *.yml -recurse)) {
        Write-Output "Creating $($ci.name)"
        try {apply -file $ci.fullname} catch {
          Write-Output "Failed to apply file: $($ci.name)"
          Write-Output "Content follows:"
          Write-Output "----------------------------------------------"
          Write-Output ""
          cat $ci.fullname
        }
      }
    }
  }
} #>
exit $LASTEXITCODE