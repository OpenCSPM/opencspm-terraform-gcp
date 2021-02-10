provider "google" {
  #credentials = file(local.credentials_file_path)
}

provider "google-beta" {
  #credentials = file(local.credentials_file_path)
}

provider "null" {
}

provider "random" {
}
