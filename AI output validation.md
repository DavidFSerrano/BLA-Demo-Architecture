## Pushing back against AI

- The AI wanted to put the dev and prod tf state in the same backend bucket, I told it that I wanted a stronger boundary between the 2. Told it to create on s3 bucket for each.

- For security I had to tell the AI model the put AWS Network firewall in between the APP tier and the NATGW and ALB  explicitly, it did not suggested it on its own.