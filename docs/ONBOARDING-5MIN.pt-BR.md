# Onboarding 5 Minutos (PT-BR)

Objetivo: subir o LinkLab local, criar um link curto e validar analytics em menos de 5 minutos.

## 1) Subir stack local

```bash
cd /root/linklab
make compose-up
```

## 2) Abrir interface

Acesse:
- Frontend: `http://localhost:8088`

Checklist visual rapido:
- Badge `API: ok` no topo da pagina.

## 3) Criar link curto

No formulario `Criar link curto`:
1. Cole uma URL longa (ex.: `https://example.com`).
2. Clique em `Encurtar`.
3. Copie o link no formato `http://localhost:8088/r/<codigo>`.

## 4) Testar redirect + stats

1. Abra o link curto gerado.
2. Volte ao frontend e use `Consultar stats`.
3. Confirme:
   - `clicks >= 1`
   - `last_click` preenchido

## 5) Smoke test por terminal (opcional)

```bash
curl -s http://localhost:8080/health
bash cli/linklab.sh shorten https://example.com
bash cli/linklab.sh stats <codigo>
```

## 6) Encerrar

```bash
make compose-down
```

## Comandos de emergencia

Se algo falhar:

```bash
docker-compose ps
docker-compose logs --tail=80 api worker frontend
make compose-down && make compose-up
```
