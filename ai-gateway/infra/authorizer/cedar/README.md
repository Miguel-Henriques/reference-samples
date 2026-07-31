## `ListModels`

`ListModels` uses a two-step authorization:

```
GET /v1/models
  → AVP: `ListModels` on Gateway
  → Fetch/cache LiteLLM model catalog
  → AVP `BatchIsAuthorized` in chunks of 30
  → Filter locally
  → Return permitted models
```

> The batch authorization approach is acceptable for most scenarios as a typical model catalogs won't exceed 30 models.
>
> Should you have a large catalog with hundreds of models you can maintain a role/key model allowlist to efficiently query the list of allowed models for a given role.
>
> Permission queries - what enables asking questions such as "which models can I access" - though already available in the Cedar policy language, are not yet supported in AVP.

Results are cacheable per role.

## RBAC

LiteLLM provides data-side filtering allowing virtual keys and teams to have model allowlists, however this may be limited for setups that requires other group-based permissions.

LiteLLM provides RBAC capabilities but most useful controls are locked behind an enterprise license.

That's why I've introduced `role` an authorizer-level attribute to provide the ability to establish granular permissions at user and team-member level. Composable with team-based permissions configured in LiteLLM.
