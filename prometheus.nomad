job "prometheus-stack" {
  type = "service"

  datacenters = ["dc1"]

  group "prometheus" {
    count = 2

    network {
      mode = "host"

      port "http" {}
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        args = [
          "--config.file",
          "/local/prometheus.yml",
          "--log.level",
          "debug",
          "--web.listen-address",
          "0.0.0.0:${NOMAD_PORT_http}"
        ]

        network_mode = "host"
      }

      template {
        destination = "/local/prometheus.yml"
        data = <<EOT
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
           - localhost:9093

rule_files:
- /local/rules*.yml

scrape_configs:
  - job_name: prometheus

    static_configs:
      - targets:
          - {{ env "NOMAD_ADDR_http" }} # scrape itself
        labels:
          alloc_id: {{ env "NOMAD_ALLOC_ID" }}
          alloc_idx: {{ env "NOMAD_ALLOC_INDEX" }}
          alloc_name: {{ env "NOMAD_ALLOC_NAME" }}
EOT
      }

      template {
        change_mode = "signal"
        change_signal = "SIGHUP"

        left_delimiter = "[["
        right_delimiter = "]]"

        destination = "/local/rules-1.yml"
        data = <<EOT
groups:
- name: example-group1
  rules:
  - alert: Test1
    expr: prometheus_build_info > 0
    for: 1m
    labels:
      severity: page
      alloc_id: "{{ $labels.alloc_id }}"
    annotations:
      summary: oh noes

  - alert: Test2
    expr: prometheus_build_info > 0
    for: 1m
    labels:
      severity: critical
      alloc_id: "{{ $labels.alloc_id }}"
    annotations:
      summary: Something bad happened
EOT
      }

      template {
        change_mode = "signal"
        change_signal = "SIGHUP"

        left_delimiter = "[["
        right_delimiter = "]]"

        destination = "/local/rules-2.yml"
        data = <<EOT
groups:
- name: example-group2
  rules:
  - alert: Test1
    expr: prometheus_build_info > 0
    for: 1m
    labels:
      severity: page
      alloc_id: "{{ $labels.alloc_id }}"
    annotations:
      summary: oh noes2

  - alert: Test3
    expr: prometheus_build_info > 0
    for: 1m
    labels:
      severity: critical
      alloc_id: "{{ $labels.alloc_id }}"
    annotations:
      summary: Something bad happened
EOT
      }
    }
  }

  group "alertmanager" {
    network {
      mode = "host"
    }

    task "alertmanager" {
      driver = "docker"

      config {
        image = "prom/alertmanager:latest"
        args = [
          "--config.file",
          "/local/alertmanager.yml",
          "--log.level",
          "debug",
        ]

        network_mode = "host"
      }

      template {
        destination = "/local/alertmanager.yml"
        data = <<EOF
route:
  group_by:
    - alertname
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 1m
  receiver: webhook

receivers:
  - name: webhook
    webhook_configs:
    - url: http://localhost:8000/alerts
      send_resolved: true
      max_alerts: 0 # 0=all alerts
EOF
      }
    }
  }
}
