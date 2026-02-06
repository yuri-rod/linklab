# Guia Git do Repositorio (PT-BR)

## Inicializar repositorio local

No diretorio do projeto:

```bash
git init -b main
git add .
git commit -m "chore: bootstrap do repositorio"
```

## Conectar remoto no GitHub

Crie um repositorio vazio no GitHub e rode:

```bash
git remote add origin https://github.com/<seu-usuario>/linklab.git
git push -u origin main
```

## Fluxo recomendado de branches

- `main`: branch estavel
- `feat/*`: novas features
- `fix/*`: correcoes

Exemplo:

```bash
git checkout -b feat/frontend-local
git add .
git commit -m "feat: frontend local"
git push -u origin feat/frontend-local
```

## Convencao de commits sugerida

- `feat:` nova funcionalidade
- `fix:` correcao
- `docs:` documentacao
- `chore:` manutencao
- `refactor:` refatoracao sem alterar comportamento
