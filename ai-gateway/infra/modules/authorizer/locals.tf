locals {
  name = "${var.litellm_stack_name}-authorizer"

  tags = {
    component = "authorizer"
  }

  tls_enabled = var.acm_certificate_arn != ""

  # Cedar namespace from policies/schema.json (must be exactly one top-level key).
  # Injected as AVP_NAMESPACE so the authorizer entity types stay in lockstep.
  avp_namespace = one(
    keys(jsondecode(file("${path.module}/cedar/schema.json"))),
  )
}
