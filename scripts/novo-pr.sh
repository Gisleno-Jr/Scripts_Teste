#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Funções auxiliares
# ============================================================

encerrar_com_erro() {
    printf '\n%s\n\n' "$1"
    exit 1
}

perguntar_obrigatorio() {
    local mensagem="$1"
    local resposta=''

    while [[ -z "${resposta//[[:space:]]/}" ]]; do
        read -r -p "$mensagem" resposta

        if [[ -z "${resposta//[[:space:]]/}" ]]; then
            printf 'Este campo é obrigatório.\n'
        fi
    done

    printf '%s' "$resposta"
}

resposta_afirmativa() {
    [[ "$1" =~ ^[sS]$ ]]
}

resposta_negativa() {
    [[ "$1" =~ ^[nN]$ ]]
}

# ============================================================
# Verificações iniciais
# ============================================================

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    encerrar_com_erro 'Este comando deve ser executado dentro de um repositório Git.'
fi

if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    encerrar_com_erro \
        'Existe um merge em andamento. Conclua ou cancele o merge antes de criar o Pull Request.'
fi

if ! command -v gh >/dev/null 2>&1; then
    printf '\n'
    printf 'O GitHub CLI não foi encontrado neste computador.\n'
    printf 'Instale o GitHub CLI antes de utilizar o comando git novo-pr.\n'
    printf '\n'
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    printf '\n'
    printf 'O GitHub CLI não está autenticado.\n'
    printf '\n'
    printf 'Execute:\n'
    printf '  gh auth login\n'
    printf '\n'
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    encerrar_com_erro \
        'O repositório não possui um remoto chamado origin configurado.'
fi

branch_atual="$(git branch --show-current)"

if [[ -z "$branch_atual" ]]; then
    encerrar_com_erro \
        'Não foi possível identificar a branch atual. Verifique se o repositório está em detached HEAD.'
fi

# ============================================================
# Validação da branch atual
# ============================================================

if [[ "$branch_atual" == 'main' ]] ||
   [[ "$branch_atual" =~ ^develop/pcb-rev-[0-9]+\.[0-9]+$ ]]; then

    printf '\n'
    printf 'Não é possível abrir um Pull Request a partir da branch atual.\n'
    printf '\n'
    printf 'Branch atual:\n'
    printf '  %s\n' "$branch_atual"
    printf '\n'
    printf 'O Pull Request deve ser aberto a partir de uma branch temporária.\n'
    printf '\n'
    printf 'Crie ou acesse uma branch temporária antes de continuar.\n'
    printf '\n'

    exit 1
fi

padrao_branch='^(feature|fix|hotfix|refactor|test|integration|docs)/(pcb-rev-[0-9]+\.[0-9]+)/([a-z0-9-]+)/([a-z0-9-]+)$'

if [[ ! "$branch_atual" =~ $padrao_branch ]]; then
    printf '\n'
    printf 'A branch atual não segue o padrão estabelecido.\n'
    printf '\n'
    printf 'Branch atual:\n'
    printf '  %s\n' "$branch_atual"
    printf '\n'
    printf 'Padrão esperado:\n'
    printf '  [TIPO]/pcb-rev-X.Y/[AREA]/[OBJETIVO]\n'
    printf '\n'
    printf 'Tipos permitidos:\n'
    printf '  feature, fix, hotfix, refactor, test, integration e docs\n'
    printf '\n'
    exit 1
fi

tipo_branch="${BASH_REMATCH[1]}"
segmento_revisao="${BASH_REMATCH[2]}"

if [[ "$tipo_branch" == 'hotfix' ]]; then
    branch_base='main'
else
    branch_base="develop/${segmento_revisao}"
fi

# ============================================================
# Atualização das referências remotas
# ============================================================

printf '\n'
printf 'Atualizando as referências do repositório remoto...\n'
printf '\n'

git fetch origin --prune

if ! git show-ref --verify --quiet "refs/remotes/origin/${branch_base}"; then
    printf '\n'
    printf 'A branch de destino não foi encontrada no repositório remoto.\n'
    printf '\n'
    printf 'Branch de destino esperada:\n'
    printf '  %s\n' "$branch_base"
    printf '\n'
    exit 1
fi

# ============================================================
# Verificação de alterações locais não salvas
# ============================================================

