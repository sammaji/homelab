resource "oci_budget_budget" "this" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.vm_name_prefix}-budget"
  description    = "Expected VPU spend ~${format("%.2f", local.estimated_monthly_vpu_cost)}/month"
  amount         = var.budget_amount
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [local.compartment_id]
}

resource "oci_budget_alert_rule" "actual" {
  for_each = toset(["50", "80", "100", "120"])

  budget_id      = oci_budget_budget.this.id
  display_name   = "actual-${each.value}pct"
  type           = "ACTUAL"
  threshold      = tonumber(each.value)
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  message        = "Oracle Cloud spend in the ${var.vm_name_prefix} compartment reached ${each.value}% of the ${var.budget_amount} monthly budget (expected ~${format("%.2f", local.estimated_monthly_vpu_cost)} from boot volume VPUs at ${var.boot_volume_vpus_per_gb}/GB)."
}

resource "oci_budget_alert_rule" "forecast" {
  budget_id      = oci_budget_budget.this.id
  display_name   = "forecast-over-budget"
  type           = "FORECAST"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  message        = "Oracle Cloud spend in the ${var.vm_name_prefix} compartment is forecast to exceed the ${var.budget_amount} monthly budget."
}

moved {
  from = oci_budget_alert_rule.any_spend
  to   = oci_budget_alert_rule.actual["100"]
}

# Fixed-amount early warnings, independent of budget_amount
resource "oci_budget_alert_rule" "early" {
  for_each = toset([for a in var.early_alert_amounts : tostring(a)])

  budget_id      = oci_budget_budget.this.id
  display_name   = "actual-early-warning-${replace(each.value, ".", "_")}"
  type           = "ACTUAL"
  threshold      = tonumber(each.value)
  threshold_type = "ABSOLUTE"
  recipients     = var.budget_alert_email
  message        = "Oracle Cloud spend in the ${var.vm_name_prefix} compartment passed ${each.value} this month (boot volume VPUs at ${var.boot_volume_vpus_per_gb}/GB, expected ~${format("%.2f", local.estimated_monthly_vpu_cost)}/month)."
}

moved {
  from = oci_budget_alert_rule.early
  to   = oci_budget_alert_rule.early["1"]
}
