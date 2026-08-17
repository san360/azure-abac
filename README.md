# Azure Attribute-Based Access Control

An overview of Azure attribute-based access control (Azure ABAC) plus runnable Bicep and
PowerShell demos for Azure Blob Storage role-assignment conditions.

## Demo scenarios

The sample deploys each scenario to a separate storage account so the additive RBAC role
assignments do not interfere with one another.

| Demo | Attribute used by the condition | Allowed | Denied |
| --- | --- | --- | --- |
| **1. Container name** | Blob container name | Read and list blobs in `allowed-container` | Read or list `blocked-container` |
| **2. Blob index tag** | Blob tag `Project` | Read blobs tagged `Project=Cascade` | Read blobs with another project tag, such as `Project=Baker` |
| **3. Blob path prefix** | Blob path | Read blobs under `readonly/` | Read blobs under another path, such as `private/` |
| **4. Principal attribute** | Caller custom security attribute and blob tag | Read blobs whose `Project` tag matches the caller's `abacdemo/Project` attribute | Read blobs whose tag does not match the caller's attribute |

Demos 2 through 4 exclude the `Blob.List` sub-operation because blob tags and paths are not
evaluated when listing blobs. Demo 4 is disabled by default because its Microsoft Entra custom
security attribute must exist before Azure validates the role-assignment condition.

## Documentation

- [Azure ABAC overview](azure-abac-overview.md) explains the model, supported services,
  condition syntax, use cases, limitations, and worked examples.
- [Blob Storage demo guide](azure-abac-blob-demos/README.md) contains architecture,
  prerequisites, deployment, data seeding, tests, expected results, and cleanup instructions.

## Repository contents

```text
azure-abac-overview.md       Conceptual Azure ABAC guide
azure-abac-blob-demos/
  bicep/                     Deployment and conditional role assignments
  scripts/                   Setup, test, inspection, and cleanup scripts
  README.md                  Complete demo walkthrough
```
