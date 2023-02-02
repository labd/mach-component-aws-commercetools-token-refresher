version 0.3.3 (2023-02-02)
--------------------------
 - Security fix: updated certifi and urllib3 packages


version 0.3.2 (2022-09-14)
--------------------------
 - Remove too restrictive IAM policy condition which prevented scope-change trigger to rotate the token


version 0.3.1 (2022-09-14)
--------------------------
 - Add permission for scope-change lambda function to perform RotateSecret (#13)


version 0.3.0 (2022-06-29)
--------------------------
 - Add VPC support
 - Add custom KMS key support
 - Add cloudwatch log group
 - Make available in us-east-1


version 0.2.0 (2021-10-28)
--------------------------
 - Force rotate when scope changes


version 0.1.0 (2021-04-14)
--------------------------
 - Initial tagged release
