/* 
<<< INPUT MAP >>>
code_pipelines = {
  "service1" = [
    "container1",
    "container2",
  ]
  "service3" = [
    "container3",
  ]
}

<<< OUTPUT >>>
codepipeline[0]
name = "service1"
..
stage {
  name = "container1"
}
..
stage {
  name = "container1"
}
..

codepipeline[1]
name = "service2"
..
stage {
  name = "container2"
}
..
stage {
  name = "container2"
}
..

<<< EXPECTED OUTPUT >>>
codepipeline[0]
name = "service1"
..
stage {
  name = "container1"
}
..
stage {
  name = "container2"
}
..
codepipeline[1]
name = "service2"
..
stage {
  name = "container3"
}
..
*/

locals {
  // load only keys: service1, service2
  // problem: using this loop the new stage creates with same container
  // the next one creates only with loop a key
  pipeline_names = flatten([
    for service in keys(var.code_pipelines) : {
        service   = service
      }
  ])

  service_names = flatten([
    // load the all map: service1 = [ "container1", "container2" ]
    // problem: the keys are duplicated when multiple containers used; 
    // it creates duplicated resources
    for service, containers in var.code_pipelines : [
      for container in containers : {
        service   = service
        container = container
      }
    ]
  ])
}

resource "aws_codepipeline" "codepipeline" {
  count                  = length(local.pipeline_names)

  name                   = local.pipeline_names[count.index].service
  role_arn               = aws_iam_role.codepipeline[count.index].arn

  artifact_store {
    location             = aws_s3_bucket.codepipeline[count.index].bucket
    type                 = "S3"
  }

  dynamic "stage" {
    for_each             = local.service_names

    content {
      name               = join("-", ["source", local.service_names[count.index].container])

      action {
        name             = "Source"
        category         = "Source"
        owner            = "ThirdParty"
        provider         = "GitHub"
        version          = var.revision
        output_artifacts = [
          join("-", ["source", local.service_names[count.index].container])
        ]

        configuration    = {
          Owner          = var.github_organization
          Repo           = upper(local.pipeline_names[count.index].service)
          Branch         = var.env
        }
      }
    }
  }
}
