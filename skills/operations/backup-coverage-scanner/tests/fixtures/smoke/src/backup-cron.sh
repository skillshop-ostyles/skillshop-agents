#!/bin/bash
pg_dump -h localhost -U myapp myapp > /backups/daily/myapp-$(date +%Y%m%d).sql
