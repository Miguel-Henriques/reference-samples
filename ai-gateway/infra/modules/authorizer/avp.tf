resource "aws_verifiedpermissions_policy_store" "this" {
  description = "Authorization policies for the ${var.litellm_stack_name} AI gateway."

  validation_settings {
    mode = "STRICT"
  }

  tags = local.tags
}

resource "aws_verifiedpermissions_schema" "this" {
  policy_store_id = aws_verifiedpermissions_policy_store.this.id

  definition {
    value = file("${path.module}/cedar/schema.json")
  }
}

locals {
  avp_static_policies = {
    for meta_path in fileset(
      "${path.module}/cedar/policies/static",
      "**/meta.json",
    ) :
    dirname(meta_path) => {
      meta = jsondecode(file(
        "${path.module}/cedar/policies/static/${meta_path}",
      ))
      statement = file(
        "${path.module}/cedar/policies/static/${dirname(meta_path)}/policy.cedar",
      )
    }
  }

  avp_policy_templates = {
    for meta_path in fileset(
      "${path.module}/cedar/policies/templated",
      "**/meta.json",
    ) :
    dirname(meta_path) => {
      meta = jsondecode(file(
        "${path.module}/cedar/policies/templated/${meta_path}",
      ))
      statement = file(
        "${path.module}/cedar/policies/templated/${dirname(meta_path)}/policy.cedar",
      )
    }
  }

  avp_template_links = merge({}, [
    for template_key, policy_template in local.avp_policy_templates : {
      for link in policy_template.meta.linked :
      "${template_key}/${link.link_id}" => {
        template_key = template_key
        args = {
          for placeholder, entity_uid in link.args :
          placeholder => {
            entity_type = regex("^(.+)::\"([^\"]+)\"$", entity_uid)[0]
            entity_id   = regex("^(.+)::\"([^\"]+)\"$", entity_uid)[1]
          }
        }
      }
    }
  ]...)
}

resource "aws_verifiedpermissions_policy" "static" {
  for_each = local.avp_static_policies

  policy_store_id = aws_verifiedpermissions_policy_store.this.id

  definition {
    static {
      description = each.value.meta.description
      statement   = each.value.statement
    }
  }

  depends_on = [aws_verifiedpermissions_schema.this]
}

resource "aws_verifiedpermissions_policy_template" "this" {
  for_each = local.avp_policy_templates

  policy_store_id = aws_verifiedpermissions_policy_store.this.id
  description     = each.value.meta.description
  statement       = each.value.statement

  depends_on = [aws_verifiedpermissions_schema.this]
}

resource "aws_verifiedpermissions_policy" "templated" {
  for_each = local.avp_template_links

  policy_store_id = aws_verifiedpermissions_policy_store.this.id

  definition {
    template_linked {
      policy_template_id = aws_verifiedpermissions_policy_template.this[
        each.value.template_key
      ].policy_template_id

      dynamic "principal" {
        for_each = contains(keys(each.value.args), "?principal") ? [
          each.value.args["?principal"],
        ] : []

        content {
          entity_id   = principal.value.entity_id
          entity_type = principal.value.entity_type
        }
      }

      dynamic "resource" {
        for_each = contains(keys(each.value.args), "?resource") ? [
          each.value.args["?resource"],
        ] : []

        content {
          entity_id   = resource.value.entity_id
          entity_type = resource.value.entity_type
        }
      }
    }
  }
}
