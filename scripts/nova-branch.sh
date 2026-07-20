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
        'Resolva o merge ou cancele antes de criar uma nova branch.' \
        'Para cancelar o merge:' \
        'git merge --abort'
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    printf '\n%s\n\n' \
        'Existem alterações pendentes no repositório:'

    git status --short

    printf '\n%s\n%s\n%s\n\n' \
        'Antes de criar uma branch, faça commit, descarte as alterações' \
        'ou guarde-as temporariamente com:' \
        '  git stash push -u'
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    printf '\n%s\n%s\n\n' \
        'Não existe um remoto chamado origin configurado.' \
        'Configure o repositório oficial antes de criar uma branch.'
    exit 1
fi

# ============================================================
# Funções auxiliares
# ============================================================

normalizar() {
    local texto="$1"

    if command -v python >/dev/null 2>&1; then
        PYTHONUTF8=1 python -c '
import re
import sys
import unicodedata

texto = sys.argv[1]
texto = unicodedata.normalize("NFKD", texto)
texto = texto.encode("ascii", "ignore").decode("ascii")
texto = texto.lower()
texto = re.sub(r"[^a-z0-9]+", "-", texto)
texto = texto.strip("-")
print(texto)
' "$texto"
        return
    fi

    if command -v py >/dev/null 2>&1; then
        PYTHONUTF8=1 py -3 -c '
import re
import sys
import unicodedata

texto = sys.argv[1]
texto = unicodedata.normalize("NFKD", texto)
texto = texto.encode("ascii", "ignore").decode("ascii")
texto = texto.lower()
texto = re.sub(r"[^a-z0-9]+", "-", texto)
texto = texto.strip("-")
print(texto)
' "$texto"
        return
    fi

    if command -v iconv >/dev/null 2>&1; then
        texto="$(
            printf '%s' "$texto" |
                iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null ||
                printf '%s' "$texto"
        )"
    fi

    printf '%s' "$texto" |
        tr '[:upper:]' '[:lower:]' |
        sed -E '
            s/[^a-z0-9]+/-/g;
            s/^-+//;
            s/-+$//
        '
}

branch_existe_local() {
    git show-ref --verify --quiet "refs/heads/$1"
}

branch_existe_remota() {
    git show-ref --verify --quiet "refs/remotes/origin/$1"
}

branch_existe() {
    branch_existe_local "$1" || branch_existe_remota "$1"
}

listar_develops() {
    {
        git for-each-ref \
            --format='%(refname:short)' \
            refs/heads/develop/pcb-rev-* \
            2>/dev/null || true

        git for-each-ref \
            --format='%(refname:short)' \
            refs/remotes/origin/develop/pcb-rev-* \
            2>/dev/null |
            sed 's#^origin/##' || true
    } |
        awk '/^develop\/pcb-rev-[0-9]+\.[0-9]+$/ { print }' |
        sort -u
}

