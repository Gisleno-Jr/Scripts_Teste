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
        'Antes de criar ou trocar de branch, faça commit,' \
        'descarte as alterações ou guarde-as temporariamente com:' \
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

validar_revisao() {
    local revisao="$1"

    [[ "$revisao" =~ ^[0-9]+\.[0-9]+$ ]]
}

branch_existe_local() {
    local branch="$1"

    git show-ref \
        --verify \
        --quiet \
        "refs/heads/$branch"
}

branch_existe_remota() {
    local branch="$1"

    git show-ref \
        --verify \
        --quiet \
        "refs/remotes/origin/$branch"
}

branch_existe() {
    local branch="$1"

    branch_existe_local "$branch" ||
        branch_existe_remota "$branch"
}

listar_develops() {
    {
        git for-each-ref \
            --format='%(refname:short)' \
            refs/heads \
            2>/dev/null || true

        git for-each-ref \
            --format='%(refname:short)' \
            refs/remotes/origin \
            2>/dev/null |
            sed 's#^origin/##' || true
    } |
        awk '
            /^develop\/pcb-rev-[0-9]+\.[0-9]+$/ {
                print
            }
        ' |
        sort -u
}

atualizar_referencias_remotas() {
    printf '\n%s\n\n' \
        'Atualizando as referências do GitHub...'

    if ! git fetch origin --prune; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível acessar o repositório remoto.' \
            'Verifique sua conexão, suas credenciais e suas permissões.'

        exit 1
    fi
}

ir_para_branch() {
    local branch="$1"

    if branch_existe_local "$branch"; then
        git switch "$branch"
        return
    fi

    if branch_existe_remota "$branch"; then
        git switch \
            --track \
            -c "$branch" \
            "origin/$branch"
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

    if branch_existe_remota "$branch"; then
        if ! git pull --ff-only origin "$branch"; then
            printf '\n%s\n%s\n\n' \
                'Não foi possível atualizar a branch base automaticamente.' \
                'Resolva a divergência antes de criar uma nova branch.'

            exit 1
        fi

        return
    fi

    printf '%s\n%s\n\n' \
        'A branch base existe apenas localmente.' \
        'A versão local será utilizada.'
}

enviar_branch_para_github() {
    local branch_atual

    branch_atual="$(git branch --show-current)"

    if [[ -z "$branch_atual" ]]; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível identificar a branch atual.' \
            'A branch pode estar em estado detached HEAD.'

        exit 1
    fi

    printf '\n%s\n  %s\n\n' \
        'Enviando a branch para o GitHub:' \
        "$branch_atual"

    if ! git push -u origin HEAD; then
        printf '\n%s\n%s\n\n' \
            'A branch foi criada localmente, mas o envio falhou.' \
            'Verifique sua conexão, suas credenciais e suas permissões.'

        exit 1
    fi

    printf '\n%s\n  %s\n\n' \
        'Branch criada e enviada para o GitHub com sucesso:' \
        "$branch_atual"
}

# ============================================================
# Seleção de branch develop existente
# ============================================================

