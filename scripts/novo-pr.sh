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
        'Resolva ou cancele o merge antes de abrir um Pull Request.' \
        'Para cancelar o merge:' \
        'git merge --abort'
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    printf '\n%s\n%s\n\n' \
        'O GitHub CLI não foi encontrado neste computador.' \
        'Instale o GitHub CLI antes de utilizar o comando git novo-pr.'
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    printf '\n%s\n%s\n\n%s\n  %s\n\n' \
        'O GitHub CLI não está autenticado.' \
        'Faça a autenticação antes de continuar:' \
        'Comando:' \
        'gh auth login'
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    printf '\n%s\n%s\n\n' \
        'Não existe um remoto chamado origin configurado.' \
        'Configure o repositório oficial antes de abrir o Pull Request.'
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

    printf '\n%s\n  %s\n\n%s\n\n' \
        'O Pull Request deve ser aberto a partir de uma branch temporária.' \
        "$branch_atual" \
        'Crie ou acesse uma branch temporária antes de continuar.'
    exit 1
fi

PADRAO_BRANCH='^(feature|fix|hotfix|refactor|test|integration|docs)/(pcb-rev-[0-9]+\.[0-9]+)/[a-z0-9-]+/[a-z0-9-]+$'

if [[ ! "$branch_atual" =~ $PADRAO_BRANCH ]]; then
    printf '\n%s\n  %s\n\n%s\n  %s\n\n' \
        'A branch atual não segue o padrão definido no manual:' \
        "$branch_atual" \
        'Padrão esperado:' \
        '[TIPO]/pcb-rev-X.Y/[AREA]/[OBJETIVO]'
    exit 1
fi

tipo_branch="${BASH_REMATCH[1]}"
segmento_revisao="${BASH_REMATCH[2]}"
revisao_pcb="${segmento_revisao#pcb-rev-}"

# ============================================================
# Definição automática da branch de destino
# ============================================================

if [[ "$tipo_branch" == 'hotfix' ]]; then
    branch_destino='main'
else
    branch_destino="develop/$segmento_revisao"
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

ler_campo_obrigatorio() {
    local pergunta="$1"
    local valor=''

    while [[ -z "$valor" ]]; do
        read -rp "$pergunta" valor
        valor="$(remover_espacos_extremos "$valor")"

        if [[ -z "$valor" ]]; then
            printf '%s\n' \
                'Este campo é obrigatório.'
        fi
    done

    printf '%s' "$valor"
}

branch_remota_existe() {
    local branch="$1"

    git show-ref \
        --verify \
        --quiet \
        "refs/remotes/origin/$branch"
}

listar_labels() {
    gh label list \
        --limit 100 \
        --sort name \
        --order asc \
        --json name \
        --jq '.[].name' \
        2>/dev/null
}

label_ja_selecionada() {
    local label_procurada="$1"
    local label

    for label in "${labels_selecionadas[@]:-}"; do
        if [[ "$label" == "$label_procurada" ]]; then
            return 0
        fi
    done

    return 1
}

