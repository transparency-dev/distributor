# Cloudbuild Triggers and Steps

This directory contains a terragrunt file that can be deployed using `terragrunt apply` to define the necessary triggers and steps in GCB.
These steps will:
 1. Trigger on a change to the `main` branch of the distributor repo
 2. Build a docker image from the `main` branch
 3. Publish this docker image in artifact repository

The first time this is run for a pair of {GCP Project, GitHub Repo} you will get an error message such as the following:
```
Error: Error creating Trigger: googleapi: Error 400: Repository mapping does not exist. Please visit $URL to connect a repository to your project
```

This is a manual one-time step that needs to be followed to integrate GCB and the GitHub project.

## Slack Notifications

Each cloudbuild environment sets up a Slack integration. This requires:
 1. A webhook to have been created in a Slack app (https://api.slack.com/apps/A06KYD43DPE/incoming-webhooks)
 2. This webhook URL has been stored as a secret in Secret Manager in cloud

One unfortunate issue is that there is a common dependency on the pubsub topic `cloud-builds`.
The first environment will create this, and other environments will then fail to create it because the name is in use.
To work around this:

```
terragrunt import module.cloud-build-slack-notifier.google_pubsub_topic.cloud_builds projects/checkpoint-distributor/topics/cloud-builds
```

This imports the resource into this configuration, and running `terragrunt apply` again after this should work.

### Slack Templating

Here's an example pub-sub message for ease of writing templates ([docs](https://pkg.go.dev/cloud.google.com/go/cloudbuild/apiv1/v2/cloudbuildpb#Build)):

```
{
  "id": "0d97c63e-a349-4bf7-80d0-8f6e21786d87",
  "status": "SUCCESS",
  "source": {
    "gitSource": {
      "url": "https://github.com/transparency-dev/distributor.git",
      "revision": "a017b5e59a1cf9fdbed5999e1a9aced5404de4cd"
    }
  },
  "createTime": "2024-02-21T16:56:35.560619Z",
  "steps": [{
    "name": "gcr.io/cloud-builders/docker",
    "args": ["build", "-t", "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/distributor:latest", "-f", "./cmd/Dockerfile", "."]
  }, {
    "name": "gcr.io/cloud-builders/docker",
    "args": ["push", "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/distributor:latest"]
  }, {
    "name": "gcr.io/google.com/cloudsdktool/cloud-sdk",
    "args": ["run", "deploy", "distributor-service-dev", "--image", "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/distributor:latest", "--region", "us-central1"],
    "entrypoint": "gcloud"
  }],
  "timeout": "600s",
  "projectId": "checkpoint-distributor",
  "sourceProvenance": {
    "resolvedGitSource": {
      "url": "https://github.com/transparency-dev/distributor.git",
      "revision": "a017b5e59a1cf9fdbed5999e1a9aced5404de4cd"
    }
  },
  "buildTriggerId": "33f60a9c-3d79-4941-bfb1-fccbdd9cf38c",
  "options": {
    "substitutionOption": "ALLOW_LOOSE",
    "logging": "CLOUD_LOGGING_ONLY",
    "dynamicSubstitutions": true,
    "pool": {
    }
  },
  "logUrl": "https://console.cloud.google.com/cloud-build/builds;region\u003dus-central1/0d97c63e-a349-4bf7-80d0-8f6e21786d87?project\u003d39300730911",
  "substitutions": {
    "TRIGGER_NAME": "build-distributor-docker-dev",
    "COMMIT_SHA": "a017b5e59a1cf9fdbed5999e1a9aced5404de4cd",
    "TRIGGER_BUILD_CONFIG_PATH": "",
    "REPO_FULL_NAME": "transparency-dev/distributor",
    "SHORT_SHA": "a017b5e",
    "BRANCH_NAME": "main",
    "REF_NAME": "main",
    "REVISION_ID": "a017b5e59a1cf9fdbed5999e1a9aced5404de4cd",
    "REPO_NAME": "distributor"
  },
  "tags": ["trigger-33f60a9c-3d79-4941-bfb1-fccbdd9cf38c"],
  "queueTtl": "3600s",
  "serviceAccount": "projects/checkpoint-distributor/serviceAccounts/cloudbuild-dev-sa@checkpoint-distributor.iam.gserviceaccount.com",
  "name": "projects/39300730911/locations/us-central1/builds/0d97c63e-a349-4bf7-80d0-8f6e21786d87"
}
```

