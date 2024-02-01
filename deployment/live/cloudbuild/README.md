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

