#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Validações iniciais
# ============================================================

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '\n%s\n\n' \
        'Este comando precisa ser executado dentro de um repositório Git.'
    exit 1
fi

ARQUIVOS_OBRIGATORIOS=(
    'scripts/configurar-atalhos.sh'
    'scripts/nova-branch.sh'
    'scripts/novo-commit.sh'
    'scripts/novo-pr.sh'
    'scripts/nova-tag.sh'
)

for arquivo in "${ARQUIVOS_OBRIGATORIOS[@]}"; do
    if [[ ! -f "$arquivo" ]]; then
        printf '\n%s\n  %s\n\n' \
            'Arquivo obrigatório não encontrado:' \
            "$arquivo"
        exit 1
    fi
done

# ============================================================
# Cabeçalho
# ============================================================

printf '\n%s\n%s\n%s\n\n' \
    '======================================' \
    ' Configuração dos atalhos Git' \
    '======================================'

# ============================================================
# Remoção de aliases antigos
# ============================================================

git config \
    --local \
    --unset alias.criar-tag \
    2>/dev/null || true

git config \
    --local \
    --unset alias.criar-pr \
    2>/dev/null || true

# ============================================================
# Configuração dos aliases
# ============================================================

git config \
    --local \
    alias.nova-branch \
    '!bash scripts/nova-branch.sh'

git config \
    --local \
    alias.novo-commit \
    '!bash scripts/novo-commit.sh'

git config \
    --local \
    alias.novo-pr \
    '!bash scripts/novo-pr.sh'

git config \
    --local \
    alias.nova-tag \
    '!bash scripts/nova-tag.sh'

# ============================================================
# Permissões de execução
# ============================================================

chmod +x scripts/configurar-atalhos.sh
chmod +x scripts/nova-branch.sh
chmod +x scripts/novo-commit.sh
chmod +x scripts/novo-pr.sh
chmod +x scripts/nova-tag.sh

# ============================================================
# Registro das permissões no Git
# ============================================================

git update-index \
    --chmod=+x scripts/configurar-atalhos.sh \
    2>/dev/null || true

git update-index \
    --chmod=+x scripts/nova-branch.sh \
    2>/dev/null || true

git update-index \
    --chmod=+x scripts/novo-commit.sh \
    2>/dev/null || true

git update-index \
    --chmod=+x scripts/novo-pr.sh \
    2>/dev/null || true

git update-index \
    --chmod=+x scripts/nova-tag.sh \
    2>/dev/null || true

# ============================================================
# Confirmação
# ============================================================

printf '%s\n\n' \
    'Atalhos configurados com sucesso.'

printf '%s\n' \
    'Comandos disponíveis:' \
    '' \
    '  git nova-branch' \
    '  git novo-commit' \
    '  git novo-pr' \
    '  git nova-tag' \
    '' \
    'Os atalhos foram configurados somente neste repositório.' \
    '' \
    ''