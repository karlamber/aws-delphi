# tf-github-oidc-role

GitHub Actions OIDC deploy role for easyCMDB.

The role can update the Argus API Lambda from the shared artifact bucket and sync the CloudFront SPA origin (`s3-argus-{env}-{region_short}-cf-origin`). It does not attach `AmazonS3FullAccess`, `CloudFrontFullAccess`, or `AWSLambda_FullAccess`.

`ListDistributions` is the one account-wide action. CloudFront does not support a resource ARN for that call, and the SPA deploy uses it to resolve a distribution id from a hostname.