selecionar_labels() {
    local resposta
    local escolha
    local label
    local indice_concluir
    local indice_cancelar
    local -a labels_disponiveis
    local -a opcoes

    labels_selecionadas=()

    printf '\n'

    read -rp \
        'Deseja adicionar labels ao Pull Request? [s/N]: ' \
        resposta

    if [[ ! "$resposta" =~ ^[Ss]$ ]]; then
        return 0
    fi

    mapfile -t labels_disponiveis < <(
        listar_labels
    )

    if [[ ${#labels_disponiveis[@]} -eq 0 ]]; then
        printf '\n%s\n\n' \
            'Nenhuma label foi encontrada no repositório.'
        return 0
    fi

    while true; do
        opcoes=()

        for label in "${labels_disponiveis[@]}"; do
            if label_ja_selecionada "$label"; then
                opcoes+=("$label [selecionada]")
            else
                opcoes+=("$label")
            fi
        done

        opcoes+=(
            'Concluir seleção'
            'Cancelar seleção de labels'
        )

        indice_concluir=$((${#labels_disponiveis[@]} + 1))
        indice_cancelar=$((${#labels_disponiveis[@]} + 2))

        printf '\n%s\n\n' \
            'Selecione uma label:'

        PS3='Opção: '

        select escolha in "${opcoes[@]}"; do
            if [[ "$REPLY" =~ ^[0-9]+$ ]] &&
               ((REPLY >= 1 && REPLY <= ${#labels_disponiveis[@]})); then

                label="${labels_disponiveis[$((REPLY - 1))]}"

                if label_ja_selecionada "$label"; then
                    printf '\n%s\n  %s\n\n' \
                        'A label já foi selecionada:' \
                        "$label"
                else
                    labels_selecionadas+=("$label")

                    printf '\n%s\n  %s\n\n' \
                        'Label adicionada:' \
                        "$label"
                fi

                break
            fi

            if [[ "$REPLY" == "$indice_concluir" ]]; then
                return 0
            fi

            if [[ "$REPLY" == "$indice_cancelar" ]]; then
                labels_selecionadas=()

                printf '%s\n' \
                    'Seleção de labels cancelada.'

                return 0
            fi

            printf '%s\n' \
                'Opção inválida.'
        done
    done
}

# ============================================================
# Atualização das referências
# ============================================================

printf '\n%s\n\n' \
    'Atualizando as referências do GitHub...'

if ! git fetch origin --prune; then
    printf '\n%s\n%s\n\n' \
        'Não foi possível acessar o repositório remoto.' \
        'Verifique sua conexão, suas credenciais e suas permissões.'
    exit 1
fi

if ! branch_remota_existe "$branch_destino"; then
    printf '\n%s\n  %s\n\n' \
        'A branch de destino não foi encontrada no GitHub:' \
        "$branch_destino"
    exit 1
fi

# ============================================================
# Verificação da branch de origem
# ============================================================

if [[ -n "$(git status --porcelain)" ]]; then
    printf '\n%s\n\n' \
        'Existem alterações locais ainda não registradas:'

    git status --short

    printf '\n%s\n%s\n\n' \
        'Crie o commit antes de abrir o Pull Request.' \
        'Utilize: git novo-commit'
    exit 1
fi

if ! branch_remota_existe "$branch_atual"; then
    printf '\n%s\n  %s\n\n' \
        'A branch atual ainda não existe no GitHub:' \
        "$branch_atual"

    read -rp \
        'Deseja enviar a branch agora? [S/n]: ' \
        enviar_branch

    enviar_branch="${enviar_branch:-S}"

    if [[ ! "$enviar_branch" =~ ^[Ss]$ ]]; then
        printf '%s\n' \
            'Operação cancelada.'
        exit 0
    fi

    if ! git push -u origin HEAD; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível enviar a branch para o GitHub.' \
            'Verifique sua conexão, suas credenciais e suas permissões.'
        exit 1
    fi

    git fetch origin --prune
fi

commit_local="$(git rev-parse HEAD)"
commit_remoto="$(git rev-parse "origin/$branch_atual")"

if [[ "$commit_local" != "$commit_remoto" ]]; then
    printf '\n%s\n%s\n\n' \
        'A branch local possui commits que ainda não estão no GitHub.' \
        'O Pull Request deve incluir o estado mais recente da branch.'

    read -rp \
        'Deseja enviar os commits agora? [S/n]: ' \
        enviar_commits

    enviar_commits="${enviar_commits:-S}"

    if [[ ! "$enviar_commits" =~ ^[Ss]$ ]]; then
        printf '%s\n' \
            'Operação cancelada.'
        exit 0
    fi

    if ! git push -u origin HEAD; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível enviar os commits para o GitHub.' \
            'Verifique sua conexão, suas credenciais e suas permissões.'
        exit 1
    fi
fi

# ============================================================
# Verificação de Pull Request existente
# ============================================================

pr_existente="$(
    gh pr list \
        --head "$branch_atual" \
        --state open \
        --limit 1 \
        --json url \
        --jq '.[0].url // empty'
)"

if [[ -n "$pr_existente" ]]; then
    printf '\n%s\n  %s\n\n' \
        'Já existe um Pull Request aberto para esta branch:' \
        "$pr_existente"
    exit 0
fi

# ============================================================
# Cabeçalho
# ============================================================

printf '\n%s\n%s\n%s\n\n' \
    '======================================' \
    ' Criação de Pull Request' \
    '======================================'

printf '%s\n  %s\n\n' \
    'Branch de origem:' \
    "$branch_atual"

printf '%s\n  %s\n\n' \
    'Branch de destino:' \
    "$branch_destino"

printf '%s\n  %s\n\n' \
    'Revisão da PCB:' \
    "$revisao_pcb"

if [[ "$tipo_branch" == 'hotfix' ]]; then
    printf '%s\n%s\n\n' \
        'ATENÇÃO:' \
        "Após o merge na main, a correção também deverá ser incorporada em develop/$segmento_revisao."
fi

# ============================================================
# Título
# ============================================================

titulo_sugerido="$(git log -1 --pretty=format:'%s')"

printf '%s\n  %s\n\n' \
    'Título sugerido com base no último commit:' \
    "$titulo_sugerido"

read -rp \
    'Deseja utilizar o título sugerido? [S/n]: ' \
    usar_titulo

usar_titulo="${usar_titulo:-S}"

if [[ "$usar_titulo" =~ ^[Ss]$ ]]; then
    titulo_pr="$titulo_sugerido"
else
    titulo_pr="$(
        ler_campo_obrigatorio \
            'Digite o título do Pull Request: '
    )"
fi

# ============================================================
# Campos exigidos no Pull Request
# ============================================================

printf '\n%s\n\n' \
    'Preencha as informações do Pull Request.'

objetivo="$(
    ler_campo_obrigatorio \
        'Objetivo da alteração: '
)"

motivo="$(
    ler_campo_obrigatorio \
        'Motivo da alteração: '
)"

modulos="$(
    ler_campo_obrigatorio \
        'Módulos ou arquivos modificados: '
)"

impactos="$(
    ler_campo_obrigatorio \
        'Impactos conhecidos, ou escreva Nenhum: '
)"

testes="$(
    ler_campo_obrigatorio \
        'Testes executados: '
)"

resultados="$(
    ler_campo_obrigatorio \
        'Resultados obtidos: '
)"

limitacoes="$(
    ler_campo_obrigatorio \
        'Limitações ou pendências, ou escreva Nenhuma: '
)"

# ============================================================
# Verificações
# ============================================================

printf '\n%s\n%s\n\n' \
    'Responda às verificações abaixo.' \
    'Essas respostas serão registradas no Pull Request.'

read -rp \
    'O projeto compila sem erros? [s/N]: ' \
    compilacao_ok

read -rp \
    'A alteração é compatível com a revisão da PCB indicada? [s/N]: ' \
    compatibilidade_ok

read -rp \
    'As funções alteradas foram testadas? [s/N]: ' \
    funcoes_testadas

read -rp \
    'Foram verificadas as funções relacionadas? [s/N]: ' \
    relacionadas_verificadas

read -rp \
    'Não foram identificadas regressões críticas? [s/N]: ' \
    sem_regressoes

read -rp \
    'O README foi atualizado ou não precisava de atualização? [s/N]: ' \
    readme_ok

marcar_checkbox() {
    if [[ "$1" =~ ^[Ss]$ ]]; then
        printf 'x'
    else
        printf ' '
    fi
}

check_compilacao="$(marcar_checkbox "$compilacao_ok")"
check_compatibilidade="$(marcar_checkbox "$compatibilidade_ok")"
check_testes="$(marcar_checkbox "$funcoes_testadas")"
check_relacionadas="$(marcar_checkbox "$relacionadas_verificadas")"
check_regressoes="$(marcar_checkbox "$sem_regressoes")"
check_readme="$(marcar_checkbox "$readme_ok")"

# ============================================================
# Labels
# ============================================================

declare -a labels_selecionadas=()
selecionar_labels

# ============================================================
# Rascunho
# ============================================================

printf '\n%s\n%s\n\n' \
    'Um Pull Request em rascunho ainda não está pronto para revisão.' \
    'Os revisores serão solicitados quando ele for marcado como pronto.'

read -rp \
    'Deseja criar o Pull Request como rascunho (draft)? [s/N]: ' \
    resposta_draft

declare -a argumentos_draft=()

if [[ "$resposta_draft" =~ ^[Ss]$ ]]; then
    argumentos_draft+=('--draft')
    estado_pr='Rascunho'
else
    estado_pr='Pronto para revisão'
fi

# ============================================================
# Montagem do corpo
# ============================================================

arquivo_corpo="$(mktemp)"
trap 'rm -f "$arquivo_corpo"' EXIT

cat > "$arquivo_corpo" <<EOF
## Objetivo da alteração

$objetivo

## Motivo da alteração

$motivo

## Revisão da PCB afetada

- PCB Rev. $revisao_pcb
- Branch correspondente: \`develop/$segmento_revisao\`

## Módulos ou arquivos modificados

$modulos

## Impactos conhecidos

$impactos

## Testes executados

$testes

## Resultados obtidos

$resultados

## Limitações ou pendências

$limitacoes

## Verificações

- [$check_compilacao] O projeto compila sem erros.
- [$check_compatibilidade] A alteração é compatível com a revisão da PCB indicada.
- [$check_testes] As funções alteradas foram testadas.
- [$check_relacionadas] Foram verificadas as funções relacionadas.
- [$check_regressoes] Não foram identificadas regressões críticas.
- [$check_readme] O README foi atualizado ou não precisava de atualização.
EOF

if [[ "$tipo_branch" == 'hotfix' ]]; then
    cat >> "$arquivo_corpo" <<EOF

## Observação sobre o hotfix

Após a integração na \`main\`, esta correção deverá ser incorporada também à branch \`develop/$segmento_revisao\`.
EOF
fi

# ============================================================
# Argumentos de labels
# ============================================================

declare -a argumentos_labels=()

for label in "${labels_selecionadas[@]:-}"; do
    argumentos_labels+=(
        '--label'
        "$label"
    )
done

# ============================================================
# Resumo
# ============================================================

printf '\n%s\n' \
    '--------------------------------------'

printf '%s\n  %s\n\n' \
    'Título:' \
    "$titulo_pr"

printf '%s\n  %s\n\n' \
    'Origem:' \
    "$branch_atual"

printf '%s\n  %s\n\n' \
    'Destino:' \
    "$branch_destino"

printf '%s\n  %s\n\n' \
    'Responsável atribuído:' \
    '@me'

printf '%s\n  %s\n\n' \
    'Estado:' \
    "$estado_pr"

if [[ ${#labels_selecionadas[@]} -gt 0 ]]; then
    printf '%s\n' \
        'Labels:'

    for label in "${labels_selecionadas[@]}"; do
        printf '  - %s\n' "$label"
    done

    printf '\n'
else
    printf '%s\n  %s\n\n' \
        'Labels:' \
        'Nenhuma'
fi

printf '%s\n' \
    '--------------------------------------'

# ============================================================
# Confirmação
# ============================================================

printf '\n'

read -rp \
    'Confirma a criação do Pull Request? [S/n]: ' \
    confirmacao

confirmacao="${confirmacao:-S}"

if [[ ! "$confirmacao" =~ ^[Ss]$ ]]; then
    printf '\n%s\n\n' \
        'Operação cancelada.'
    exit 0
fi

# ============================================================
# Criação do Pull Request
# ============================================================

printf '\n%s\n\n' \
    'Criando o Pull Request no GitHub...'

gh pr create \
    --base "$branch_destino" \
    --head "$branch_atual" \
    --title "$titulo_pr" \
    --body-file "$arquivo_corpo" \
    --assignee '@me' \
    "${argumentos_labels[@]}" \
    "${argumentos_draft[@]}"

printf '\n%s\n\n' \
    'Pull Request criado com sucesso.'