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

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
        pwd
)"

TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -d "$SCRIPT_DIR" ]]; then
    mkdir -p "$TMP_DIR/scripts"
    cp -R "$SCRIPT_DIR/." "$TMP_DIR/scripts/"
fi

# ============================================================
# Normalização de textos
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

normalizar_branch_completa() {
    local entrada="$1"
    local resultado=''
    local parte
    local parte_normalizada
    local -a partes

    IFS='/' read -ra partes <<< "$entrada"

    for parte in "${partes[@]}"; do
        parte_normalizada="$(normalizar "$parte")"

        if [[ -n "$parte_normalizada" ]]; then
            if [[ -z "$resultado" ]]; then
                resultado="$parte_normalizada"
            else
                resultado="$resultado/$parte_normalizada"
            fi
        fi
    done

    printf '%s' "$resultado"
}

validar_revisao() {
    local revisao="$1"

    [[ "$revisao" =~ ^[0-9]+\.[0-9]+$ ]]
}

# ============================================================
# Validação do estado do repositório
# ============================================================

verificar_alteracoes_pendentes() {
    if [[ -z "$(git status --porcelain)" ]]; then
        return
    fi

    printf '\n%s\n\n' \
        'Existem alterações pendentes no repositório:'

    git status --short

    printf '\n%s\n\n' \
        'Antes de criar ou trocar de branch, faça uma destas ações:'

    printf '%s\n' \
        '  1. Crie um commit com as alterações.' \
        '  2. Guarde temporariamente as alterações:' \
        '     git stash push -u' \
        '  3. Descarte as alterações, caso não sejam necessárias.' \
        ''

    exit 1
}

verificar_origin() {
    git remote get-url origin >/dev/null 2>&1
}

atualizar_referencias_remotas() {
    if ! verificar_origin; then
        printf '\n%s\n%s\n\n' \
            'Aviso: não existe um remoto chamado origin configurado.' \
            'Somente as branches locais poderão ser utilizadas.'
        return
    fi

    printf '\n%s\n\n' \
        'Atualizando as referências do GitHub...'

    if ! git fetch origin --prune; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível atualizar as referências do GitHub.' \
            'Verifique sua conexão, suas credenciais e suas permissões.'
        exit 1
    fi
}

# ============================================================
# Consulta de branches
# ============================================================

listar_branches() {
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
            $0 != "" &&
            $0 != "HEAD" &&
            $0 != "origin/HEAD" {
                print
            }
        ' |
        sort -u
}

listar_develops_existentes() {
    listar_branches |
        awk '
            /^develop\/pcb-rev-[0-9]+\.[0-9]+$/ {
                print
            }
        ' |
        sort -u
}