if [[ -n "$(git status --porcelain)" ]]; then
    printf '\n'
    printf 'Existem alterações locais que ainda não foram commitadas.\n'
    printf '\n'
    git status --short
    printf '\n'
    printf 'Faça o commit ou descarte as alterações antes de criar o Pull Request.\n'
    printf '\n'
    exit 1
fi

# ============================================================
# Verificação da branch remota e sincronização
# ============================================================

local_head="$(git rev-parse HEAD)"

if git show-ref --verify --quiet "refs/remotes/origin/${branch_atual}"; then
    remoto_head="$(git rev-parse "origin/${branch_atual}")"

    if [[ "$local_head" == "$remoto_head" ]]; then
        :
    elif git merge-base --is-ancestor "origin/${branch_atual}" HEAD; then
        printf '\n'
        printf 'A branch local possui commits que ainda não foram enviados.\n'
        printf '\n'
        printf 'Branch:\n'
        printf '  %s\n' "$branch_atual"
        printf '\n'

        read -r -p 'Deseja enviar os commits para o GitHub agora? [S/n]: ' resposta_push
        resposta_push="${resposta_push:-S}"

        if resposta_negativa "$resposta_push"; then
            printf '\n'
            printf 'O Pull Request não foi criado.\n'
            printf 'Envie a branch ao GitHub antes de tentar novamente.\n'
            printf '\n'
            exit 1
        fi

        printf '\n'
        printf 'Enviando a branch ao GitHub...\n'
        printf '\n'

        git push origin "$branch_atual"

    elif git merge-base --is-ancestor HEAD "origin/${branch_atual}"; then
        printf '\n'
        printf 'A branch local está desatualizada em relação ao GitHub.\n'
        printf '\n'
        printf 'Branch:\n'
        printf '  %s\n' "$branch_atual"
        printf '\n'
        printf 'Atualize a branch antes de criar o Pull Request:\n'
        printf '  git pull --ff-only\n'
        printf '\n'
        exit 1
    else
        printf '\n'
        printf 'A branch local e a branch remota possuem históricos divergentes.\n'
        printf '\n'
        printf 'Branch:\n'
        printf '  %s\n' "$branch_atual"
        printf '\n'
        printf 'Resolva a divergência antes de criar o Pull Request.\n'
        printf '\n'
        exit 1
    fi
else
    printf '\n'
    printf 'A branch atual ainda não existe no GitHub.\n'
    printf '\n'
    printf 'Branch:\n'
    printf '  %s\n' "$branch_atual"
    printf '\n'

    read -r -p 'Deseja publicar esta branch no GitHub agora? [S/n]: ' resposta_publicar
    resposta_publicar="${resposta_publicar:-S}"

    if resposta_negativa "$resposta_publicar"; then
        printf '\n'
        printf 'O Pull Request não foi criado.\n'
        printf 'Publique a branch no GitHub antes de tentar novamente.\n'
        printf '\n'
        exit 1
    fi

    printf '\n'
    printf 'Publicando a branch no GitHub...\n'
    printf '\n'

    git push --set-upstream origin "$branch_atual"
fi

# Atualiza novamente as referências após um possível push.
git fetch origin --prune >/dev/null

# ============================================================
# Verificação de Pull Request já existente
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
    printf '\n'
    printf 'Já existe um Pull Request aberto para esta branch.\n'
    printf '\n'
    printf 'Branch:\n'
    printf '  %s\n' "$branch_atual"
    printf '\n'
    printf 'Pull Request:\n'
    printf '  %s\n' "$pr_existente"
    printf '\n'
    exit 1
fi

# ============================================================
# Verificação antecipada de commits para o Pull Request
# ============================================================

quantidade_commits="$(
    git rev-list --count "origin/${branch_base}..HEAD"
)"

if [[ "$quantidade_commits" -eq 0 ]]; then
    printf '\n'
    printf 'Não é possível criar o Pull Request.\n'
    printf '\n'
    printf 'Branch de origem:\n'
    printf '  %s\n' "$branch_atual"
    printf '\n'
    printf 'Branch de destino:\n'
    printf '  %s\n' "$branch_base"
    printf '\n'
    printf 'A branch atual não possui commits novos em relação à branch de destino.\n'
    printf '\n'
    printf 'Faça pelo menos um commit na branch atual antes de continuar.\n'
    printf '\n'
    exit 1
fi

quantidade_arquivos="$(
    git diff --name-only "origin/${branch_base}...HEAD" |
        sed '/^[[:space:]]*$/d' |
        wc -l |
        tr -d '[:space:]'
)"