selecionar_develop_existente() {
    local -a develops
    local -a opcoes
    local escolha

    mapfile -t develops < <(
        listar_develops
    )

    if [[ ${#develops[@]} -eq 0 ]]; then
        printf '\n%s\n%s\n%s\n\n' \
            'Nenhuma branch develop/pcb-rev-X.Y foi encontrada.' \
            'Antes de criar uma branch temporária, crie a branch develop' \
            'correspondente à revisão física da PCB.'

        return 1
    fi

    printf '\n%s\n\n' \
        'Selecione a revisão de PCB afetada:'

    opcoes=(
        "${develops[@]}"
        'Cancelar'
    )

    PS3='Opção: '

    select escolha in "${opcoes[@]}"; do
        if [[ "$escolha" == 'Cancelar' ]]; then
            printf '%s\n' \
                'Operação cancelada.'

            return 1
        fi

        if [[ -n "${escolha:-}" ]]; then
            develop_escolhida="$escolha"
            return 0
        fi

        printf '%s\n' \
            'Opção inválida.'
    done
}

# ============================================================
# Criação de branch a partir de uma base
# ============================================================

criar_branch_a_partir_de_base() {
    local nova_branch="$1"
    local branch_base="$2"
    local confirmacao

    if branch_existe "$nova_branch"; then
        printf '\n%s\n  %s\n\n' \
            'A branch já existe:' \
            "$nova_branch"

        return 1
    fi

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
        printf '%s\n' \
            'Operação cancelada.'

        return 0
    fi

    ir_para_branch "$branch_base"
    atualizar_branch_base "$branch_base"

    git switch -c "$nova_branch"

    enviar_branch_para_github
}

# ============================================================
# Criação de branch temporária
# ============================================================

montar_branch_temporaria() {
    local tipo
    local revisao
    local branch_base
    local area_digitada
    local objetivo_digitado
    local area
    local objetivo
    local nova_branch

    local -a tipos=(
        'feature'
        'fix'
        'hotfix'
        'refactor'
        'test'
        'integration'
        'docs'
        'Cancelar'
    )

    if ! selecionar_develop_existente; then
        return 0
    fi

    revisao="${develop_escolhida#develop/}"

    printf '\n%s\n' \
        'Selecione o tipo da alteração:'

    PS3='Opção: '

    select tipo in "${tipos[@]}"; do
        case "$REPLY" in
            1|2|3|4|5|6|7)
                break
                ;;

            8)
                printf '%s\n' \
                    'Operação cancelada.'

                return 0
                ;;

            *)
                printf '%s\n' \
                    'Opção inválida. Digite um número entre 1 e 8.'
                ;;
        esac
    done

    if [[ "$tipo" == 'hotfix' ]]; then
        branch_base='main'

        if ! branch_existe "$branch_base"; then
            printf '\n%s\n\n' \
                'A branch main não foi encontrada.'

            return 1
        fi

        printf '\n%s\n%s\n%s\n\n' \
            'ATENÇÃO:' \
            'O hotfix será criado a partir da versão oficial disponível na main.' \
            "Após a aprovação, a correção também deverá ser integrada em $develop_escolhida."
    else
        branch_base="$develop_escolhida"
    fi

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

        return 1
    fi

    if [[ -z "$objetivo" ]]; then
        printf '\n%s\n\n' \
            'O objetivo informado é inválido.'

        return 1
    fi

    nova_branch="$tipo/$revisao/$area/$objetivo"

    criar_branch_a_partir_de_base \
        "$nova_branch" \
        "$branch_base"
}

# ============================================================
# Criação de branch develop
# ============================================================

montar_branch_develop() {
    local revisao
    local nova_develop
    local confirmacao

    printf '\n%s\n%s\n%s\n\n' \
        '======================================' \
        ' Criação de branch develop' \
        '======================================'

    printf '%s\n%s\n\n' \
        'A nova branch permanente será criada a partir da main.' \
        'Ela deverá representar uma revisão física específica da PCB.'

    read -rp \
        'Revisão da PCB, por exemplo 1.0 ou 1.1: ' \
        revisao

    if ! validar_revisao "$revisao"; then
        printf '\n%s\n%s\n\n' \
            'Revisão inválida.' \
            'Utilize o formato X.Y, por exemplo: 1.0, 1.1 ou 2.0.'

        return 1
    fi

    nova_develop="develop/pcb-rev-$revisao"

    if branch_existe "$nova_develop"; then
        printf '\n%s\n  %s\n\n' \
            'A branch já existe:' \
            "$nova_develop"

        return 1
    fi

    if ! branch_existe 'main'; then
        printf '\n%s\n\n' \
            'A branch main não foi encontrada.'

        return 1
    fi

    printf '\n%s\n  %s\n\n%s\n  %s\n\n' \
        'Nova branch permanente:' \
        "$nova_develop" \
        'Branch base:' \
        'main'

    printf '%s\n%s\n\n' \
        'ATENÇÃO:' \
        'Essa branch representará a linha de desenvolvimento da revisão informada da PCB.'

    read -rp \
        'Confirma a criação da branch develop? [S/n]: ' \
        confirmacao

    confirmacao="${confirmacao:-S}"

    if [[ ! "$confirmacao" =~ ^[Ss]$ ]]; then
        printf '%s\n' \
            'Operação cancelada.'

        return 0
    fi

    ir_para_branch 'main'
    atualizar_branch_base 'main'

    git switch -c "$nova_develop"

    enviar_branch_para_github
}

# ============================================================
# Atualização das referências
# ============================================================

atualizar_referencias_remotas

# ============================================================
# Menu principal
# ============================================================

printf '\n%s\n%s\n%s\n\n' \
    '======================================' \
    ' Criação de branch' \
    '======================================'

opcoes_inicio=(
    'Criar branch temporária padronizada'
    'Criar nova branch develop/pcb-rev-X.Y'
    'Cancelar'
)

printf '%s\n' \
    'O que deseja criar?'

PS3='Opção: '

select escolha_inicio in "${opcoes_inicio[@]}"; do
    case "$REPLY" in
        1)
            montar_branch_temporaria
            exit $?
            ;;

        2)
            montar_branch_develop
            exit $?
            ;;

        3)
            printf '%s\n' \
                'Operação cancelada.'

            exit 0
            ;;

        *)
            printf '%s\n' \
                'Opção inválida. Digite 1, 2 ou 3.'
            ;;
    esac
done