listar_develops_e_main_existentes() {
    listar_branches |
        awk '
            /^develop\/pcb-rev-[0-9]+\.[0-9]+$/ ||
            /^main$/ {
                print
            }
        ' |
        sort -u
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

# ============================================================
# Seleção de branches
# ============================================================

escolher_develop_ou_main_existente() {
    local -a bases
    local -a opcoes
    local escolha

    mapfile -t bases < <(
        listar_develops_e_main_existentes
    )

    if [[ ${#bases[@]} -eq 0 ]]; then
        printf '\n%s\n\n' \
            'Nenhuma branch develop/pcb-rev-X.Y ou main foi encontrada.' \
            >&2
        return 130
    fi

    printf '\n%s\n\n' \
        'Selecione uma branch develop existente ou a main:' \
        >&2

    opcoes=("${bases[@]}" 'Cancelar')

    PS3='Opção: '

    select escolha in "${opcoes[@]}"; do
        if [[ "$escolha" == 'Cancelar' ]]; then
            printf '%s\n' \
                'Operação cancelada.' \
                >&2
            return 130
        fi

        if [[ -n "${escolha:-}" ]]; then
            printf '%s' "$escolha"
            return 0
        fi

        printf '%s\n' \
            'Opção inválida.' \
            >&2
    done
}

escolher_branch_existente() {
    local -a branches
    local -a opcoes
    local branch_escolhida

    mapfile -t branches < <(
        listar_branches
    )

    if [[ ${#branches[@]} -eq 0 ]]; then
        printf '%s\n' \
            'Nenhuma branch existente foi encontrada.' \
            >&2
        return 130
    fi

    printf '\n%s\n\n' \
        'Branches disponíveis:' \
        >&2

    opcoes=("${branches[@]}" 'Cancelar')

    PS3='Escolha a branch base: '

    select branch_escolhida in "${opcoes[@]}"; do
        if [[ "$branch_escolhida" == 'Cancelar' ]]; then
            printf '%s\n' \
                'Operação cancelada.' \
                >&2
            return 130
        fi

        if [[ -n "${branch_escolhida:-}" ]]; then
            printf '%s' "$branch_escolhida"
            return 0
        fi

        printf '%s\n' \
            'Opção inválida.' \
            >&2
    done
}

digitar_nova_revisao_pcb() {
    local revisao_digitada
    local develop
    local -a develops

    printf '\n%s\n\n' \
        'Branches develop existentes:' \
        >&2

    mapfile -t develops < <(
        listar_develops_existentes
    )

    if [[ ${#develops[@]} -eq 0 ]]; then
        printf '  %s\n' \
            'Nenhuma develop existente.' \
            >&2
    else
        for develop in "${develops[@]}"; do
            printf '  - %s\n' "$develop" >&2
        done
    fi

    printf '\n' >&2

    read -rp \
        'Digite a nova revisão da PCB, por exemplo 1.0 ou 1.1, ou deixe vazio para cancelar: ' \
        revisao_digitada

    if [[ -z "$revisao_digitada" ]]; then
        printf '%s\n' \
            'Operação cancelada.' \
            >&2
        return 130
    fi

    if ! validar_revisao "$revisao_digitada"; then
        printf '\n%s\n%s\n\n' \
            'Revisão inválida.' \
            'Use o formato X.Y, por exemplo: 1.0, 1.1 ou 2.0.' \
            >&2
        return 130
    fi

    printf '%s' "$revisao_digitada"
}

# ============================================================
# Troca e atualização de branches
# ============================================================

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
        'A branch informada não foi encontrada:' \
        "$branch"

    exit 1
}

atualizar_branch_base() {
    local branch="$1"

    if ! verificar_origin; then
        printf '\n%s\n\n' \
            'A branch base será utilizada somente com a versão local.'
        return
    fi

    if ! branch_existe_remota "$branch"; then
        printf '\n%s\n  %s\n\n%s\n\n' \
            'A branch base não possui uma versão correspondente no GitHub:' \
            "origin/$branch" \
            'A nova branch será criada a partir da versão local.'
        return
    fi

    printf '\n%s\n  %s\n\n' \
        'Atualizando a branch base:' \
        "$branch"

    if ! git pull --ff-only origin "$branch"; then
        printf '\n%s\n%s\n%s\n\n' \
            'Não foi possível atualizar a branch base automaticamente.' \
            'Podem existir commits locais divergentes.' \
            'Resolva a situação antes de criar uma nova branch.'
        exit 1
    fi
}

# ============================================================
# Preservação da pasta scripts
# ============================================================

garantir_scripts_na_branch() {
    if [[ -d "$TMP_DIR/scripts" ]]; then
        mkdir -p scripts
        cp -R "$TMP_DIR/scripts/." scripts/
    else
        mkdir -p scripts
        touch scripts/.gitkeep
    fi

    git add scripts

    if ! git diff --cached --quiet; then
        git commit \
            -m 'docs: adiciona scripts de automacao'
    fi
}

# ============================================================
# Envio da branch
# ============================================================

enviar_branch_para_github() {
    local branch_atual

    branch_atual="$(git branch --show-current)"

    if [[ -z "$branch_atual" ]]; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível identificar a branch atual.' \
            'A branch pode estar em estado detached HEAD.'
        return 1
    fi

    if ! verificar_origin; then
        printf '\n%s\n%s\n\n%s\n  %s\n\n' \
            'Não existe um remoto chamado origin configurado.' \
            'A branch foi criada apenas localmente.' \
            'Configure o remoto antes de enviar:' \
            'git remote add origin URL_DO_REPOSITORIO'
        return 0
    fi

    printf '\n%s\n%s\n  %s\n\n' \
        'Enviando a branch para o GitHub...' \
        'Branch:' \
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
# Criação de branch a partir de uma base
# ============================================================

criar_branch_a_partir_de_base() {
    local nova_branch="$1"
    local branch_base="$2"

    if branch_existe "$nova_branch"; then
        printf '\n%s\n  %s\n\n' \
            'A branch já existe:' \
            "$nova_branch"
        exit 1
    fi

    verificar_alteracoes_pendentes

    ir_para_branch "$branch_base"
    atualizar_branch_base "$branch_base"

    git switch -c "$nova_branch"

    garantir_scripts_na_branch

    printf '\n%s\n%s\n%s\n\n%s\n\n' \
        '======================================' \
        ' Branch criada com sucesso' \
        '======================================' \
        "$nova_branch"

    enviar_branch_para_github

    exit 0
}

# ============================================================
# Criação de branch sem histórico
# ============================================================

criar_branch_vazia() {
    local nova_branch="$1"
    local confirma_vazia

    if branch_existe "$nova_branch"; then
        printf '\n%s\n  %s\n\n' \
            'A branch já existe:' \
            "$nova_branch"
        exit 1
    fi

    verificar_alteracoes_pendentes

    printf '\n%s\n\n%s\n%s\n\n' \
        'Você escolheu criar uma branch vazia.' \
        'Ela será criada sem o histórico anterior do projeto,' \
        'mas receberá a pasta scripts/.'

    read -rp \
        'Confirma a criação da branch vazia com scripts/? [S/n]: ' \
        confirma_vazia

    confirma_vazia="${confirma_vazia:-S}"

    if [[ ! "$confirma_vazia" =~ ^[Ss]$ ]]; then
        printf '%s\n' \
            'Operação cancelada.'
        exit 0
    fi

    git switch --orphan "$nova_branch"

    git rm -rf . >/dev/null 2>&1 || true

    find . \
        -mindepth 1 \
        -maxdepth 1 \
        ! -name '.git' \
        -exec rm -rf {} +

    if [[ -d "$TMP_DIR/scripts" ]]; then
        mkdir -p scripts
        cp -R "$TMP_DIR/scripts/." scripts/
    else
        mkdir -p scripts
        touch scripts/.gitkeep
    fi

    git add scripts

    git commit \
        -m 'docs: adiciona scripts de automacao'

    printf '\n%s\n%s\n%s\n\n%s\n\n' \
        '======================================' \
        ' Branch vazia criada com scripts' \
        '======================================' \
        "$nova_branch"

    enviar_branch_para_github

    exit 0
}

# ============================================================
# Confirmação da origem da branch
# ============================================================

escolher_origem_e_criar() {
    local nova_branch="$1"
    local branch_base_esperada="${2:-}"
    local confirmacao
    local escolha_base
    local branch_atual
    local branch_escolhida
    local -a opcoes_base

    atualizar_referencias_remotas

    if branch_existe "$nova_branch"; then
        printf '\n%s\n  %s\n\n%s\n\n' \
            'A branch já existe:' \
            "$nova_branch" \
            'Operação cancelada.'
        exit 1
    fi

    printf '\n%s\n  %s\n' \
        'Nova branch:' \
        "$nova_branch"

    if [[ -n "$branch_base_esperada" ]]; then
        printf '\n%s\n  %s\n' \
            'Branch base:' \
            "$branch_base_esperada"
    fi

    printf '\n'

    read -rp \
        'Confirma a criação da branch? [S/n]: ' \
        confirmacao

    confirmacao="${confirmacao:-S}"

    if [[ ! "$confirmacao" =~ ^[Ss]$ ]]; then
        printf '%s\n' \
            'Operação cancelada.'
        exit 0
    fi

    if [[ -n "$branch_base_esperada" ]] &&
        branch_existe "$branch_base_esperada"; then

        criar_branch_a_partir_de_base \
            "$nova_branch" \
            "$branch_base_esperada"
    fi

    if [[ -n "$branch_base_esperada" ]]; then
        printf '\n%s\n  %s\n\n' \
            'A branch base esperada não foi encontrada:' \
            "$branch_base_esperada"
    fi

    printf '%s\n\n' \
        'Escolha como deseja criar a nova branch:'

    opcoes_base=(
        'Usar a branch atual como base'
        'Escolher uma branch existente como base'
        'Criar a nova branch vazia com scripts'
        'Cancelar'
    )

    PS3='Opção: '

    select escolha_base in "${opcoes_base[@]}"; do
        case "$REPLY" in
            1)
                branch_atual="$(git branch --show-current)"

                if [[ -z "$branch_atual" ]]; then
                    printf '\n%s\n\n' \
                        'Não foi possível identificar a branch atual.'
                    exit 1
                fi

                criar_branch_a_partir_de_base \
                    "$nova_branch" \
                    "$branch_atual"
                ;;

            2)
                branch_escolhida="$(
                    escolher_branch_existente
                )" || exit 0

                printf '\n%s\n  %s\n\n' \
                    'Branch escolhida como base:' \
                    "$branch_escolhida"

                criar_branch_a_partir_de_base \
                    "$nova_branch" \
                    "$branch_escolhida"
                ;;

            3)
                criar_branch_vazia "$nova_branch"
                ;;

            4)
                printf '%s\n' \
                    'Operação cancelada.'
                exit 0
                ;;

            *)
                printf '%s\n' \
                    'Opção inválida. Digite 1, 2, 3 ou 4.'
                ;;
        esac
    done
}

# ============================================================
# Montagem de branch temporária
# ============================================================

montar_branch_temporaria() {
    local opcao
    local tipo
    local tipo_digitado
    local branch_base
    local segmento_branch
    local area_digitada
    local objetivo_digitado
    local area
    local objetivo
    local nova_branch

    local -a opcoes=(
        'feature'
        'fix'
        'hotfix'
        'refactor'
        'test'
        'integration'
        'docs'
        'Digitar outro tipo'
    )

    printf '\n%s\n' \
        'Selecione o tipo da branch temporária:'

    PS3='Opção: '

    select opcao in "${opcoes[@]}"; do
        case "$REPLY" in
            1|2|3|4|5|6|7)
                tipo="$opcao"
                break
                ;;

            8)
                read -rp \
                    'Digite o tipo da branch: ' \
                    tipo_digitado

                tipo="$(normalizar "$tipo_digitado")"

                if [[ -z "$tipo" ]]; then
                    printf '%s\n' \
                        'Tipo inválido.'
                    exit 1
                fi

                break
                ;;

            *)
                printf '%s\n' \
                    'Opção inválida. Digite um número entre 1 e 8.'
                ;;
        esac
    done

    branch_base="$(
        escolher_develop_ou_main_existente
    )" || exit 0

    if [[ "$branch_base" == develop/pcb-rev-* ]]; then
        segmento_branch="${branch_base#develop/}"
    else
        segmento_branch='main'

        printf '\n%s\n\n' \
            'ATENÇÃO:'

        printf '%s\n\n' \
            'A branch será criada a partir da main e terá o padrão:'

        printf '  %s\n\n' \
            "$tipo/main/area/objetivo"

        printf '%s\n%s\n%s\n\n' \
            'Essa branch não ficará vinculada diretamente a uma revisão específica da PCB.' \
            'Para o fluxo normal de desenvolvimento, recomenda-se utilizar uma branch' \
            'develop/pcb-rev-X.Y.'
    fi

    printf '\n'

    read -rp \
        'Área, por exemplo Comunicação: ' \
        area_digitada

    read -rp \
        'Objetivo, por exemplo Adicionar Modbus TCP: ' \
        objetivo_digitado

    area="$(normalizar "$area_digitada")"
    objetivo="$(normalizar "$objetivo_digitado")"

    if [[ -z "$area" ]]; then
        printf '%s\n' \
            'Área inválida.'
        exit 1
    fi

    if [[ -z "$objetivo" ]]; then
        printf '%s\n' \
            'Objetivo inválido.'
        exit 1
    fi

    nova_branch="$tipo/$segmento_branch/$area/$objetivo"

    escolher_origem_e_criar \
        "$nova_branch" \
        "$branch_base"
}