printf '\n'
printf 'Comparação identificada:\n'
printf '  Origem:        %s\n' "$branch_atual"
printf '  Destino:       %s\n' "$branch_base"
printf '  Commits novos: %s\n' "$quantidade_commits"
printf '  Arquivos:      %s\n' "$quantidade_arquivos"
printf '\n'

# ============================================================
# Definição antecipada do tipo de Pull Request
# ============================================================

printf 'Como deseja criar o Pull Request?\n'
printf '\n'
printf '1) Rascunho — ainda em desenvolvimento\n'
printf '2) Pronto para revisão\n'
printf '3) Cancelar\n'
printf '\n'

while true; do
    read -r -p 'Escolha uma opção: ' opcao_pr

    case "$opcao_pr" in
        1)
            criar_como_draft=true
            break
            ;;
        2)
            criar_como_draft=false
            break
            ;;
        3)
            printf '\n'
            printf 'Operação cancelada.\n'
            printf '\n'
            exit 0
            ;;
        *)
            printf 'Opção inválida. Escolha 1, 2 ou 3.\n'
            ;;
    esac
done

# ============================================================
# Título do Pull Request
# ============================================================

titulo_sugerido="$(git log -1 --pretty=%s)"

printf '\n'
printf 'Título sugerido com base no último commit:\n'
printf '  %s\n' "$titulo_sugerido"
printf '\n'

read -r -p 'Título do Pull Request [Enter para usar o sugerido]: ' titulo_pr
titulo_pr="${titulo_pr:-$titulo_sugerido}"

# ============================================================
# Coleta das informações do Pull Request
# ============================================================

if [[ "$criar_como_draft" == true ]]; then
    printf '\n'
    printf 'O Pull Request será criado como rascunho.\n'
    printf 'Preencha as informações iniciais disponíveis.\n'
    printf '\n'

    objetivo="$(
        perguntar_obrigatorio \
            'Objetivo inicial do Pull Request: '
    )"

    modulos="$(
        perguntar_obrigatorio \
            'Módulos ou arquivos envolvidos: '
    )"

    read -r -p 'Estado atual do desenvolvimento: ' estado_atual
    estado_atual="${estado_atual:-Em desenvolvimento.}"

    read -r -p 'Pendências conhecidas: ' limitacoes
    limitacoes="${limitacoes:-A definir durante o desenvolvimento.}"

    motivo='A definir durante o desenvolvimento.'
    impactos='Em análise.'
    testes='Ainda não executados.'
    resultados='Ainda não disponíveis.'
else
    printf '\n'
    printf 'O Pull Request será criado como pronto para revisão.\n'
    printf 'Preencha todas as informações solicitadas.\n'
    printf '\n'

    objetivo="$(
        perguntar_obrigatorio \
            'Objetivo do Pull Request: '
    )"

    motivo="$(
        perguntar_obrigatorio \
            'Motivo da alteração: '
    )"

    modulos="$(
        perguntar_obrigatorio \
            'Módulos ou arquivos envolvidos: '
    )"

    impactos="$(
        perguntar_obrigatorio \
            'Impactos conhecidos: '
    )"

    testes="$(
        perguntar_obrigatorio \
            'Testes executados: '
    )"

    resultados="$(
        perguntar_obrigatorio \
            'Resultados dos testes: '
    )"

    read -r -p 'Limitações ou pendências [Nenhuma]: ' limitacoes
    limitacoes="${limitacoes:-Nenhuma.}"

    estado_atual='Implementação concluída e disponível para revisão.'
fi

# ============================================================
# Checklist para Pull Request pronto para revisão
# ============================================================

build_confirmado='Não se aplica — Pull Request em rascunho.'
compatibilidade_confirmada='Não se aplica — Pull Request em rascunho.'
funcoes_confirmadas='Não se aplica — Pull Request em rascunho.'
funcoes_relacionadas_confirmadas='Não se aplica — Pull Request em rascunho.'
regressoes_confirmadas='Não se aplica — Pull Request em rascunho.'
readme_confirmado='Não se aplica — Pull Request em rascunho.'

