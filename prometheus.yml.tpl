global:
  scrape_interval: 20s
  evaluation_interval: 30s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets:
          - localhost:9090

  - job_name: target-node
    static_configs:
      - targets:
          - ${target_private_ip}:9100
