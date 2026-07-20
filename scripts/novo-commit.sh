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

# ============================================================
# Funções auxiliares
# ============================================================

normalizar_tipo() {
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

remover_espacos_extremos() {
    local texto="$1"

    printf '%s' "$texto" |
        sed -E '
            s/^[[:space:]]+//;
            s/[[:space:]]+$//
        '
}

verificar_origin() {
    git remote get-url origin >/dev/null 2>&1
}

# ============================================================
# Preparação dos arquivos para o commit
# ============================================================

preparar_arquivos_para_commit() {
    local escolha_stage

    local -a opcoes_stage=(
        'Adicionar todas as alterações'
        'Adicionar somente arquivos específicos'
        'Cancelar'
    )

    if ! git diff --cached --quiet; then
        return
    fi

    if [[ -z "$(git status --porcelain)" ]]; then
        printf '\n%s\n\n' \
            'Não existem alterações para criar um commit.'
        exit 0
    fi

    printf '\n%s\n\n' \
        'Existem alterações que ainda não foram adicionadas ao commit:'

    git status --short

    printf '\n%s\n' \
        'Como deseja continuar?'

    PS3='Opção: '

    select escolha_stage in "${opcoes_stage[@]}"; do
        case "$REPLY" in
            1)
                git add --all

                printf '\n%s\n\n' \
                    'Todas as alterações foram adicionadas ao commit.'
                break
                ;;

            2)
                printf '\n%s\n\n' \
                    'Nenhum arquivo foi adicionado automaticamente.'

                printf '%s\n' \
                    'Adicione os arquivos desejados com:' \
                    '' \
                    '  git add nome-do-arquivo' \
                    '' \
                    'Depois execute novamente:' \
                    '' \
                    '  git novo-commit' \
                    ''

                exit 0
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

    if git diff --cached --quiet; then
        printf '\n%s\n\n' \
            'Nenhuma alteração foi adicionada ao stage.'
        exit 1
    fi
}

# ============================================================
# Envio para o GitHub
# ============================================================

enviar_commit_para_github() {
    local branch_atual

    branch_atual="$(git branch --show-current)"

    if [[ -z "$branch_atual" ]]; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível identificar a branch atual.' \
            'O commit foi criado, mas não foi possível fazer o push.'
        return 1
    fi

    if ! verificar_origin; then
        printf '\n%s\n%s\n\n%s\n  %s\n\n' \
            'Não existe um remoto chamado origin configurado.' \
            'O commit foi criado apenas localmente.' \
            'Configure o remoto antes de enviar:' \
            'git remote add origin URL_DO_REPOSITORIO'
        return 0
    fi

    printf '\n%s\n%s\n  %s\n\n' \
        'Enviando o commit para o GitHub...' \
        'Branch:' \
        "$branch_atual"

    if ! git push -u origin HEAD; then
        printf '\n%s\n\n' \
            'O commit foi criado localmente, mas o envio falhou.'

        printf '%s\n' \
            'Verifique:' \
            '  - sua conexão com a internet;' \
            '  - suas credenciais do GitHub;' \
            '  - suas permissões no repositório;' \
            '  - se a branch possui alguma proteção ou restrição.' \
            '' \
            'Para tentar novamente:' \
            '  git push -u origin HEAD' \
            ''

        exit 1
    fi

    printf '\n%s\n\n' \
        'Commit criado e enviado para o GitHub com sucesso.'
}

# ============================================================
# Identificação da branch atual
# ============================================================

branch_atual="$(git branch --show-current)"

if [[ -z "$branch_atual" ]]; then
    printf '\n%s\n%s\n\n' \
        'Não foi possível identificar a branch atual.' \
        'O repositório pode estar em estado detached HEAD.'
    exit 1
fi

tipo_branch="${branch_atual%%/*}"

case "$tipo_branch" in
    feature)
        tipo_sugerido='feat'
        ;;

    fix)
        tipo_sugerido='fix'
        ;;

    hotfix)
        tipo_sugerido='fix'
        ;;

    refactor)
        tipo_sugerido='refactor'
        ;;

    test)
        tipo_sugerido='test'
        ;;

    docs)
        tipo_sugerido='docs'
        ;;

    integration)
        tipo_sugerido='integration'
        ;;

    main|develop)
        tipo_sugerido=''
        ;;

    *)
        tipo_sugerido="$(
            normalizar_tipo "$tipo_branch"
        )"
        ;;
esac

# ============================================================
# Tela inicial
# ============================================================

printf '\n%s\n%s\n%s\n\n' \
    '======================================' \
    ' Criação de commit padronizado' \
    '======================================'

printf '%s\n  %s\n\n' \
    'Branch atual:' \
    "$branch_atual"

preparar_arquivos_para_commit

if [[ -n "$tipo_sugerido" ]]; then
    printf '%s\n  %s\n' \
        'Tipo sugerido com base na branch:' \
        "$tipo_sugerido"
else
    printf '%s\n' \
        'Nenhum tipo foi sugerido automaticamente para esta branch.'
fi

# ============================================================
# Seleção do tipo do commit
# ============================================================

opcoes=(
    'Usar tipo sugerido'
    'feat'
    'fix'
    'refactor'
    'test'
    'docs'
    'integration'
    'chore'
    'build'
    'ci'
    'perf'
    'revert'
    'Digitar outro tipo'
)

printf '\n%s\n' \
    'Selecione o tipo do commit:'

PS3='Opção: '

select opcao in "${opcoes[@]}"; do
    case "$REPLY" in
        1)
            if [[ -z "$tipo_sugerido" ]]; then
                printf '\n%s\n%s\n' \
                    'Não existe um tipo sugerido para esta branch.' \
                    'Escolha outra opção.'
                continue
            fi

            tipo="$tipo_sugerido"
            break
            ;;

        2|3|4|5|6|7|8|9|10|11|12)
            tipo="$opcao"
            break
            ;;

        13)
            printf '\n'

            read -rp \
                'Digite o tipo do commit: ' \
                tipo_digitado

            tipo="$(
                normalizar_tipo "$tipo_digitado"
            )"

            if [[ -z "$tipo" ]]; then
                printf '%s\n' \
                    'Tipo inválido.'
                exit 1
            fi

            break
            ;;

        *)
            printf '%s\n' \
                'Opção inválida. Digite um número entre 1 e 13.'
            ;;
    esac
done

# ============================================================
# Descrição da alteração
# ============================================================

printf '\n'

read -rp \
    'Descrição objetiva da alteração: ' \
    descricao

descricao="$(
    remover_espacos_extremos "$descricao"
)"

if [[ -z "$descricao" ]]; then
    printf '\n%s\n\n' \
        'A descrição não pode ficar vazia.'
    exit 1
fi

descricao="${descricao%.}"

mensagem="$tipo: $descricao"

# ============================================================
# Confirmação do commit
# ============================================================

printf '\n%s\n' \
    '--------------------------------------'

printf '%s\n\n  %s\n\n' \
    'Mensagem do commit:' \
    "$mensagem"

printf '%s\n\n' \
    'Arquivos adicionados ao commit:'

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
# Criação do commit
# ============================================================

if ! git commit -m "$mensagem"; then
    printf '\n%s\n\n' \
        'Não foi possível criar o commit.'
    exit 1
fi

printf '\n%s\n  %s\n\n' \
    'Commit criado localmente:' \
    "$mensagem"

enviar_commit_para_github