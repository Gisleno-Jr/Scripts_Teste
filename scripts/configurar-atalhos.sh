#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Funções auxiliares
# ============================================================

encerrar_com_erro() {
    printf '\n%s\n\n' "$1"
    exit 1
}

verificar_arquivo() {
    local arquivo="$1"

    if [[ ! -f "$arquivo" ]]; then
        printf '\n'
        printf 'Arquivo não encontrado:\n'
        printf '  %s\n' "$arquivo"
        printf '\n'
        exit 1
    fi
}

# ============================================================
# Verificação do repositório
# ============================================================

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    encerrar_com_erro \
        'Este comando deve ser executado dentro de um repositório Git.'
fi

# ============================================================
# Definição dos arquivos
# ============================================================

arquivo_configurar='scripts/configurar-atalhos.sh'
arquivo_branch='scripts/nova-branch.sh'
arquivo_commit='scripts/novo-commit.sh'
arquivo_pr='scripts/novo-pr.sh'
arquivo_tag='scripts/nova-tag.sh'
arquivo_exportar='scripts/exportar-versao.sh'

# ============================================================
# Verificação da existência dos scripts
# ============================================================

verificar_arquivo "$arquivo_configurar"
verificar_arquivo "$arquivo_branch"
verificar_arquivo "$arquivo_commit"
verificar_arquivo "$arquivo_pr"
verificar_arquivo "$arquivo_tag"
verificar_arquivo "$arquivo_exportar"

# ============================================================
# Remoção de aliases antigos
# ============================================================

git config --local --unset-all alias.criar-tag 2>/dev/null || true
git config --local --unset-all alias.criar-pr 2>/dev/null || true

# Remove versões anteriores dos aliases atuais, quando existirem.
git config --local --unset-all alias.nova-branch 2>/dev/null || true
git config --local --unset-all alias.novo-commit 2>/dev/null || true
git config --local --unset-all alias.novo-pr 2>/dev/null || true
git config --local --unset-all alias.nova-tag 2>/dev/null || true
git config --local --unset-all alias.exportar-versao 2>/dev/null || true

# ============================================================
# Configuração das permissões de execução
# ============================================================

chmod +x "$arquivo_configurar"
chmod +x "$arquivo_branch"
chmod +x "$arquivo_commit"
chmod +x "$arquivo_pr"
chmod +x "$arquivo_tag"
chmod +x "$arquivo_exportar"

git update-index --chmod=+x "$arquivo_configurar"
git update-index --chmod=+x "$arquivo_branch"
git update-index --chmod=+x "$arquivo_commit"
git update-index --chmod=+x "$arquivo_pr"
git update-index --chmod=+x "$arquivo_tag"
git update-index --chmod=+x "$arquivo_exportar"

# ============================================================
# Configuração dos aliases locais
# ============================================================

git config --local alias.nova-branch \
    '!bash scripts/nova-branch.sh'

git config --local alias.novo-commit \
    '!bash scripts/novo-commit.sh'

git config --local alias.novo-pr \
    '!bash scripts/novo-pr.sh'

git config --local alias.nova-tag \
    '!bash scripts/nova-tag.sh'

git config --local alias.exportar-versao \
    '!bash scripts/exportar-versao.sh'

# ============================================================
# Resultado
# ============================================================

printf '\n'
printf 'Configuração concluída com sucesso.\n'
printf '\n'

printf 'Comandos disponíveis neste repositório:\n'
printf '\n'
printf '  git nova-branch\n'
printf '  git novo-commit\n'
printf '  git novo-pr\n'
printf '  git nova-tag\n'
printf '  git exportar-versao\n'
printf '\n'

printf 'Os aliases foram configurados localmente neste repositório.\n'
printf '\n'
printf 'Para verificar os aliases configurados, execute:\n'
printf '  git config --local --get-regexp '\''^alias\.'\''\n'
printf '\n'