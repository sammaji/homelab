resource "oci_budget_budget" "this" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.vm_name_prefix}-budget"
  amount         = var.budget_amount
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [local.compartment_id]
}

resource "oci_budget_alert_rule" "any_spend" {
  budget_id      = oci_budget_budget.this.id
  display_name   = "any-actual-spend"
  type           = "ACTUAL"
  threshold      = 1
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  message        = "Oracle Cloud spend detected in the ${var.vm_name_prefix} compartment - something left the Always Free tier."
}

resource "oci_budget_alert_rule" "forecast" {
  budget_id      = oci_budget_budget.this.id
  display_name   = "forecast-over-budget"
  type           = "FORECAST"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  message        = "Oracle Cloud spend in the ${var.vm_name_prefix} compartment is forecast to exceed budget."
}
