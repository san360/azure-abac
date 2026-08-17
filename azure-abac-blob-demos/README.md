# Azure ABAC — Blob Storage Demos (Bicep)

A ready-to-run sample that showcases **Azure attribute-based access control (ABAC)** on
**Azure Blob Storage** using **Bicep**. It deploys **four independent demos**, each showing a
different kind of role-assignment **condition**, and includes scripts to **seed** sample data
and **test** the behavior as a real user.

> For the concepts behind ABAC, see the companion overview in
> [../azure-abac-overview.md](../azure-abac-overview.md).

---

## The demos at a glance

| Demo | Condition type | Role granted | What the user can do | What is denied |
| --- | --- | --- | --- | --- |
| **1** | **Container name** | Storage Blob Data Reader | Read/list blobs in `allowed-container` | Read/list `blocked-container` |
| **2** | **Blob index tag** | Storage Blob Data Owner | Read blobs tagged `Project=Cascade` | Read blobs tagged anything else (e.g., `Project=Baker`) |
| **3** | **Blob path / prefix** | Storage Blob Data Reader | Read blobs whose path starts with `readonly/` | Read blobs under any other path (e.g., `private/`) |
| **4** | **Principal attribute** (custom security attribute) | Storage Blob Data Owner | Read blobs whose `Project` tag equals the **caller's** `abacdemo/Project` attribute | Read blobs whose tag does not match the caller's attribute |

Each demo's condition (validated against the
[Azure ABAC condition syntax](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-format)):

- **Demo 1** — allow read only when
  `@Resource[...containers:name] StringEquals 'allowed-container'`.
- **Demo 2** — allow read (excluding *List*) only when
  `@Resource[...blobs/tags:Project<$key_case_sensitive$>] StringEquals 'Cascade'`.
- **Demo 3** — allow read (excluding *List*) only when
  `@Resource[...blobs:path] StringStartsWith 'readonly/'`.
- **Demo 4** — allow read (excluding *List*) only when
  `@Resource[...blobs/tags:Project<$key_case_sensitive$>] StringEquals @Principal[Microsoft.Directory/CustomSecurityAttributes/Id:abacdemo_Project]`.

