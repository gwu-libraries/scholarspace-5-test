resource "aws_wafv2_web_acl" "scholarspace" {
  name        = "${var.site_prefix}-waf"
  description = "WAF rules for Scholarspace bot control and DDoS protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule - block IPs making >2000 requests in 5 min
  rule {
    name     = "RateLimitRule"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule - Bot Control
  rule {
    name     = "AWSManagedRulesBotControl"
    priority = 1

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        managed_rule_group_configs {
          aws_managed_rules_bot_control_rule_set {
            inspection_level = "COMMON"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BotControlRule"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRule"
      sampled_requests_enabled   = true
    }
  }

  # Custom rule - Block common scanner user agents
  rule {
    name     = "BlockScannerUserAgents"
    priority = 3

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string = "sqlmap"
            field_to_match {
              single_header { name = "user-agent" }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }

        statement {
          byte_match_statement {
            search_string = "nikto"
            field_to_match {
              single_header { name = "user-agent" }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }

        statement {
          byte_match_statement {
            search_string = "nmap"
            field_to_match {
              single_header { name = "user-agent" }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }

        statement {
          byte_match_statement {
            search_string = "masscan"
            field_to_match {
              single_header { name = "user-agent" }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockScannerUserAgents"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule - IP Reputation List
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 4

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "IpReputationListRule"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule - Common Rule Set (OWASP)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 5

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SizeRestrictions_BODY"

          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "CrossSiteScripting_BODY"

          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "GenericLFI_BODY"

          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.site_prefix}-waf-metrics"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.site_prefix}-waf"
  }
}

resource "aws_wafv2_web_acl_association" "scholarspace_alb" {
  resource_arn = aws_lb.scholarspace.arn
  web_acl_arn  = aws_wafv2_web_acl.scholarspace.arn
}

resource "aws_cloudwatch_log_group" "waf_log_group" {
  name              = "/aws/waf/${var.site_prefix}"
  retention_in_days = 30

  tags = {
    Name = "${var.site_prefix}-waf-logs"
  }
}
