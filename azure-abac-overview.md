# Azure Attribute-Based Access Control (Azure ABAC)

> A comprehensive showcase of Azure ABAC: what it is, the problems it solves, why it
> exists, how it works, the services it supports, when to use it (and when not to), and
> real-world sample repositories.

Every section below cites the authoritative Microsoft Learn source documentation that was
used to validate the content. Links were verified against the official Azure documentation.

---

## Table of contents

1. [What is Azure ABAC?](#1-what-is-azure-abac)
2. [What problem does it solve?](#2-what-problem-does-it-solve)
3. [Why was it built?](#3-why-was-it-built)
4. [How does it work?](#4-how-does-it-work)
5. [Which Azure services are supported?](#5-which-azure-services-are-supported)
6. [When should you use ABAC — and when should you not?](#6-when-should-you-use-abac--and-when-should-you-not)
7. [Worked examples](#7-worked-examples)
8. [GitHub repositories with samples](#8-github-repositories-with-samples)
9. [Reference summary](#9-reference-summary)

---

## 1. What is Azure ABAC?

**Attribute-based access control (ABAC)** is an authorization system that defines access
based on **attributes** associated with three things:

- the **security principal** requesting access (user, group, service principal, managed identity),
- the **resource** being accessed, and
- the **environment** and **request** in which the access is made.

**Azure ABAC** is Microsoft's implementation of ABAC for Azure. It *builds on top of*
[Azure role-based access control (Azure RBAC)](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)
by letting you attach **role assignment conditions** to a role assignment. A condition is an
additional check — expressed as a predicate that evaluates to `true` or `false` — that further
filters the permissions granted by the role.

Key terminology:

| Term | Definition |
| --- | --- |
| **ABAC** | Authorization based on attributes of principals, resources, and environment. |
| **Azure ABAC** | The Azure-specific implementation of ABAC. |
| **Role assignment condition** | An optional check added to a role assignment for finer-grained control. |
| **Attribute** | A key-value pair (e.g., `Project=Blue`). Attributes and tags are synonymous for access-control purposes. |
| **Expression** | A statement of the form `<attribute> <operator> <value>` that evaluates to true/false. |

> Important: Conditions **filter down** (narrow) the permissions granted by a role. You
> **cannot** use a condition to explicitly *deny* access to specific resources.

**Sources:**
- [What is Azure attribute-based access control (Azure ABAC)?](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview)
- [Azure RBAC overview](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)

---

## 2. What problem does it solve?

Plain Azure RBAC grants permissions at the level of a role definition + scope
(management group, subscription, resource group, or resource). That works well, but it runs
into three practical problems that ABAC directly addresses:

### 2.1 Coarse granularity
With RBAC alone, if you grant *Storage Blob Data Reader* at a container scope, the principal
can read **every** blob in that container. There is no built-in way to say "…but only blobs
tagged `Project=Cascade`" or "…only blobs under the path `readonly/`". ABAC conditions make
this fine-grained control possible.

### 2.2 Role assignment sprawl and limits
Azure subscriptions have a
[hard limit on the number of role assignments](https://learn.microsoft.com/en-us/azure/role-based-access-control/troubleshooting#limits).
Scenarios such as "one container per customer, thousands of customers" can require **hundreds
of thousands** of role assignments — well beyond the limit and effectively unmanageable. ABAC
lets you collapse many assignments into **one** assignment plus a condition. Microsoft's
reference scenario reduces **256,000 role assignments to a single one**.

### 2.3 Access rules that lack business meaning
RBAC assignments don't naturally express organizational concepts like project name,
classification level, or development stage. ABAC lets you write conditions in terms of
**attributes that carry business meaning**, and those attributes can change dynamically as
people move between teams and projects.

The three primary benefits, per Microsoft, are:

1. **Provide more fine-grained access control.**
2. **Help reduce the number of role assignments.**
3. **Use attributes that have specific business meaning.**

**Sources:**
- [Why use conditions? (Azure ABAC overview)](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview#why-use-conditions)
- [Scale the management of Azure role assignments by using conditions and custom security attributes](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-custom-security-attributes-example)
- [Azure RBAC limits](https://learn.microsoft.com/en-us/azure/role-based-access-control/troubleshooting#limits)

---

## 3. Why was it built?

Azure ABAC was introduced to combine the strengths of two access-control models rather than
force a choice between them:

- **Azure RBAC** is simple and aligns closely with business roles, but it is coarse-grained.
- **Azure ABAC** adds flexibility and precision for the scenarios RBAC can't handle cleanly.

By using them **together**, organizations get a more sophisticated authorization capability:
RBAC establishes *who has a role at what scope*, while ABAC conditions add *the additional
attribute-driven checks* on top. Microsoft explicitly frames ABAC as an enhancement of RBAC,
not a replacement:

> "Azure RBAC is more straightforward to implement due to its close alignment with business
> logic, while Azure ABAC provides greater flexibility in some key scenarios. By combining
> these two methods, organizations can achieve a more sophisticated level of authorization."

A second driver was **security posture**. Alternatives for data-plane access — **account access
keys** and **shared access signature (SAS) tokens** — have no identity binding, are hard to
rotate, and represent a real risk if leaked. ABAC keeps access tied to Microsoft Entra
identities (identity binding) while still allowing fine-grained, attribute-driven rules,
centrally managed and auditable.

**Sources:**
- [What are role assignment conditions? (overview)](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview#what-are-role-assignment-conditions)
- [Why use this solution? (keys vs. SAS vs. ABAC)](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-custom-security-attributes-example#why-use-this-solution)

---

## 4. How does it work?

### 4.1 The building blocks

A condition is attached to a role assignment and is evaluated **at the time an action is
authorized**. Conditions are written using attributes drawn from four **attribute sources**,
each referenced with a prefix:

| Source | Prefix | Description |
| --- | --- | --- |
| **Environment** | `@Environment` | The network/context of the request — private link, subnet, or current UTC time. |
| **Principal** | `@Principal` | A Microsoft Entra **custom security attribute** on the user/service principal. |
| **Request** | `@Request` | A value in the action request, e.g., the blob index tag being set. |
| **Resource** | `@Resource` | A property of the target resource, e.g., container name or blob path. |

### 4.2 Condition format

The most basic condition targets an **action** and pairs it with an **expression**:

```text
(
    (
        !(ActionMatches{'<action>'})
    )
    OR
    (
        <attribute> <operator> <value>
    )
)
```

A concrete example — *allow "read a blob" only when the container is named
`blobs-example-container`*:

```text
(
    (
        !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'})
    )
    OR
    (
        @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name]
        StringEquals 'blobs-example-container'
    )
)
```

### 4.3 How a condition is evaluated

The `!(ActionMatches{...}) OR (expression)` pattern reads as follows:

```text
if the attempted action does NOT match <action>
{
    Allow the action        // condition doesn't target this action
}
else                        // the action IS the targeted action
{
    if <attribute> <operator> <value> is true
        Allow the action
    else
        Do not allow the action
}
```

In other words, a condition only constrains the actions it explicitly targets; all other
actions permitted by the role continue to work unchanged.

### 4.4 Operators available

Azure ABAC provides a rich operator set for building expressions:

- **Function operators:** `ActionMatches`, `SubOperationMatches`, `Exists`
- **Logical operators:** `AND` / `&&`, `OR` / `||`, `NOT` / `!`
- **Boolean:** `BoolEquals`, `BoolNotEquals`
- **String:** `StringEquals`, `StringEqualsIgnoreCase`, `StringNotEquals`, `StringStartsWith`,
  `StringLike` (supports `*` and `?` wildcards), and their negations
- **Numeric:** `NumericEquals`, `NumericGreaterThan`, `NumericLessThanEquals`, etc. (integers only)
- **DateTime:** `DateTimeEquals`, `DateTimeGreaterThan`, etc. (format `yyyy-mm-ddThh:mm:ss.mmmmmmmZ`)
- **GUID:** `GuidEquals`, `GuidNotEquals`
- **Cross-product (collection) operators:** `ForAnyOfAnyValues:*`, `ForAllOfAnyValues:*`,
  `ForAnyOfAllValues:*`, `ForAllOfAllValues:*`

Conditions can include **multiple actions**, **multiple expressions** (combined with `AND`/`OR`),
and **multiple conditions** grouped with parentheses for precedence.

### 4.5 Where conditions are authored

You can add, edit, and view conditions through:

- **Azure portal** — a **visual condition editor** (limit of 5 expressions) and a **code editor**
  for advanced conditions and condition templates
- **Azure PowerShell** (`New-AzRoleAssignment -Condition -ConditionVersion`)
- **Azure CLI** (`az role assignment create --condition --condition-version`)
- **REST API**, **ARM templates**, and **Bicep**

The condition version currently used is **`2.0`**.

**Sources:**
- [Azure role assignment condition format and syntax](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-format)
- [Attributes and attribute sources](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-format#attributes)
- [Add or edit conditions using the Azure portal](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-portal)
- [Add conditions using Azure PowerShell](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-powershell)
- [Add conditions using Azure CLI](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-cli)
- [Add conditions using the REST API](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-rest)

---

## 5. Which Azure services are supported?

Azure ABAC conditions are currently supported in two broad areas: **storage data-plane access**
and **control-plane role-assignment delegation**.

### 5.1 Storage data plane (resource/request/environment/principal attributes)

Azure ABAC is **generally available (GA)** for controlling access to:

- **Azure Blob Storage**
- **Azure Data Lake Storage Gen2** (storage accounts with hierarchical namespace / HNS enabled)
- **Azure Queue Storage**

…using `request`, `resource`, `environment`, and `principal` attributes, on both **standard**
and **premium** performance tiers.

Conditions apply to **data actions** (`DataActions`) and can be attached to these built-in roles
(or custom roles that include supported data actions):

| Blob roles | Queue roles |
| --- | --- |
| Storage Blob Data Reader | Storage Queue Data Reader |
| Storage Blob Data Contributor | Storage Queue Data Contributor |
| Storage Blob Data Owner | Storage Queue Data Message Processor |
| | Storage Queue Data Message Sender |

Example storage attributes you can use in conditions: account name, container name, blob path,
blob prefix, **blob index tags** (keys and values), encryption scope name, is-current-version,
is-HNS-enabled, is-private-link, snapshot, version ID, and **UTC now**.

> Notes and caveats:
> - Conditions are **not** supported for management-plane storage **Actions** via the Storage resource provider — only **DataActions**.
> - **Blob index tags are not supported** on HNS-enabled (Data Lake Storage) accounts; for tag-based conditions use *Storage Blob Data Owner* on a General Purpose v2 account with HNS disabled.
> - A small set of features (e.g., *list blob include* request attribute, *snapshot* for HNS) are in **Preview**.

### 5.2 Control plane — delegating role-assignment management (constrained delegation)

Azure ABAC also powers **constrained delegation** of role assignment management. Instead of
granting the broad *Owner* or *User Access Administrator* roles, you assign the
**Role Based Access Control Administrator** role with a condition on the
`Microsoft.Authorization/roleAssignments/write` and `/delete` actions. This lets you constrain:

- **which roles** a delegate may assign or remove,
- **which principal types** (user / group / service principal) they may target,
- **which specific principals** they may target, and
- **different rules for add vs. remove** actions.

Two built-in roles already ship **with a built-in condition** for this purpose:

- **Key Vault Data Access Administrator** — constrains assignments to Key Vault data roles
  (Key Vault Administrator, Crypto Officer, Secrets Officer, Crypto User, Secrets User, etc.).
- **Virtual Machine Data Access Administrator (preview)** — constrains assignments to the VM login roles.

### 5.3 Integration with Microsoft Entra

- **Principal attributes** rely on
  [Microsoft Entra custom security attributes](https://learn.microsoft.com/en-us/entra/fundamentals/custom-security-attributes-overview),
  which require the **Attribute Assignment Administrator** role to manage.
- Conditions can be attached to **eligible** role assignments in
  **Microsoft Entra Privileged Identity Management (PIM)**, combining attribute checks with
  time-bound activation, approval workflows, and audit trails.

### 5.4 Feature status — GA vs Preview

| Capability | Area | Status |
| --- | --- | --- |
| Blob Storage conditions (resource/request attributes) | Data plane | **GA** (Oct 2022) |
| Data Lake Storage Gen2 (HNS) conditions | Data plane | **GA** |
| Queue Storage conditions | Data plane | **GA** |
| Environment attributes (private link, subnet, UTC now) | Data plane | **GA** (Apr 2024) |
| Principal custom security attributes in a condition | Data plane | **GA** (Nov 2023) |
| *List blob include* request attribute | Data plane (Blob) | **Preview** |
| *Snapshot* resource attribute for hierarchical namespace | Data plane (ADLS) | **Preview** |
| Delegate role-assignment management with conditions | Control plane | **GA** |
| **Key Vault Data Access Administrator** built-in condition | Control plane | **GA** |
| **Virtual Machine Data Access Administrator** built-in condition | Control plane | **Preview** |

> **What about Azure Key Vault?** Key Vault participates in ABAC **only on the control plane** —
> the *Key Vault Data Access Administrator* role carries a built-in condition that constrains
> **which Key Vault roles a delegate may assign**. There is **no general data-plane ABAC** for
> Key Vault (you cannot yet write conditions on individual secrets/keys/certificates the way you
> can on blobs). As of this writing, **Azure Storage (Blob, ADLS Gen2, Queue) is the only
> service with data-plane ABAC conditions**; everything else surfaces ABAC via the control-plane
> role-assignment delegation model. Always confirm the current list in the
> [conditions overview → "Where can conditions be added?"](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview#where-can-conditions-be-added)
> since coverage expands over time.

**Sources:**
- [Authorize access to Blob Storage using conditions (supported services & feature status)](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac)
- [Actions and attributes for Blob Storage conditions](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac-attributes)
- [Actions and attributes for Queue Storage conditions](https://learn.microsoft.com/en-us/azure/storage/queues/queues-auth-abac-attributes)
- [Delegate Azure access management to others (constrained delegation)](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-overview)
- [Conditions prerequisites (principal & environment attributes)](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-prerequisites)
- [Conditions and Microsoft Entra PIM](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview#conditions-and-microsoft-entra-pim)

---

## 6. When should you use ABAC — and when should you not?

### 6.1 Good fits (when to use)

- **You need finer granularity than a role gives you** — e.g., read only blobs tagged
  `Project=Cascade`, or only blobs under a specific path/prefix.
- **You would otherwise need a very large number of role assignments** — e.g., per-customer or
  per-tenant container access. A single assignment + condition that matches a principal's
  custom security attribute to a resource attribute can replace thousands of assignments.
- **Your access rules map to business attributes** — project, classification, environment/stage.
- **You want time- or network-bounded access** — allow access only during a date/time window,
  only over a **private link**, or only from a specific **subnet**.
- **You want least-privilege delegation of role management** — let a team lead assign only
  specific roles to specific groups without granting Owner/User Access Administrator.
- **You want to move away from access keys / SAS tokens** toward identity-bound, centrally
  managed access.

### 6.2 Poor fits / cautions (when not to use)

- **You need an explicit deny.** Conditions can only *narrow* granted permissions; they cannot
  deny. Use [Azure deny assignments](https://learn.microsoft.com/en-us/azure/role-based-access-control/deny-assignments)
  or Azure Policy for deny semantics.
- **Principal attribute *value changes* propagate slowly (two delays).** Role/condition changes
  take effect in ~5 minutes, but changing a principal's **custom security attribute value** is
  subject to (1) a **directory-to-token propagation delay** of a few minutes before newly issued
  tokens carry the new value, and (2) **data-plane caching for the access-token lifetime**. To
  observe a change: update the value, wait a few minutes, then **re-sign-in** for a fresh token.
  Prefer stable attribute values, or use distinct principals per value, for predictable behavior.
- **The service/data action isn't supported.** ABAC conditions today target storage data
  actions and role-assignment delegation. For unsupported services, plain RBAC (and other
  controls) still apply.
- **You lack a consistent attribute taxonomy.** ABAC's power depends on a **structured,
  governed** set of attributes/tags. Inconsistent or unprotected attributes undermine the
  model and can create security gaps — attributes must be protected because access depends on them.
- **HNS/Data Lake accounts with tag-based conditions.** Blob index tags aren't supported on
  HNS-enabled accounts; design around resource attributes (container name, path) instead.
- **Very complex, hard-to-review logic.** Conditions must be carefully designed and reviewed;
  overly complex expressions are error-prone. The visual editor caps at 5 expressions (use the
  code editor beyond that, deliberately).
- **Known constraint:** you can't currently combine a `Microsoft.Storage` data action with an
  ABAC condition that uses a **GUID** comparison operator, and PIM can't delegate role-assignment
  management for **custom** roles with conditions.

> Rule of thumb: use **RBAC** as the foundation for *who gets a role where*, and add **ABAC
> conditions** only where you need attribute-driven precision, scale reduction, or bounded access.

**Sources:**
- [Overview of conditions in Azure Storage (trade-offs)](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac#overview-of-conditions-in-azure-storage)
- [Why use conditions? / Limits & known issues](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview#limits)
- [Delegate role assignments — known issues](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-overview#known-issues)
- [Azure deny assignments](https://learn.microsoft.com/en-us/azure/role-based-access-control/deny-assignments)

---

## 7. Worked examples

### 7.1 Read access to blobs only when tagged `Project=Cascade`

```text
(
    (
        !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'}
        AND NOT
        SubOperationMatches{'Blob.List'})
    )
    OR
    (
        @Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags:Project<$key_case_sensitive$>]
        StringEqualsIgnoreCase 'Cascade'
    )
)
```

### 7.2 Match a principal's custom security attribute to a container name (scale scenario)

Replaces up to 256,000 role assignments with one assignment + condition:

```text
@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name]
StringEquals
@Principal[Microsoft.Directory/CustomSecurityAttributes/Id:Contosocustomer_name]
```

### 7.3 Constrained delegation — allow assigning only two specific roles to users

```text
(
  (!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'}))
  OR
  (
    @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId]
      ForAnyOfAnyValues:GuidEquals {5e467623-bb1f-42f4-a55d-6e525e11384b, a795c7a0-d4a2-40c1-ae25-d81f01202912}
    AND
    @Request[Microsoft.Authorization/roleAssignments:PrincipalType]
      ForAnyOfAnyValues:StringEqualsIgnoreCase {'User'}
  )
)
AND
(
  (!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'}))
  OR
  (
    @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId]
      ForAnyOfAnyValues:GuidEquals {5e467623-bb1f-42f4-a55d-6e525e11384b, a795c7a0-d4a2-40c1-ae25-d81f01202912}
  )
)
```

**Sources:**
- [Example Azure role assignment conditions for Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac-examples)
- [Examples to delegate role assignment management with conditions](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-examples)

---

## 8. GitHub repositories with samples

The following public repositories contain working Azure ABAC condition samples across the
portal, CLI, PowerShell, ARM/Bicep, REST, and Terraform. (Microsoft ships most first-party ABAC
samples inside its documentation repository rather than a standalone samples repo.)

| Repository | What it contains | Link |
| --- | --- | --- |
| **MicrosoftDocs/azure-docs** | Official ABAC articles **and the embedded sample code** — CLI, PowerShell, ARM template, Bicep, and REST snippets for storage conditions and constrained delegation (see `articles/role-based-access-control/conditions-*` and `articles/storage/blobs/storage-auth-abac-*`). | https://github.com/MicrosoftDocs/azure-docs |
| **hashicorp/terraform-provider-azurerm** | The `azurerm_role_assignment` resource supports `condition` and `condition_version`; the repo includes acceptance tests demonstrating conditions on role assignments. | https://github.com/hashicorp/terraform-provider-azurerm |
| **Azure/azure-cli** | Implementation and examples for `az role assignment create --condition --condition-version`. | https://github.com/Azure/azure-cli |
| **Azure/azure-powershell** | Implementation and examples for `New-AzRoleAssignment -Condition -ConditionVersion`. | https://github.com/Azure/azure-powershell |
| **Azure/azure-quickstart-templates** | Community ARM/Bicep templates, including role-assignment templates you can extend with a `condition`/`conditionVersion` property. | https://github.com/Azure/azure-quickstart-templates |

> Tip: In `MicrosoftDocs/azure-docs`, the highest-value sample files are
> `conditions-role-assignments-template.md` (ARM), `delegate-role-assignments-overview.md`
> (Bicep + CLI + PowerShell + REST), `storage-auth-abac-cli.md`, and
> `storage-auth-abac-powershell.md`.

### IaC snippet references (from the docs repo)

- **Bicep** role assignment with a condition:
  [`Microsoft.Authorization/roleAssignments` with `condition` + `conditionVersion: '2.0'`](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-portal)
- **ARM template** role assignment with a condition:
  [conditions-role-assignments-template](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-template)
- **Terraform** `azurerm_role_assignment` `condition`/`condition_version` arguments:
  [Terraform Registry docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment)

---

## 9. Reference summary

Primary Microsoft Learn documentation used and validated for this document:

- [What is Azure ABAC? (overview)](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview)
- [Condition format and syntax](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-format)
- [Conditions prerequisites](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-prerequisites)
- [Add/edit conditions in the Azure portal](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-role-assignments-portal)
- [Scale role assignments with conditions & custom security attributes](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-custom-security-attributes-example)
- [Delegate role-assignment management (constrained delegation)](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-overview)
- [Authorize Blob Storage access with conditions](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac)
- [Blob Storage actions & attributes](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac-attributes)
- [Queue Storage actions & attributes](https://learn.microsoft.com/en-us/azure/storage/queues/queues-auth-abac-attributes)
- [Example conditions for Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-auth-abac-examples)
- [Microsoft Entra custom security attributes](https://learn.microsoft.com/en-us/entra/fundamentals/custom-security-attributes-overview)
- [Azure RBAC overview](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)

---

*Documentation compiled from Microsoft Learn (Azure RBAC / ABAC) and public GitHub
repositories. Verify feature availability (GA vs. preview) against the live docs, as ABAC
capabilities continue to expand.*