> **Principal attributes *are* supported for Azure Storage conditions.** They are Microsoft
> Entra **custom security attributes** referenced via `@Principal[...]`. Unlike resource/request
> attributes, they must be **defined in Entra and assigned to the principal first** — the
> attribute cannot be created in Bicep, and the conditional role assignment will fail with
> `InvalidRoleAssignmentCondition` if the attribute doesn't exist yet. See
> [Demo 4 — principal attribute](#demo-4--principal-attribute-setup) below.

---

## How the demos stay isolated (no conflicts)

RBAC is **additive**: if one principal has multiple role assignments at the same scope, the
effective permission is the **union** of them. If all three conditions lived on one storage
account, they would combine and mask each other.

To prevent that, **each demo provisions its own dedicated storage account** and attaches its
role assignment **scoped to that account only**:

```text
rg-abac-demo
├── abacd1xxxxxxxxxxxxx   (Demo 1)  ── role assignment: Reader + container-name condition
│     ├── allowed-container
│     └── blocked-container
├── abacd2xxxxxxxxxxxxx   (Demo 2)  ── role assignment: Owner + tag condition
│     └── data
├── abacd3xxxxxxxxxxxxx   (Demo 3)  ── role assignment: Reader + path condition
│     └── docs
└── abacd4xxxxxxxxxxxxx   (Demo 4)  ── role assignment: Owner + principal-attribute condition
      └── data
```

Because a user accessing Demo 1's account only ever has Demo 1's assignment in effect, the
demos never interfere with one another. You can also deploy any subset (see `deployDemoN`).
Demo 4 is **off by default** (`deployDemo4=false`) because it requires the custom security
attribute to exist first.

---

## Repository layout

```text
azure-abac-blob-demos/
├── README.md
├── .gitignore
├── bicep/
│   ├── main.bicep                         # Orchestrator: deploys the demos
│   ├── modules/
│   │   ├── storageAccount.bicep           # Reusable storage account + containers
│   │   └── roleAssignmentWithCondition.bicep  # Reusable conditional role assignment
│   └── demos/
│       ├── demo1-container-name.bicep
│       ├── demo2-blob-index-tags.bicep
│       ├── demo3-blob-path-prefix.bicep
│       └── demo4-principal-attribute.bicep
└── scripts/
    ├── deploy.ps1                    # Create RG + deploy demos
    ├── seed-data.ps1                 # Upload sample blobs (with tags / paths)
    ├── setup-principal-attribute.ps1 # Demo 4: define + assign Entra custom security attribute
    ├── inspect-token.ps1            # Decode the access token (JWT) to show it has no ABAC claims
    ├── _testHelper.ps1               # Shared PASS/FAIL assertion helper
    ├── test-demo1.ps1                # Verify container-name condition
    ├── test-demo2.ps1                # Verify tag condition
    ├── test-demo3.ps1                # Verify path condition
    ├── test-demo4.ps1                # Verify principal-attribute condition
    └── cleanup.ps1                   # Delete everything
```

---

## Prerequisites

- **Azure CLI** 2.18+ (`az version`) and the **Bicep** tooling (`az bicep install`).
- An Azure subscription and a target region.
- **Two identities**:
  - An **admin/operator** identity to deploy — needs permission to create role assignments
    (**Owner**, **User Access Administrator**, or **Role Based Access Control Administrator**)
    on the resource group.
  - A **test user** (the principal that receives the conditional access). You only need its
    **object ID** to deploy. To run the tests you sign in as this user.
- Get the test user's object ID:

  ```powershell
  az ad user show --id someone@contoso.com --query id -o tsv
  ```

> **Storage account requirements for tags (Demo 2):** blob index tags require a General
> Purpose v2 account with hierarchical namespace **disabled** — the Bicep sets
> `kind: 'StorageV2'` and `isHnsEnabled: false` accordingly. See
> [conditions prerequisites](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-prerequisites).

---

## Step 1 — Deploy

Sign in as the **admin/operator** and deploy:

```powershell
cd azure-abac-blob-demos/scripts

az login
az account set --subscription "<your-subscription-id-or-name>"

./deploy.ps1 `
  -ResourceGroup rg-abac-demo `
  -Location eastus `
  -TestPrincipalId "<test-user-object-id>" `
  -TestPrincipalType User
```

The script prints the three generated storage account names. Copy them — the test scripts
need them.

> Deploy a subset instead by passing Bicep params, e.g. `deployDemo2=false deployDemo3=false`,
> via `az deployment group create ... --parameters deployDemo1=true deployDemo2=false deployDemo3=false`.

---

## Step 2 — Seed sample data

Still as the **admin/operator**:

```powershell
./seed-data.ps1 -ResourceGroup rg-abac-demo
```

This uploads:

| Demo | Blobs created |
| --- | --- |
| 1 | `allowed-container/hello.txt`, `blocked-container/hello.txt` |
| 2 | `data/cascade.txt` (tag `Project=Cascade`), `data/baker.txt` (tag `Project=Baker`) |
| 3 | `docs/readonly/allowed.txt`, `docs/private/secret.txt` |

> Seeding uses the account key purely for setup convenience. The ABAC evaluation you test in
> Step 3 uses **Microsoft Entra identity** (`--auth-mode login`), not keys.

---

## Step 3 — Test as the user

> Role assignments can take **a few minutes** to propagate. If everything shows `Deny`
> immediately after deploy, wait and re-run.

Open a **new terminal** and sign in **as the test user** (the identity whose object ID you
deployed with):

```powershell
az login   # sign in as the TEST USER
```

Then run each demo's test, passing the matching storage account name from Step 1:

```powershell
./test-demo1.ps1 -StorageAccount <demo1-account-name>
./test-demo2.ps1 -StorageAccount <demo2-account-name>
./test-demo3.ps1 -StorageAccount <demo3-account-name>
```

### Expected output

Each check prints `PASS`/`FAIL` by comparing the real outcome to what the condition should do.

**Demo 1**
```text
[PASS] List allowed-container                     expected=Allow actual=Allow
[PASS] List blocked-container                     expected=Deny  actual=Deny
[PASS] Download allowed-container/hello.txt        expected=Allow actual=Allow
[PASS] Download blocked-container/hello.txt        expected=Deny  actual=Deny
```

**Demo 2**
```text
[PASS] List data (list not tag-filtered)          expected=Allow actual=Allow
[PASS] Download data/cascade.txt (Cascade)         expected=Allow actual=Allow
[PASS] Download data/baker.txt (Baker)             expected=Deny  actual=Deny
```

**Demo 3**
```text
[PASS] List docs (list not path-filtered)         expected=Allow actual=Allow
[PASS] Download docs/readonly/allowed.txt          expected=Allow actual=Allow
[PASS] Download docs/private/secret.txt            expected=Deny  actual=Deny
```

> **Why is *List* always allowed in Demos 2 and 3?** Blob index tags and blob path are not
> evaluated during the *List* sub-operation, so the conditions explicitly exclude
> `SubOperationMatches{'Blob.List'}`. This mirrors Microsoft's official examples.

---

## Demo 4 — principal attribute setup

Demo 4 makes access depend on a **Microsoft Entra custom security attribute** on the *caller*
rather than a hard-coded value. The condition allows a read only when the blob's `Project` tag
equals the caller's `abacdemo/Project` attribute — so **one condition serves many users**, each
seeing only the data that matches their own attribute.

### Extra prerequisites (beyond the other demos)

Demo 4 uses Microsoft Entra **custom security attributes**, which require **two Entra directory
roles** that even a **Global Administrator does not hold by default**:

| Role | Why it's needed |
| --- | --- |
| **Attribute Definition Administrator** | Create the attribute set and the attribute definition (`abacdemo` / `Project`). |
| **Attribute Assignment Administrator** | Assign an attribute value (e.g., `Project=Cascade`) to the principal. |

(You also need **Role Based Access Control Administrator** / Owner to add the conditional role
assignment, same as the other demos.)

If you're a tenant admin without the two attribute roles, self-assign them via Microsoft Graph
(role template IDs are fixed):

```powershell
$me = az ad signed-in-user show --query id -o tsv
foreach ($roleId in '8424c6f0-a189-499e-bbd0-26c1753c96d4','58a13ea3-c632-46ae-9ee0-9c0d43cd7f3d') {
  $b = @{ principalId=$me; roleDefinitionId=$roleId; directoryScopeId='/' } | ConvertTo-Json
  $t = New-TemporaryFile; Set-Content $t $b -Encoding utf8
  az rest --method POST --url https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments --headers Content-Type=application/json --body "@$t"
  Remove-Item $t
}
# 8424c6f0... = Attribute Definition Administrator, 58a13ea3... = Attribute Assignment Administrator
```

- Custom security attributes are **directory objects** — they cannot be created in Bicep, and
  the conditional role assignment **fails with `InvalidRoleAssignmentCondition`** if the
  attribute doesn't exist yet. So the order matters:

```powershell
# 1) Define the attribute and assign a value to the test principal (needs the Entra roles above)
./setup-principal-attribute.ps1 -PrincipalObjectId <test-user-object-id> -AttributeValue Cascade

# 2) NOW deploy Demo 4 (attribute must already exist for the condition to validate)
az deployment group create -g rg-abac-demo -n demo4 `
  --template-file ../bicep/demos/demo4-principal-attribute.bicep `
  --parameters testPrincipalId=<test-user-object-id> testPrincipalType=User

# 3) Seed + test (sign in as the test user for the test)
./seed-data.ps1 -ResourceGroup rg-abac-demo          # seeds Demo 4's account too
./test-demo4.ps1 -StorageAccount <demo4-account-name>
```

Expected result with the attribute set to `Cascade`:

```text
[PASS] List data (list not tag-filtered)          expected=Allow actual=Allow
[PASS] Download data/cascade.txt (matches principal) expected=Allow actual=Allow
[PASS] Download data/baker.txt (no match)         expected=Deny  actual=Deny
```

> **Changing a principal attribute value is subject to TWO delays** (and it does *not* change the
> token — the attribute is not a JWT claim; see
> [Does ABAC change the access token?](#does-abac-change-the-access-token-jwt) below). Azure
> Storage caches the principal's attributes in its authorization layer **keyed by the access
> token**, so a change takes effect only after BOTH of these:
>
> 1. **Directory replication (minutes):** the resource provider must read the new value from
>    Entra. A token minted *seconds* after the change can still resolve to the old value
>    (verified: a fresh login right after a reset still saw the previous value).
> 2. **New token required:** the old token's cache entry keeps serving the old value for the
>    token's lifetime, so you must present a **fresh token** (re-sign-in).
>
> Practical recipe to observe a change: make the change, **wait a few minutes**, then run
> `az login` again (fresh token). Waiting alone (same token) or re-logging in immediately can
> both still show the old value. This is very different from role/condition changes, which
> propagate within ~5 minutes with no re-auth.

> **Tip for reliable demos:** instead of flipping one user's attribute, use **two principals**
> with fixed attributes (e.g., a `Cascade` user and a `Baker` user), each set **before** first
> access. That avoids the token-cache delay entirely and mirrors Microsoft's official tutorial.

> Custom security attribute **definitions cannot be deleted**, only deactivated (set
> `status: Deprecated`). Deleting the resource group removes the storage/role assignment but
> leaves the attribute definition in Entra for reuse.

---

## Step 4 — Clean up


```powershell
./cleanup.ps1 -ResourceGroup rg-abac-demo
```

Deleting the resource group removes the storage accounts **and** their role assignments.

---

## Verifying / editing conditions in the portal

After deploying, you can inspect each condition:

1. Open the storage account → **Access control (IAM)** → **Role assignments**.
2. Find the assignment for your test user → **Condition** column → **View/Edit**.
3. Toggle between the **Visual** and **Code** editors.

See
[Add or edit conditions in the Azure portal](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-portal).

---

## Does ABAC change the access token (JWT)?

**No.** This is a common misconception. Verified empirically with `scripts/inspect-token.ps1`:

- **ABAC condition attributes are never in the token.** Resource attributes (container, path,
  blob tags), request attributes, and environment attributes (private link, subnet, UTC now) are
  evaluated **server-side by the resource provider** at request time. They are not claims.
- **Custom security attributes (Demo 4) are not token claims either.** The decoded Storage token
  contains standard claims (`aud`, `iss`, `oid`, `tid`, `scp`, `amr`, even `groups`) but **no**
  `Project`/custom-security-attribute claim. Notably, **`groups` *is* in the token but the ABAC
  attribute is not** — Storage fetches the attribute from Entra during authorization and caches
  it **keyed by the token** (which is why changing it needs a fresh token, per the Demo 4 note).
- **There is one token per *service*, not per demo.** The Storage token's `aud` is
  `https://storage.azure.com` — the whole service — so the **same token authorizes all four demo
  accounts identically**. You do **not** need a separate login per scenario. The token only
  differs by **target service (audience)**: a Key Vault token has `aud=https://vault.azure.net`,
  an ARM token `aud=https://management.azure.com`, etc.

Inspect it yourself (the tool masks secrets by default so output is safe to share):

```powershell
./inspect-token.ps1 -Mask                                   # Azure Storage token (used by all demos)
./inspect-token.ps1 -Resource https://vault.azure.net -Mask # compare: different audience
# omit -Mask in your own terminal to see the full encoded token
```

Example decoded payload (redacted) — note the absence of any attribute claim:

```json
{
  "aud": "https://storage.azure.com",
  "iss": "https://sts.windows.net/<tenant>/",
  "appid": "04b07795-8ddb-461a-bbee-02f9e1bf7b46",
  "scp": "user_impersonation",
  "amr": ["pwd", "mfa"],
  "groups": ["..."],          // group claims ARE present
  "oid": "<user object id>"    // but NO Project / custom-security-attribute claim
}
```

> Custom security attributes **cannot** be added to the first-party Azure Storage token (you
> can't attach a custom claims policy to a Microsoft-owned resource app). So for ABAC, the
> attribute always stays server-side. See
> [optional claims](https://learn.microsoft.com/en-us/entra/identity-platform/optional-claims)
> for the general (non-first-party) token-customization feature.

---

## Extending the sample

Ideas that keep the "one demo = one account" isolation model:

- **Time-bound access** — add an `@Environment[UtcNow]` `DateTimeGreaterThan` / `DateTimeLessThan` window.
- **Network-bound access** — require `@Environment[isPrivateLink] BoolEquals true` or a specific subnet.
- **Principal attribute matching** — match a
  [Microsoft Entra custom security attribute](https://learn.microsoft.com/en-us/entra/fundamentals/custom-security-attributes-overview)
  on the user (`@Principal[...]`) to a resource attribute — the pattern behind the
  [scale-to-one-assignment scenario](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-custom-security-attributes-example).

---

## Reference documentation

- [What is Azure ABAC?](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview)
- [Condition format and syntax](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-format)
- [Conditions prerequisites](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-prerequisites)
- [Authorize Blob Storage access with conditions](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac)
- [Blob Storage actions & attributes](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac-attributes)
- [Example conditions for Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac-examples)
- [Add conditions with Azure CLI](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-cli)
- [Azure built-in roles (storage)](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage)