if [[ "$criar_como_draft" == false ]]; then
    printf '\n'
    printf 'Checklist de validação\n'
    printf '\n'

    read -r -p 'O projeto compila corretamente? [s/N]: ' resposta
    if resposta_afirmativa "$resposta"; then
        build_confirmado='Sim'
    else
        build_confirmado='Não'
    fi

    read -r -p 'A compatibilidade com a revisão da PCB foi verificada? [s/N]: ' resposta
    if resposta_afirmativa "$resposta"; then
        compatibilidade_confirmada='Sim'
    else
        compatibilidade_confirmada='Não'
    fi

    read -r -p 'As funções alteradas foram testadas? [s/N]: ' resposta
    if resposta_afirmativa "$resposta"; then
        funcoes_confirmadas='Sim'
    else
        funcoes_confirmadas='Não'
    fi

    read -r -p 'As funções relacionadas foram verificadas? [s/N]: ' resposta
    if resposta_afirmativa "$resposta"; then
        funcoes_relacionadas_confirmadas='Sim'
    else
        funcoes_relacionadas_confirmadas='Não'
    fi

    read -r -p 'Foram verificadas possíveis regressões? [s/N]: ' resposta
    if resposta_afirmativa "$resposta"; then
        regressoes_confirmadas='Sim'
    else
        regressoes_confirmadas='Não'
    fi

    read -r -p 'O README foi atualizado ou foi confirmado que não precisa de alteração? [s/N]: ' resposta
    if resposta_afirmativa "$resposta"; then
        readme_confirmado='Sim'
    else
        readme_confirmado='Não'
    fi

    if [[ "$build_confirmado" == 'Não' ]] ||
       [[ "$compatibilidade_confirmada" == 'Não' ]] ||
       [[ "$funcoes_confirmadas" == 'Não' ]] ||
       [[ "$funcoes_relacionadas_confirmadas" == 'Não' ]] ||
       [[ "$regressoes_confirmadas" == 'Não' ]] ||
       [[ "$readme_confirmado" == 'Não' ]]; then

        printf '\n'
        printf 'Um ou mais itens do checklist não foram confirmados.\n'
        printf '\n'

        read -r -p 'Deseja continuar mesmo assim? [s/N]: ' resposta_continuar

        if ! resposta_afirmativa "$resposta_continuar"; then
            printf '\n'
            printf 'Operação cancelada.\n'
            printf '\n'
            exit 0
        fi
    fi
fi

# ============================================================
# Seleção opcional de labels
# ============================================================

declare -a labels_disponiveis=()
declare -a labels_selecionadas=()

while IFS= read -r label; do
    if [[ -n "$label" ]]; then
        labels_disponiveis+=("$label")
    fi
done < <(
    gh label list \
        --limit 100 \
        --json name \
        --jq '.[].name' 2>/dev/null || true
)

