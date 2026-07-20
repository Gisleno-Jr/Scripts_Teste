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

if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    printf '\n%s\n%s\n\n%s\n  %s\n\n' \
        'O repositório está em processo de merge.' \
        'Resolva o merge ou cancele antes de criar um novo commit.' \
        'Para cancelar o merge:' \
        'git merge --abort'
    exit 1
fi

branch_atual="$(git branch --show-current)"

if [[ -z "$branch_atual" ]]; then
    printf '\n%s\n%s\n\n' \
        'Não foi possível identificar a branch atual.' \
        'O repositório pode estar em estado detached HEAD.'
    exit 1
fi

if [[ "$branch_atual" == 'main' ]] ||
   [[ "$branch_atual" =~ ^develop/pcb-rev-[0-9]+\.[0-9]+$ ]]; then
    printf '\n%s\n  %s\n\n%s\n%s\n\n' \
        'Commits diretos não são permitidos na branch permanente:' \
        "$branch_atual" \
        'Crie uma branch temporária com:' \
        '  git nova-branch'
    exit 1
fi

if [[ ! "$branch_atual" =~ ^(feature|fix|hotfix|refactor|test|integration|docs)/pcb-rev-[0-9]+\.[0-9]+/[a-z0-9-]+/[a-z0-9-]+$ ]]; then
    printf '\n%s\n  %s\n\n%s\n\n' \
        'A branch atual não segue o padrão definido no manual:' \
        "$branch_atual" \
        '[TIPO]/pcb-rev-X.Y/[AREA]/[OBJETIVO]'
    exit 1
fi

# ============================================================
# Funções auxiliares
# ============================================================

remover_espacos_extremos() {
    printf '%s' "$1" |
        sed -E '
            s/^[[:space:]]+//;
            s/[[:space:]]+$//
        '
}

verificar_descricao_generica() {
    local texto="$1"
    local normalizado

    normalizado="$(
        printf '%s' "$texto" |
            tr '[:upper:]' '[:lower:]' |
            sed -E '
                s/[áàâãä]/a/g;
                s/[éèêë]/e/g;
                s/[íìîï]/i/g;
                s/[óòôõö]/o/g;
                s/[úùûü]/u/g;
                s/ç/c/g;
                s/^[[:space:]]+//;
                s/[[:space:]]+$//;
                s/[.]$//
            '
    )"

    case "$normalizado" in
        ajuste|ajustes|alteracao|alteracoes|teste|versao-nova|'versao nova'|correcao)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================
# Tipo de commit conforme o tipo da branch
# ============================================================

tipo_branch="${branch_atual%%/*}"

case "$tipo_branch" in
    feature)
        tipo_commit='feat'
        ;;
    fix|hotfix)
        tipo_commit='fix'
        ;;
    refactor)
        tipo_commit='refactor'
        ;;
    test)
        tipo_commit='test'
        ;;
    integration)
        tipo_commit='integration'
        ;;
    docs)
        tipo_commit='docs'
        ;;
    *)
        printf '\n%s\n\n' \
            'Não foi possível determinar o tipo do commit.'
        exit 1
        ;;
esac

# ============================================================
# Preparação dos arquivos
# ============================================================

printf '\n%s\n%s\n%s\n\n' \
    '======================================' \
    ' Criação de commit padronizado' \
    '======================================'

printf '%s\n  %s\n\n%s\n  %s\n' \
    'Branch atual:' \
    "$branch_atual" \
    'Tipo do commit:' \
    "$tipo_commit"

if git diff --cached --quiet; then
    if [[ -z "$(git status --porcelain)" ]]; then
        printf '\n%s\n\n' \
            'Não existem alterações para criar um commit.'
        exit 0
    fi

    printf '\n%s\n\n' \
        'Alterações encontradas:'

    git status --short

    printf '\n'

    read -rp \
        'Deseja adicionar todas as alterações ao commit? [S/n]: ' \
        adicionar_todas

    adicionar_todas="${adicionar_todas:-S}"

    if [[ "$adicionar_todas" =~ ^[Ss]$ ]]; then
        git add --all
    else
        printf '\n%s\n%s\n%s\n\n' \
            'Nenhum arquivo foi adicionado.' \
            'Adicione manualmente os arquivos desejados e execute novamente:' \
            '  git novo-commit'
        exit 0
    fi
fi

if git diff --cached --quiet; then
    printf '\n%s\n\n' \
        'Nenhuma alteração foi adicionada ao stage.'
    exit 1
fi

# ============================================================
# Descrição
# ============================================================

printf '\n'

read -rp \
    'Descrição objetiva da alteração: ' \
    descricao

descricao="$(remover_espacos_extremos "$descricao")"
descricao="${descricao%.}"

if [[ -z "$descricao" ]]; then
    printf '\n%s\n\n' \
        'A descrição não pode ficar vazia.'
    exit 1
fi

if verificar_descricao_generica "$descricao"; then
    printf '\n%s\n%s\n\n' \
        'A descrição informada é genérica demais.' \
        'Descreva objetivamente o que foi alterado.'
    exit 1
fi

mensagem="$tipo_commit: $descricao"

# ============================================================
# Confirmação
# ============================================================

printf '\n%s\n' \
    '--------------------------------------'

printf '%s\n\n  %s\n\n' \
    'Mensagem do commit:' \
    "$mensagem"

printf '%s\n\n' \
    'Arquivos incluídos:'

git diff --cached --name-status

printf '\n%s\n\n' \
    'Resumo das alterações:'

git diff --cached --stat

printf '%s\n\n' \
    '--------------------------------------'

read -rp \
    'Confirma a criação do commit e o envio para o GitHub? [S/n]: ' \
    confirmacao

confirmacao="${confirmacao:-S}"

if [[ ! "$confirmacao" =~ ^[Ss]$ ]]; then
    printf '\n%s\n%s\n\n' \
        'Commit cancelado.' \
        'Os arquivos permaneceram adicionados ao stage.'
    exit 0
fi

# ============================================================
# Commit e push
# ============================================================

if ! git commit -m "$mensagem"; then
    printf '\n%s\n\n' \
        'Não foi possível criar o commit.'
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    printf '\n%s\n%s\n\n' \
        'O commit foi criado localmente.' \
        'Não existe um remoto chamado origin configurado.'
    exit 0
fi

printf '\n%s\n  %s\n\n' \
    'Enviando o commit para o GitHub na branch:' \
    "$branch_atual"

if ! git push -u origin HEAD; then
    printf '\n%s\n%s\n\n' \
        'O commit foi criado localmente, mas o envio falhou.' \
        'Para tentar novamente, execute: git push -u origin HEAD'
    exit 1
fi

printf '\n%s\n\n' \
    'Commit criado e enviado para o GitHub com sucesso.'