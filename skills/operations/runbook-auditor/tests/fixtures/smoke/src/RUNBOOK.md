# Incident Response Runbook

## Service Restart
```bash
docker-compose restart app
docker-compose logs app --tail=100
```

## Database Recovery
```bash
kubectl exec -it postgres-0 -- pg_dump myapp > backup.sql
kubectl apply -f deployment.yaml
```

## Monitoring
- Grafana: https://myapp.grafana.net/d/main
- Datadog: https://app.datadoghq.com/dashboard/myapp

## Contacts
- On-call: #ops-slack
- Escalation: sre@myapp.com