if [[ "${#labels_disponiveis[@]}" -gt 0 ]]; then
    while true; do
        printf '\n'
        printf 'Labels disponíveis:\n'
        printf '\n'

        for indice in "${!labels_disponiveis[@]}"; do
            printf '%d) %s\n' \
                "$((indice + 1))" \
                "${labels_disponiveis[$indice]}"
        done

        printf '\n'
        printf 'Digite os números separados por espaço.\n'
        printf 'Exemplo: 1 2 6\n'
        printf 'Pressione Enter para continuar sem adicionar labels.\n'
        printf '\n'

        read -r -p 'Labels: ' entrada_labels

        labels_selecionadas=()
        entrada_invalida=false

        if [[ -z "${entrada_labels//[[:space:]]/}" ]]; then
            break
        fi

        for numero in $entrada_labels; do
            if [[ ! "$numero" =~ ^[0-9]+$ ]]; then
                printf '\n'
                printf 'Valor inválido: %s\n' "$numero"
                printf 'Digite apenas números separados por espaço.\n'
                entrada_invalida=true
                break
            fi

            if (( numero < 1 || numero > ${#labels_disponiveis[@]} )); then
                printf '\n'
                printf 'Número fora da lista: %s\n' "$numero"
                printf 'Escolha números entre 1 e %d.\n' \
                    "${#labels_disponiveis[@]}"
                entrada_invalida=true
                break
            fi

            label_escolhida="${labels_disponiveis[$((numero - 1))]}"
            label_duplicada=false

            for label_existente in "${labels_selecionadas[@]}"; do
                if [[ "$label_existente" == "$label_escolhida" ]]; then
                    label_duplicada=true
                    break
                fi
            done

            if [[ "$label_duplicada" == false ]]; then
                labels_selecionadas+=("$label_escolhida")
            fi
        done

        if [[ "$entrada_invalida" == true ]]; then
            continue
        fi

        printf '\n'

        if [[ "${#labels_selecionadas[@]}" -gt 0 ]]; then
            printf 'Labels selecionadas:\n'

            for label in "${labels_selecionadas[@]}"; do
                printf '  - %s\n' "$label"
            done
        else
            printf 'Nenhuma label selecionada.\n'
        fi

        printf '\n'
        read -r -p 'Confirma estas labels? [S/n]: ' resposta_labels
        resposta_labels="${resposta_labels:-S}"

        if [[ ! "$resposta_labels" =~ ^[nN]$ ]]; then
            break
        fi
    done
else
    printf '\n'
    printf 'Nenhuma label está disponível neste repositório.\n'
fi

# ============================================================
# Resumo e confirmação
# ============================================================

printf '\n'
printf 'Resumo do Pull Request\n'
printf '\n'
printf 'Tipo:               %s\n' \
    "$(
        if [[ "$criar_como_draft" == true ]]; then
            printf 'Rascunho'
        else
            printf 'Pronto para revisão'
        fi
    )"
printf 'Branch de origem:   %s\n' "$branch_atual"
printf 'Branch de destino:  %s\n' "$branch_base"
printf 'Título:              %s\n' "$titulo_pr"
printf 'Commits novos:       %s\n' "$quantidade_commits"
printf 'Arquivos alterados:  %s\n' "$quantidade_arquivos"

if [[ "${#labels_selecionadas[@]}" -gt 0 ]]; then
    printf 'Labels:              %s\n' \
        "$(IFS=', '; printf '%s' "${labels_selecionadas[*]}")"
else
    printf 'Labels:              Nenhuma\n'
fi

printf '\n'

read -r -p 'Confirma a criação do Pull Request? [S/n]: ' resposta_confirmacao
resposta_confirmacao="${resposta_confirmacao:-S}"

if resposta_negativa "$resposta_confirmacao"; then
    printf '\n'
    printf 'Operação cancelada.\n'
    printf '\n'
    exit 0
fi

# ============================================================
# Construção do corpo do Pull Request
# ============================================================

arquivo_corpo="$(mktemp)"

remover_arquivo_temporario() {
    rm -f "$arquivo_corpo"
}

trap remover_arquivo_temporario EXIT

cat >"$arquivo_corpo" <<EOF
## Objetivo

${objetivo}

## Motivo da alteração

${motivo}

## Revisão da PCB

${segmento_revisao#pcb-rev-}

## Branches

- Origem: \`${branch_atual}\`
- Destino: \`${branch_base}\`

## Módulos ou arquivos envolvidos

${modulos}

## Estado atual

${estado_atual}

## Impactos conhecidos

${impactos}

## Testes executados

${testes}

## Resultados dos testes

${resultados}

## Limitações ou pendências

${limitacoes}

## Checklist de validação

- Compilação verificada: ${build_confirmado}
- Compatibilidade com a revisão da PCB verificada: ${compatibilidade_confirmada}
- Funções alteradas testadas: ${funcoes_confirmadas}
- Funções relacionadas verificadas: ${funcoes_relacionadas_confirmadas}
- Possíveis regressões verificadas: ${regressoes_confirmadas}
- README atualizado ou verificado: ${readme_confirmado}
EOF

# ============================================================
# Criação do Pull Request
# ============================================================

declare -a argumentos_pr=(
    --base "$branch_base"
    --head "$branch_atual"
    --title "$titulo_pr"
    --body-file "$arquivo_corpo"
    --assignee '@me'
)

if [[ "$criar_como_draft" == true ]]; then
    argumentos_pr+=(--draft)
fi

for label in "${labels_selecionadas[@]}"; do
    argumentos_pr+=(--label "$label")
done

printf '\n'
printf 'Criando o Pull Request no GitHub...\n'
printf '\n'

url_pr="$(gh pr create "${argumentos_pr[@]}")"

printf '\n'
printf 'Pull Request criado com sucesso.\n'
printf '\n'
printf '%s\n' "$url_pr"
printf '\n'

if [[ "$criar_como_draft" == true ]]; then
    printf 'O Pull Request foi criado como rascunho.\n'
    printf 'Marque-o como pronto quando o desenvolvimento e as validações forem concluídos.\n'
    printf '\n'
fi