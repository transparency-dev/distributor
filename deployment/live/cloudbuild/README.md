## Cloudbuild Triggers and Steps

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

### Slack notifications

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
