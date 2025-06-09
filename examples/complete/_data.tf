## ----------------------------------------------------------------------------
##  Copyright 2023 SevenPico, Inc.
##
##  Licensed under the Apache License, Version 2.0 (the "License");
##  you may not use this file except in compliance with the License.
##  You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
##  Unless required by applicable law or agreed to in writing, software
##  distributed under the License is distributed on an "AS IS" BASIS,
##  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##  See the License for the specific language governing permissions and
##  limitations under the License.
## ----------------------------------------------------------------------------

## ----------------------------------------------------------------------------
##  ./_data.tf
##  This file contains code written by SevenPico, Inc.
## ----------------------------------------------------------------------------

# The AWS region currently being used.
data "aws_region" "current" {
  count = module.context.enabled ? 1 : 0
}

# The AWS account id
data "aws_caller_identity" "current" {
  count = module.context.enabled ? 1 : 0
}

# The AWS partition (commercial or govcloud)
data "aws_partition" "current" {
  count = module.context.enabled ? 1 : 0
}

locals {
  arn_prefix = "arn:${try(data.aws_partition.current[0].partition, "")}"
  account_id = try(data.aws_caller_identity.current[0].account_id, "")
  region     = try(data.aws_region.current[0].name, "")
}