# ============================================================
# Montagem de branch develop
# ============================================================

montar_branch_develop() {
    local revisao
    local nova_branch

    revisao="$(
        digitar_nova_revisao_pcb
    )" || exit 0

    nova_branch="develop/pcb-rev-$revisao"

    escolher_origem_e_criar "$nova_branch"
}

# ============================================================
# Montagem de branch personalizada
# ============================================================

montar_branch_personalizada() {
    local nome_digitado
    local nova_branch

    printf '\n'

    read -rp \
        'Digite o nome completo da branch: ' \
        nome_digitado

    nova_branch="$(
        normalizar_branch_completa "$nome_digitado"
    )"

    if [[ -z "$nova_branch" ]]; then
        printf '%s\n' \
            'Nome de branch inválido.'
        exit 1
    fi

    escolher_origem_e_criar "$nova_branch"
}

# ============================================================
# Menu principal
# ============================================================

printf '\n%s\n%s\n%s\n\n' \
    '======================================' \
    ' Criação de branch' \
    '======================================'

printf '%s\n' \
    'O que deseja criar?'

opcoes_inicio=(
    'Criar branch temporária padronizada'
    'Criar nova branch develop/pcb-rev-X.Y'
    'Criar branch com nome personalizado'
    'Cancelar'
)

PS3='Opção: '

select escolha_inicio in "${opcoes_inicio[@]}"; do
    case "$REPLY" in
        1)
            montar_branch_temporaria
            ;;

        2)
            montar_branch_develop
            ;;

        3)
            montar_branch_personalizada
            ;;

        4)
            printf '%s\n' \
                'Operação cancelada.'
            exit 0
            ;;

        *)
            printf '%s\n' \
                'Opção inválida. Digite 1, 2, 3 ou 4.'
            ;;
    esac
done