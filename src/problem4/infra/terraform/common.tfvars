region          = "ap-southeast-1"
artifact_bucket = "example-delivery-artifacts"
manifest_bucket = "example-delivery-manifests"

accounts = {
  delivery   = "111122223333"
  staging    = "444455556666"
  production = "777788889999"
}

github = {
  owner    = "example-org"
  owner_id = "1000001"
  repo     = "example-repo"
  repo_id  = "2000002"
}
