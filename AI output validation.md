## Pushing back against AI

- The AI put dev and prod Terraform state in the same S3 bucket. I required one bucket per environment.

- It shipped the Terraform modules with no tests. I had to require the Terraform testing framework on every module.

- Argo CD was already working, and it still deployed with `kubectl apply`. I had to force the GitOps path.

- It installed external tools by hand. I required Helm charts, synced by Argo CD, not the Helm CLI.

- It left the API as raw manifests. I had to tell it to package the API as a Helm chart.