escolher_develop() {
    local -a develops
    local -a opcoes
    local escolha

    mapfile -t develops < <(listar_develops)

    if [[ ${#develops[@]} -eq 0 ]]; then
        printf '\n%s\n%s\n\n' \
            'Nenhuma branch develop/pcb-rev-X.Y foi encontrada.' \
            'Solicite a criação da branch permanente correspondente.'
        exit 1
    fi

    printf '\n%s\n\n' \
        'Selecione a revisão de PCB afetada:'

    opcoes=("${develops[@]}" 'Cancelar')

    PS3='Opção: '

    select escolha in "${opcoes[@]}"; do
        if [[ "$escolha" == 'Cancelar' ]]; then
            printf '%s\n' 'Operação cancelada.'
            exit 0
        fi

        if [[ -n "${escolha:-}" ]]; then
            printf '%s' "$escolha"
            return
        fi

        printf '%s\n' 'Opção inválida.'
    done
}

ir_para_branch() {
    local branch="$1"

    if branch_existe_local "$branch"; then
        git switch "$branch"
        return
    fi

    if branch_existe_remota "$branch"; then
        git switch --track -c "$branch" "origin/$branch"
        return
    fi

    printf '\n%s\n  %s\n\n' \
        'A branch base não foi encontrada:' \
        "$branch"
    exit 1
}

atualizar_branch_base() {
    local branch="$1"

    printf '\n%s\n  %s\n\n' \
        'Atualizando a branch base:' \
        "$branch"

    if ! git pull --ff-only origin "$branch"; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível atualizar a branch base automaticamente.' \
            'Resolva a divergência antes de criar uma nova branch.'
        exit 1
    fi
}

# ============================================================
# Atualização das referências remotas
# ============================================================

printf '\n%s\n\n' \
    'Atualizando as referências do GitHub...'

if ! git fetch origin --prune; then
    printf '\n%s\n%s\n\n' \
        'Não foi possível acessar o repositório remoto.' \
        'Verifique sua conexão, suas credenciais e suas permissões.'
    exit 1
fi

# ============================================================
# Seleção do tipo da branch
# ============================================================

tipos=(
    'feature'
    'fix'
    'hotfix'
    'refactor'
    'test'
    'integration'
    'docs'
    'Cancelar'
)

printf '\n%s\n%s\n%s\n\n' \
    '======================================' \
    ' Criação de branch temporária' \
    '======================================'

printf '%s\n' \
    'Selecione o tipo da alteração:'

PS3='Opção: '

select tipo in "${tipos[@]}"; do
    case "$REPLY" in
        1|2|3|4|5|6|7)
            break
            ;;
        8)
            printf '%s\n' 'Operação cancelada.'
            exit 0
            ;;
        *)
            printf '%s\n' \
                'Opção inválida. Digite um número entre 1 e 8.'
            ;;
    esac
done

# ============================================================
# Definição da revisão e da branch base
# ============================================================

develop_escolhida="$(escolher_develop)"
revisao="${develop_escolhida#develop/}"

if [[ "$tipo" == 'hotfix' ]]; then
    branch_base='main'

    if ! branch_existe "$branch_base"; then
        printf '\n%s\n\n' \
            'A branch main não foi encontrada.'
        exit 1
    fi

    printf '\n%s\n%s\n\n' \
        'O hotfix será criado a partir da versão oficial na main.' \
        "Após a aprovação, a correção também deverá ser integrada em $develop_escolhida."
else
    branch_base="$develop_escolhida"
fi

# ============================================================
# Área e objetivo
# ============================================================

printf '\n'

read -rp \
    'Área afetada, por exemplo Comunicação ou Motor: ' \
    area_digitada

read -rp \
    'Objetivo da alteração, por exemplo Adicionar Modbus TCP: ' \
    objetivo_digitado

area="$(normalizar "$area_digitada")"
objetivo="$(normalizar "$objetivo_digitado")"

if [[ -z "$area" ]]; then
    printf '\n%s\n\n' \
        'A área informada é inválida.'
    exit 1
fi

if [[ -z "$objetivo" ]]; then
    printf '\n%s\n\n' \
        'O objetivo informado é inválido.'
    exit 1
fi

nova_branch="$tipo/$revisao/$area/$objetivo"

if branch_existe "$nova_branch"; then
    printf '\n%s\n  %s\n\n' \
        'A branch já existe:' \
        "$nova_branch"
    exit 1
fi

# ============================================================
# Confirmação
# ============================================================

printf '\n%s\n  %s\n\n%s\n  %s\n\n' \
    'Nova branch:' \
    "$nova_branch" \
    'Branch base:' \
    "$branch_base"

read -rp \
    'Confirma a criação da branch? [S/n]: ' \
    confirmacao

confirmacao="${confirmacao:-S}"

if [[ ! "$confirmacao" =~ ^[Ss]$ ]]; then
    printf '%s\n' 'Operação cancelada.'
    exit 0
fi

# ============================================================
# Criação e envio
# ============================================================

ir_para_branch "$branch_base"
atualizar_branch_base "$branch_base"

git switch -c "$nova_branch"

printf '\n%s\n  %s\n\n' \
    'Enviando a nova branch para o GitHub:' \
    "$nova_branch"

if ! git push -u origin HEAD; then
    printf '\n%s\n%s\n\n' \
        'A branch foi criada localmente, mas o envio falhou.' \
        'Verifique sua conexão, suas credenciais e suas permissões.'
    exit 1
fi

printf '\n%s\n  %s\n\n' \
    'Branch criada e enviada para o GitHub com sucesso:' \
    "$nova_branch"