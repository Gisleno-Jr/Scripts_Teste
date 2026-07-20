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
        'Resolva ou cancele o merge antes de criar uma tag.' \
        'Para cancelar o merge:' \
        'git merge --abort'
    exit 1
fi

branch_atual="$(git branch --show-current)"

if [[ "$branch_atual" != 'main' ]]; then
    printf '\n%s\n  %s\n\n%s\n\n' \
        'As tags oficiais somente podem ser criadas a partir da branch main.' \
        "$branch_atual" \
        'Alterne para a main e execute novamente.'
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    printf '\n%s\n\n' \
        'Existem alterações pendentes no repositório:'

    git status --short

    printf '\n%s\n%s\n\n' \
        'A tag não pode ser criada enquanto houver alterações locais.' \
        'Faça commit, descarte ou armazene as alterações antes de continuar.'
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    printf '\n%s\n%s\n\n' \
        'Não existe um remoto chamado origin configurado.' \
        'Configure o repositório oficial antes de criar uma tag.'
    exit 1
fi

# ============================================================
# Funções auxiliares
# ============================================================

validar_revisao_pcb() {
    local revisao="$1"

    [[ "$revisao" =~ ^[0-9]+\.[0-9]+$ ]]
}

validar_versao_software() {
    local versao="$1"

    [[ "$versao" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

tag_existe_local() {
    local tag="$1"

    git show-ref \
        --tags \
        --verify \
        --quiet \
        "refs/tags/$tag"
}

tag_existe_remota() {
    local tag="$1"

    git ls-remote \
        --exit-code \
        --tags \
        origin \
        "refs/tags/$tag" \
        >/dev/null 2>&1
}

# ============================================================
# Atualização do repositório
# ============================================================

printf '\n%s\n\n' \
    'Atualizando as referências do GitHub...'

if ! git fetch origin --prune --tags; then
    printf '\n%s\n%s\n\n' \
        'Não foi possível acessar o repositório remoto.' \
        'Verifique sua conexão, suas credenciais e suas permissões.'
    exit 1
fi

if ! git show-ref \
    --verify \
    --quiet \
    'refs/remotes/origin/main'; then

    printf '\n%s\n\n' \
        'A branch origin/main não foi encontrada.'
    exit 1
fi

main_local="$(git rev-parse main)"
main_remota="$(git rev-parse origin/main)"

if [[ "$main_local" != "$main_remota" ]]; then
    printf '\n%s\n%s\n\n' \
        'A branch main local não está sincronizada com origin/main.' \
        'Atualizando a branch main...'

    if ! git pull --ff-only origin main; then
        printf '\n%s\n%s\n\n' \
            'Não foi possível atualizar a branch main automaticamente.' \
            'Resolva a divergência antes de criar uma tag.'
        exit 1
    fi
fi

# ============================================================
# Identificação da versão
# ============================================================

printf '\n%s\n%s\n%s\n\n' \
    '======================================' \
    ' Criação de tag de versão oficial' \
    '======================================'

printf '%s\n%s\n%s\n\n' \
    'A tag será criada sobre o commit atual da branch main.' \
    'Utilize este comando somente após revisão, validação e aprovação' \
    'do Pull Request de liberação.'

read -rp \
    'Revisão da PCB, por exemplo 1.0 ou 1.1: ' \
    revisao_pcb

if ! validar_revisao_pcb "$revisao_pcb"; then
    printf '\n%s\n%s\n\n' \
        'Revisão da PCB inválida.' \
        'Utilize o formato X.Y, por exemplo: 1.0, 1.1 ou 2.0.'
    exit 1
fi

read -rp \
    'Versão do software, por exemplo 1.0.0 ou 1.1.2: ' \
    versao_software

if ! validar_versao_software "$versao_software"; then
    printf '\n%s\n%s\n\n' \
        'Versão do software inválida.' \
        'Utilize o formato X.Y.Z, por exemplo: 1.0.0, 1.1.0 ou 2.0.1.'
    exit 1
fi

nome_tag="PCB-Rev-${revisao_pcb}_SW-v${versao_software}"

# ============================================================
# Verificação de duplicidade
# ============================================================

if tag_existe_local "$nome_tag"; then
    printf '\n%s\n  %s\n\n' \
        'A tag já existe localmente:' \
        "$nome_tag"
    exit 1
fi

if tag_existe_remota "$nome_tag"; then
    printf '\n%s\n  %s\n\n%s\n\n' \
        'A tag já existe no GitHub:' \
        "$nome_tag" \
        'Tags oficiais não devem ser reutilizadas ou substituídas.'
    exit 1
fi

# ============================================================
# Dados do commit
# ============================================================

commit_hash="$(git rev-parse HEAD)"
commit_curto="$(git rev-parse --short HEAD)"
commit_descricao="$(git log -1 --pretty=format:'%s')"
commit_autor="$(git log -1 --pretty=format:'%an')"
commit_data="$(git log -1 --date=format:'%d/%m/%Y %H:%M:%S' --pretty=format:'%ad')"

printf '\n%s\n' \
    '--------------------------------------'

printf '%s\n  %s\n\n' \
    'Tag que será criada:' \
    "$nome_tag"

printf '%s\n  %s\n\n' \
    'Branch:' \
    "$branch_atual"

printf '%s\n  %s\n\n' \
    'Commit:' \
    "$commit_curto"

printf '%s\n  %s\n\n' \
    'Descrição do commit:' \
    "$commit_descricao"

printf '%s\n  %s\n\n' \
    'Autor do commit:' \
    "$commit_autor"

printf '%s\n  %s\n\n' \
    'Data do commit:' \
    "$commit_data"

printf '%s\n' \
    '--------------------------------------'

# ============================================================
# Confirmações
# ============================================================

printf '\n%s\n%s\n%s\n\n' \
    'ATENÇÃO:' \
    'Após publicada, uma tag oficial não deve ser alterada,' \
    'movida, reutilizada, substituída ou excluída.'

read -rp \
    'O Pull Request de liberação foi revisado, validado e aprovado? [s/N]: ' \
    aprovacao

if [[ ! "$aprovacao" =~ ^[Ss]$ ]]; then
    printf '\n%s\n\n' \
        'Operação cancelada. A aprovação é obrigatória.'
    exit 0
fi

read -rp \
    "Confirma a criação e publicação da tag $nome_tag? [s/N]: " \
    confirmacao

if [[ ! "$confirmacao" =~ ^[Ss]$ ]]; then
    printf '\n%s\n\n' \
        'Operação cancelada.'
    exit 0
fi

# ============================================================
# Criação da tag anotada
# ============================================================

mensagem_tag="Versão oficial $nome_tag"

if ! git tag \
    -a "$nome_tag" \
    "$commit_hash" \
    -m "$mensagem_tag"; then

    printf '\n%s\n\n' \
        'Não foi possível criar a tag localmente.'
    exit 1
fi

# ============================================================
# Publicação da tag
# ============================================================

printf '\n%s\n  %s\n\n' \
    'Enviando a tag para o GitHub:' \
    "$nome_tag"

if ! git push origin "$nome_tag"; then
    printf '\n%s\n%s\n\n' \
        'A tag foi criada localmente, mas o envio falhou.' \
        'Ela não foi publicada no GitHub.'

    printf '%s\n  %s\n\n' \
        'Para tentar novamente:' \
        "git push origin $nome_tag"

    exit 1
fi

printf '\n%s\n  %s\n\n' \
    'Tag oficial criada e publicada com sucesso:' \
    "$nome_tag"

printf '%s\n%s\n\n' \
    'Próxima etapa:' \
    'Criar a Release no GitHub associada exatamente a essa tag.'