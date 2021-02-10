provider "google" {
  #credentials = file(local.credentials_file_path)
  version = "~> 3.30"
}

provider "google-beta" {
  #credentials = file(local.credentials_file_path)
  version = "~> 3.38"
}

provider "null" {
  version = "~> 2.1"
}
