# Configure the Confluent Provider
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.47.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "platform-engineering-terraform-state"
    key    = "terraform/all-state/data-streaming-platform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
  sensitive = "true"
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive = "true"
}

provider "confluent" {
  cloud_api_key       = var.confluent_cloud_api_key
  cloud_api_secret    = var.confluent_cloud_api_secret
}


resource "confluent_environment" "staging" {
  display_name = "Staging"

  /*lifecycle {
    prevent_destroy = true
  }*/
}

resource "confluent_kafka_cluster" "standard" {
  display_name = "standard_kafka_cluster"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-east-2"
  standard {}

  environment {
    id = confluent_environment.staging.id
  }

  /*lifecycle {
    prevent_destroy = true
  }*/
}


resource "confluent_service_account" "platform-manager" {
  display_name = "platform-manager"
  description  = "Service account to manage the platform"
}

resource "confluent_role_binding" "platform-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.platform-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.standard.rbac_crn
}


resource "confluent_api_key" "platform-manager-kafka-api-key" {
  display_name = "platform-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'platform-manager' service account"
  owner {
    id          = confluent_service_account.platform-manager.id
    api_version = confluent_service_account.platform-manager.api_version
    kind        = confluent_service_account.platform-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.standard.id
    api_version = confluent_kafka_cluster.standard.api_version
    kind        = confluent_kafka_cluster.standard.kind

    environment {
      id = confluent_environment.staging.id
    }
  }
  # The goal is to ensure that confluent_role_binding.app-manager-kafka-cluster-admin is created before
  # confluent_api_key.app-manager-kafka-api-key is used to create instances of
  # confluent_kafka_topic, confluent_kafka_acl resources.

  # 'depends_on' meta-argument is specified in confluent_api_key.app-manager-kafka-api-key to avoid having
  # multiple copies of this definition in the configuration which would happen if we specify it in
  # confluent_kafka_topic, confluent_kafka_acl resources instead.
  depends_on = [
    confluent_role_binding.platform-manager-kafka-cluster-admin
  ]
}